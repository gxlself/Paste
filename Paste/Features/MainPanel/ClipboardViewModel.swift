//
//  ClipboardViewModel.swift
//  Paste
//
//  Main panel ViewModel
//

import Foundation
import Combine
import AppKit
import CoreData

enum DisplayItem: Identifiable {
    case history(ClipboardItemModel)
    case preset(RegexPreset)

    var id: UUID {
        switch self {
        case .history(let m): return m.id
        case .preset(let p): return p.id
        }
    }
}

enum ClipboardFilterEngine {
    static func filter(
        items: [ClipboardItemModel],
        panelMode: ClipboardViewModel.PanelMode,
        pasteStackItemIDs: [UUID],
        activePinboardIndex: Int?,
        selectedType: ClipboardItemType?,
        selectedCustomTypeId: String?,
        normalizedKeyword: String
    ) -> [ClipboardItemModel] {
        var results = items

        if panelMode == .pasteStack {
            let map = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            results = pasteStackItemIDs.compactMap { map[$0] }
        }

        if let activePinboardIndex {
            results = results.filter {
                $0.parsedTags.contains { $0.pinboardIndex == activePinboardIndex }
            }
        }

        if let selectedType {
            results = results.filter { $0.itemType == selectedType }
        }

        if let selectedCustomTypeId {
            results = results.filter {
                $0.parsedTags.contains { $0.customTypeId == selectedCustomTypeId }
            }
        }

        guard !normalizedKeyword.isEmpty else { return results }
        return results.filter { item in
            switch item.itemType {
            case .text:
                return (item.plainText ?? "").lowercased().contains(normalizedKeyword)
            case .file:
                return (item.filePathsArray ?? []).contains { path in
                    path.lowercased().contains(normalizedKeyword)
                        || URL(fileURLWithPath: path).lastPathComponent
                            .lowercased()
                            .contains(normalizedKeyword)
                }
            case .image:
                return false
            }
        }
    }
}

@MainActor
class ClipboardViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var items: [ClipboardItemModel] = []
    @Published var filteredItems: [ClipboardItemModel] = []
    @Published private(set) var displayRevision = 0
    @Published private(set) var displayScopeID = 0
    private(set) var isFiltering = false
    
    @Published var searchText: String = ""
    @Published var selectedType: ClipboardItemType? {
        didSet {
            guard oldValue != selectedType else { return }
            withFilterMutation {
                if selectedType != nil {
                    isRegexPresetMode = false
                    selectedCustomTypeId = nil
                    isAboutMode = false
                }
                persistSelectedFilter()
            }
        }
    }
    /// When true, main list shows regex presets instead of history.
    @Published var isRegexPresetMode: Bool = false {
        didSet {
            guard oldValue != isRegexPresetMode else { return }
            withFilterMutation {
                if isRegexPresetMode {
                    selectedType = nil
                    selectedCustomTypeId = nil
                    isAboutMode = false
                }
                persistSelectedFilter()
            }
        }
    }
    @Published var selectedIndex: Int = 0 {
        didSet {
            guard oldValue != selectedIndex, isPreviewVisible else { return }
            if isPreviewVisible {
                NotificationCenter.default.post(name: AppNotification.selectedIndexChanged, object: nil)
            }
        }
    }
    /// Multi-selection indices (when count > 1, paste/delete/copy apply to all). Empty or single = use selectedIndex only.
    @Published var selectedIndices: Set<Int> = []
    /// Anchor index for Shift+Arrow extend selection.
    var selectionAnchor: Int?

    /// nil = normal history; otherwise show items tagged with `pinboard:<index>`
    @Published var activePinboardIndex: Int? {
        didSet {
            guard oldValue != activePinboardIndex else { return }
            if observesStore, let idx = activePinboardIndex {
                AppSettings.lastPinboardIndex = idx
            }
            requestApplyFilters()
        }
    }
    
    enum PanelMode: String, Sendable {
        case history
        case pasteStack
    }
    
    @Published var panelMode: PanelMode = .history {
        didSet {
            guard oldValue != panelMode else { return }
            withFilterMutation {
                if panelMode != .history {
                    // PasteStack is independent from pinboards.
                    activePinboardIndex = nil
                }
            }
        }
    }

    // MARK: - Custom Types

    /// All user-defined custom types (loaded from iCloud KV Store).
    @Published var customTypes: [CustomType] = AppSettings.customTypes

    /// When set, only items tagged with this custom type id are shown; clears selectedType and isRegexPresetMode.
    @Published var selectedCustomTypeId: String? {
        didSet {
            guard oldValue != selectedCustomTypeId else { return }
            withFilterMutation {
                if selectedCustomTypeId != nil {
                    selectedType = nil
                    isRegexPresetMode = false
                    isAboutMode = false
                }
            }
        }
    }

    /// Controls visibility of the inline new-type input row.
    @Published var showCustomTypeInput: Bool = false
    /// Text bound to the inline new-type TextField.
    @Published var customTypeInputText: String = ""

    /// When true the panel shows the fixed "About" cards instead of clipboard history.
    @Published var isAboutMode: Bool = false {
        didSet {
            guard oldValue != isAboutMode else { return }
            if isAboutMode {
                withFilterMutation {
                    selectedType = nil
                    isRegexPresetMode = false
                    selectedCustomTypeId = nil
                }
            }
        }
    }

    @Published var currentInputSourceName: String = ""
    @Published var currentInputSourceId: String = ""
    
    /// Name of the paste-target app shown in the panel header.
    @Published var pasteTargetAppName: String = ""
    /// Icon of the paste-target app.
    @Published var pasteTargetAppIcon: NSImage?
    
    /// True while the Command key is held (drives the quick-paste digit overlay).
    @Published var isCommandHeld: Bool = false
    /// True while the Shift key is held.
    @Published var isShiftHeld: Bool = false
    
    /// Index of the first visible item in the scroll view (drives quick-paste numbering).
    @Published var firstVisibleIndex: Int = 0
    
    @Published var isLoading = false
    @Published var isPreviewVisible: Bool = false
    @Published var focusSearch: Bool = false
    @Published var showRenameSheet: Bool = false
    @Published var showEditSheet: Bool = false
    @Published var showNewItemSheet: Bool = false
    /// Item being renamed/edited (for sheets).
    var itemForEdit: ClipboardItemModel? {
        guard !isFiltering, !isRegexPresetMode, filteredItems.indices.contains(selectedIndex) else { return nil }
        return filteredItems[selectedIndex]
    }
    /// Last deleted item for Cmd+Z undo (session-only).
    private(set) var lastDeletedItem: ClipboardItemModel?

    // MARK: - Private Properties
    
    private let clipboardService = ClipboardService.shared
    private let pasteStackService = PasteStackService.shared
    private var cancellables = Set<AnyCancellable>()
    private var reloadTask: Task<Void, Never>?
    private var reloadRequested = false
    private var filterTask: Task<Void, Never>?
    private var filterGeneration = 0
    private var filterMutationDepth = 0
    private var filterUpdatesSuspended = false
    private let observesStore: Bool
    private var typeCache: [ClipboardItemType: [ClipboardItemModel]] = [:]
    private var appliedFilter: FilterKey?
    private var displayedFilter: FilterKey?
    private var pendingFilter: FilterKey?

    private struct FilterKey: Equatable {
        let mode: PanelMode
        let pinboard: Int?
        let type: ClipboardItemType?
        let customType: String?
        let keyword: String
        let regex: Bool
        let about: Bool
    }
    
    // MARK: - Initialization
    
    init(initialItems: [ClipboardItemModel]? = nil) {
        observesStore = initialItems == nil
        self.activePinboardIndex = nil
        if let initialItems {
            items = initialItems
            typeCache = Dictionary(grouping: initialItems, by: \.itemType)
            applyFilters()
        } else {
            setupBindings()
            loadItems()
        }
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Debounce search input.
        $searchText
            .removeDuplicates()
            .dropFirst()
            .debounce(for: .seconds(Constants.searchDebounceDelay), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.requestApplyFilters()
            }
            .store(in: &cancellables)
        
        // Reload when a new item is saved. Copying in bursts (or CloudKit importing a batch)
        // fires these back to back, so coalesce them into a single reload.
        NotificationCenter.default.publisher(for: .clipboardItemAdded)
            .map { _ in () }
            .merge(with: NotificationCenter.default.publisher(
                for: .NSPersistentStoreRemoteChange,
                object: CoreDataStack.shared.persistentContainer.persistentStoreCoordinator
            ).map { _ in () })
            .throttle(for: .seconds(Constants.reloadCoalesceInterval), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] _ in
                self?.loadItems()
            }
            .store(in: &cancellables)
        
        // On panel show: restore the last selected filter tab. Data reloads are driven by
        // clipboard/CloudKit notifications and never block the hotkey path.
        NotificationCenter.default.publisher(for: AppNotification.panelDidShow)
            .sink { [weak self] _ in
                self?.prepareForPresentation()
            }
            .store(in: &cancellables)

        // On panel hide: reset transient state. Tab selection is persisted and restored on next show.
        NotificationCenter.default.publisher(for: AppNotification.panelWillHide)
            .sink { [weak self] _ in
                self?.suspendForHiddenPanel()
            }
            .store(in: &cancellables)

        // Reload custom types and pinboards when iCloud KV Store is updated from another device.
        NotificationCenter.default.publisher(for: NSUbiquitousKeyValueStore.didChangeExternallyNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.customTypes = AppSettings.customTypes
                AppSettings.loadPinboardsFromKVS()
                self?.objectWillChange.send()
                self?.loadItems()
            }
            .store(in: &cancellables)

    }

    func prepareForPresentation() {
        filterUpdatesSuspended = false
        if observesStore { restoreSelectedFilter() } else { applyFilters() }
        if selectedIndex != 0 { selectedIndex = 0 }
        updateFirstVisibleIndex(0)
    }

    func suspendForHiddenPanel() {
        filterUpdatesSuspended = true
        filterGeneration &+= 1
        filterTask?.cancel()
        filterTask = nil
        pendingFilter = nil
        isFiltering = false
        if !searchText.isEmpty { searchText = "" }
        if focusSearch { focusSearch = false }
        if selectedIndex != 0 { selectedIndex = 0 }
        if !selectedIndices.isEmpty { selectedIndices = [] }
        selectionAnchor = nil
        withFilterMutation(apply: false) {
            if panelMode != .history { panelMode = .history }
            if activePinboardIndex != nil { activePinboardIndex = nil }
        }
        updateModifierState([])
        updateFirstVisibleIndex(0)
        if showCustomTypeInput { showCustomTypeInput = false }
        if !customTypeInputText.isEmpty { customTypeInputText = "" }
    }

    /// Persists the current filter tab selection to UserDefaults.
    private func persistSelectedFilter() {
        guard observesStore else { return }
        let raw: Int
        if isRegexPresetMode {
            raw = 4
        } else if let type = selectedType {
            switch type {
            case .text: raw = 1
            case .image: raw = 2
            case .file: raw = 3
            }
        } else {
            raw = 0
        }
        AppSettings.lastSelectedFilterType = raw
    }

    /// Restores the last filter tab selection from UserDefaults (called on panelDidShow).
    private func restoreSelectedFilter() {
        let raw = AppSettings.lastSelectedFilterType
        withFilterMutation {
            switch raw {
            case 1:
                selectedType = .text
                isRegexPresetMode = false
            case 2:
                selectedType = .image
                isRegexPresetMode = false
            case 3:
                selectedType = .file
                isRegexPresetMode = false
            case 4:
                selectedType = nil
                isRegexPresetMode = true
            default:
                selectedType = nil
                isRegexPresetMode = false
            }
        }
    }
    
    // MARK: - Data Loading

    func waitForPendingFilters() async {
        await filterTask?.value
    }
    
    func loadItems() {
        if reloadTask != nil {
            reloadRequested = true
            return
        }
        isLoading = true

        reloadTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                let loaded = await self.clipboardService.fetchAllItemsAsync()
                let types = await Task.detached(priority: .userInitiated) {
                    Dictionary(grouping: loaded, by: \.itemType)
                }.value
                guard !Task.isCancelled else { return }

                self.items = loaded
                self.typeCache = types
                self.appliedFilter = nil
                self.pendingFilter = nil
                self.applyFilters()

                guard self.reloadRequested else {
                    self.isLoading = false
                    self.reloadTask = nil
                    return
                }
                self.reloadRequested = false
            }
            self.reloadTask = nil
        }
    }
    
    private func applyFilters() {
        guard !filterUpdatesSuspended else { return }

        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = FilterKey(mode: panelMode, pinboard: activePinboardIndex,
                            type: selectedType, customType: selectedCustomTypeId,
                            keyword: keyword, regex: isRegexPresetMode, about: isAboutMode)
        guard key != appliedFilter || key.mode == .pasteStack else {
            filterGeneration &+= 1
            filterTask?.cancel()
            filterTask = nil
            pendingFilter = nil
            isFiltering = false
            return
        }
        guard key != pendingFilter else { return }
        filterGeneration &+= 1
        let generation = filterGeneration
        filterTask?.cancel()
        filterTask = nil
        pendingFilter = key
        isFiltering = true

        if key.mode == .history, key.keyword.isEmpty,
           key.pinboard == nil, key.customType == nil {
            let results = key.type.map { typeCache[$0] ?? [] } ?? items
            applyFilterResults(results, key: key)
            return
        }

        let snapshot = items
        let currentPanelMode = panelMode
        let currentActivePinboardIndex = activePinboardIndex
        let currentSelectedType = selectedType
        let currentSelectedCustomTypeId = selectedCustomTypeId
        let pasteStackItemIDs = currentPanelMode == .pasteStack
            ? pasteStackService.fetchEntries().map(\.itemId)
            : []

        filterTask = Task { [weak self] in
            let results = await Task.detached(priority: .userInitiated) {
                ClipboardFilterEngine.filter(
                    items: snapshot,
                    panelMode: currentPanelMode,
                    pasteStackItemIDs: pasteStackItemIDs,
                    activePinboardIndex: currentActivePinboardIndex,
                    selectedType: currentSelectedType,
                    selectedCustomTypeId: currentSelectedCustomTypeId,
                    normalizedKeyword: keyword.lowercased()
                )
            }.value

            guard let self, !Task.isCancelled, generation == self.filterGeneration,
                  !self.filterUpdatesSuspended else { return }

            self.applyFilterResults(results, key: key)
            self.filterTask = nil
        }
    }

    private func applyFilterResults(_ results: [ClipboardItemModel], key: FilterKey) {
        // A pinboard can point thousands of rows into All. Carrying that selection across tabs
        // makes ScrollViewReader lay out the entire intervening history just to locate the ID.
        let scopeChanged = displayedFilter != nil && displayedFilter != key
        let previousSelectedId = scopeChanged ? nil : selectedItem?.id
        filteredItems = results
        let preservedIndex = previousSelectedId.flatMap { id in results.firstIndex { $0.id == id } } ?? 0
        let index = min(preservedIndex, max(0, displayItemCount - 1))
        if selectedIndex != index { selectedIndex = index }
        if !selectedIndices.isEmpty { selectedIndices = [] }
        selectionAnchor = nil
        appliedFilter = key
        displayedFilter = key
        pendingFilter = nil
        isFiltering = false
        displayRevision &+= 1
        if scopeChanged {
            updateFirstVisibleIndex(0)
            displayScopeID &+= 1
        }
    }

    // MARK: - Filter state

    /// Coalesces cascaded property changes into one filter pass.
    private func withFilterMutation(apply: Bool = true, _ body: () -> Void) {
        filterMutationDepth += 1
        body()
        filterMutationDepth -= 1

        guard apply, filterMutationDepth == 0 else { return }
        requestApplyFilters()
    }

    private func requestApplyFilters() {
        if filterMutationDepth > 0 {
            return
        } else {
            applyFilters()
        }
    }

    func selectFilter(_ type: ClipboardItemType?) {
        guard selectedType != type || isRegexPresetMode || selectedCustomTypeId != nil
                || activePinboardIndex != nil || isAboutMode else { return }
        withFilterMutation {
            selectedType = type
            isRegexPresetMode = false
            selectedCustomTypeId = nil
            activePinboardIndex = nil
            isAboutMode = false
        }
    }

    func selectRegexPresetFilter() {
        withFilterMutation {
            selectedType = nil
            isRegexPresetMode = true
            selectedCustomTypeId = nil
            activePinboardIndex = nil
            isAboutMode = false
        }
    }

    func selectPinboardFilter(index: Int) {
        withFilterMutation {
            selectedType = nil
            isRegexPresetMode = false
            selectedCustomTypeId = nil
            activePinboardIndex = max(0, min(index, AppSettings.pinboardCount - 1))
            isAboutMode = false
        }
    }

    func updateFirstVisibleIndex(_ index: Int) {
        let clamped = max(0, index)
        guard firstVisibleIndex != clamped else { return }
        firstVisibleIndex = clamped
    }

    func updateModifierState(_ flags: NSEvent.ModifierFlags) {
        let commandHeld = flags.contains(.command)
        let shiftHeld = flags.contains(.shift)
        if isCommandHeld != commandHeld { isCommandHeld = commandHeld }
        if isShiftHeld != shiftHeld { isShiftHeld = shiftHeld }
    }
    
    // MARK: - Actions
    
    /// Pastes the selected item(s). In multi-selection, items are joined with newlines.
    func pasteSelectedItem(plainTextOnly: Bool = false) {
        guard !isFiltering else { return }
        if isRegexPresetMode {
            pasteSelectedDisplayItem(plainTextOnly: plainTextOnly)
            return
        }
        let count = displayItemCount
        let indices = selectedIndices.count > 1 ? Array(selectedIndices).sorted() : [selectedIndex]
        guard !indices.isEmpty else { return }
        if indices.count == 1 {
            guard indices[0] < count else { return }
            if case .history(let item)? = displayItem(at: indices[0]) {
                pasteItem(item, plainTextOnly: plainTextOnly)
                if panelMode == .pasteStack {
                    pasteStackService.removeTopEntry(for: item.id)
                    loadItems()
                }
            }
            return
        }
        var parts: [String] = []
        for i in indices where i < count {
            guard let displayItem = displayItem(at: i) else { continue }
            switch displayItem {
            case .history(let item):
                if let t = item.plainText { parts.append(t) }
            case .preset(let p):
                parts.append(p.pattern)
            }
        }
        if !parts.isEmpty {
            clipboardService.copyPlainTextToClipboard(parts.joined(separator: "\n"))
            announceToVoiceOver(String(localized: "voiceover.announce.copied.multipleFormat \(parts.count)"))
            if AppSettings.directPasteEnabled {
                NotificationCenter.default.post(name: AppNotification.requestCloseAndPaste, object: nil)
            } else {
                NotificationCenter.default.post(name: AppNotification.requestClosePanel, object: nil)
            }
        }
    }
    
    /// Pastes an item. When Direct Paste is enabled, posts requestCloseAndPaste;
    /// otherwise copies to clipboard and closes the panel.
    func pasteItem(_ item: ClipboardItemModel, plainTextOnly: Bool = false) {
        guard !isFiltering else { return }
        clipboardService.pasteItem(item, simulatePaste: false, plainTextOnly: plainTextOnly)
        announceToVoiceOver(voiceOverSummary(for: item))
        
        if AppSettings.directPasteEnabled {
            NotificationCenter.default.post(name: AppNotification.requestCloseAndPaste, object: nil)
        } else {
            NotificationCenter.default.post(name: AppNotification.requestClosePanel, object: nil)
        }
        
        if panelMode == .pasteStack {
            pasteStackService.removeTopEntry(for: item.id)
        }
    }
    
    /// Writes content to the clipboard only, without triggering panel-close or paste notifications.
    /// Called by AppDelegate after the drag animation ends to unify the paste flow.
    func writeClipboardOnly(_ item: ClipboardItemModel, plainTextOnly: Bool = false) {
        clipboardService.pasteItem(item, simulatePaste: false, plainTextOnly: plainTextOnly)
        if panelMode == .pasteStack {
            pasteStackService.removeTopEntry(for: item.id)
        }
    }

    /// Copies an item to the clipboard.
    func copyItem(_ item: ClipboardItemModel, plainTextOnly: Bool = false) {
        clipboardService.copyItem(item, plainTextOnly: plainTextOnly)
    }

    /// Copies the selected item(s) to the clipboard, joining multi-selections with newlines.
    func copySelectedDisplayItem() {
        guard !isFiltering else { return }
        let count = displayItemCount
        let indices = selectedIndices.count > 1 ? Array(selectedIndices).sorted() : (selectedIndex < count ? [selectedIndex] : [])
        guard !indices.isEmpty else { return }
        if indices.count == 1, case .history(let item)? = displayItem(at: indices[0]) {
            copyItem(item)
            return
        }
        if indices.count == 1, case .preset(let p) = displayItem(at: indices[0]) {
            clipboardService.copyPlainTextToClipboard(p.pattern)
            return
        }
        var parts: [String] = []
        for i in indices where i < count {
            guard let displayItem = displayItem(at: i) else { continue }
            switch displayItem {
            case .history(let item): if let t = item.plainText { parts.append(t) }
            case .preset(let p): parts.append(p.pattern)
            }
        }
        if !parts.isEmpty {
            clipboardService.copyPlainTextToClipboard(parts.joined(separator: "\n"))
        }
    }
    
    /// Collapses multi-selection back to a single selection at the current index.
    func exitMultiSelection() {
        guard selectedIndices.count > 1 else { return }
        selectedIndices = []
        selectionAnchor = selectedIndex
    }

    /// Deletes the selected item(s). Regex presets cannot be deleted. Multi-selection deletes all.
    func deleteSelectedItem() {
        guard !isFiltering else { return }
        if isRegexPresetMode { return }
        let indices = selectedIndices.count > 1 ? Array(selectedIndices) : [selectedIndex]
        let validIndices = indices.filter { $0 < filteredItems.count }
        if let lastIdx = validIndices.last {
            lastDeletedItem = clipboardService.fetchItemWithFullData(id: filteredItems[lastIdx].id)
        }
        for i in validIndices {
            clipboardService.deleteItem(id: filteredItems[i].id)
        }
        if !validIndices.isEmpty {
            loadItems()
        }
        if selectedIndices.count > 1 {
            selectedIndices = []
            selectionAnchor = nil
        }
        let newCount = filteredItems.count
        if newCount == 0 {
            selectedIndex = 0
        } else if let firstDeleted = validIndices.min() {
            selectedIndex = firstDeleted > 0 ? (firstDeleted - 1) : 0
        }
    }
    
    /// Deletes a specific item.
    func deleteItem(_ item: ClipboardItemModel) {
        clipboardService.deleteItem(id: item.id)
        loadItems()
    }
    
    /// Toggles the pinned state of an item.
    func togglePin(_ item: ClipboardItemModel) {
        clipboardService.togglePin(id: item.id)
        loadItems()
    }
    
    /// Clears items respecting the current filter:
    /// - Paste Stack mode → clears the stack only
    /// - A type filter is active → deletes only items of that type
    /// - No filter (All) → deletes everything
    func clearAll() {
        if panelMode == .pasteStack {
            pasteStackService.clear()
        } else if let type = selectedType {
            clipboardService.deleteAllItems(ofType: type)
        } else {
            clipboardService.deleteAllItems()
        }
        loadItems()
    }

    // MARK: - Custom Types

    /// Confirms the inline input, creating a new custom type.
    func confirmAddCustomType() {
        let trimmed = customTypeInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { cancelAddCustomType(); return }
        AppSettings.addCustomType(name: trimmed)
        customTypes = AppSettings.customTypes
        customTypeInputText = ""
        showCustomTypeInput = false
    }

    func cancelAddCustomType() {
        customTypeInputText = ""
        showCustomTypeInput = false
    }

    func removeCustomType(id: String) {
        // Strip the tag from all items that carry it.
        let tagRaw = ItemTag.customType(id).rawValue
        for item in items where item.tagsArray.contains(tagRaw) {
            let updated = item.tagsArray.filter { $0 != tagRaw }
            clipboardService.updateTags(id: item.id, tags: updated)
        }
        AppSettings.removeCustomType(id: id)
        customTypes = AppSettings.customTypes
        if selectedCustomTypeId == id { selectedCustomTypeId = nil }
        loadItems()
    }

    func renameCustomType(id: String, name: String) {
        AppSettings.renameCustomType(id: id, name: name)
        customTypes = AppSettings.customTypes
    }

    /// Assigns item to a custom type (or removes it if already assigned — toggling).
    func toggleCustomType(id: String, for item: ClipboardItemModel) {
        let tagRaw = ItemTag.customType(id).rawValue
        var tags = item.tagsArray
        if tags.contains(tagRaw) {
            tags.removeAll { $0 == tagRaw }
        } else {
            tags.append(tagRaw)
        }
        clipboardService.updateTags(id: item.id, tags: tags)
        loadItems()
    }

    // MARK: - Pinboard

    var isShowingPinboard: Bool { activePinboardIndex != nil }
    
    func showPinboard(index: Int) {
        let clamped = max(0, min(index, AppSettings.pinboardCount - 1))
        activePinboardIndex = clamped
    }
    
    func exitPinboard() {
        activePinboardIndex = nil
    }
    
    func nextPinboard() {
        let current = activePinboardIndex ?? AppSettings.lastPinboardIndex
        let next = (current + 1) % AppSettings.pinboardCount
        activePinboardIndex = next
    }
    
    func previousPinboard() {
        let current = activePinboardIndex ?? AppSettings.lastPinboardIndex
        let prev = (current - 1 + AppSettings.pinboardCount) % AppSettings.pinboardCount
        activePinboardIndex = prev
    }

    func createNewPinboard() {
        let current = AppSettings.pinboardCount
        if current < AppSettings.pinboardCountMax {
            AppSettings.pinboardCount = current + 1
            AppSettings.savePinboardsToKVS()
        }
        showPinboard(index: AppSettings.pinboardCount - 1)
    }
    
    func toggleInPinboard(_ item: ClipboardItemModel, index: Int) {
        let enabled = !clipboardService.isInPinboard(item, index: index)
        clipboardService.setPinboard(id: item.id, index: index, enabled: enabled)
        loadItems()
    }
    
    func moveToPinboard(_ item: ClipboardItemModel, index: Int) {
        clipboardService.moveToPinboard(id: item.id, index: index)
        loadItems()
    }
    
    // MARK: - Filter Tab (All / Text / Image / File / Regex)
    
    /// Advances to the next tab: All → Text → Image → File → Regex → Pinboard 0…N-1 → All.
    func selectNextFilterTab() {
        withFilterMutation {
            if let pbIdx = activePinboardIndex {
                if pbIdx + 1 < AppSettings.pinboardCount {
                    selectPinboardFilter(index: pbIdx + 1)
                } else {
                    selectFilter(nil)
                }
            } else if isRegexPresetMode {
                if AppSettings.pinboardCount > 0 {
                    selectPinboardFilter(index: 0)
                } else {
                    selectFilter(nil)
                }
            } else if let t = selectedType {
                switch t {
                case .text: selectFilter(.image)
                case .image: selectFilter(.file)
                case .file: selectRegexPresetFilter()
                }
            } else {
                selectFilter(.text)
            }
        }
    }

    /// Moves to the previous tab: All → Pinboard N-1…0 → Regex → File → Image → Text → All.
    func selectPreviousFilterTab() {
        withFilterMutation {
            if let pbIdx = activePinboardIndex {
                if pbIdx > 0 {
                    selectPinboardFilter(index: pbIdx - 1)
                } else {
                    selectRegexPresetFilter()
                }
            } else if isRegexPresetMode {
                selectFilter(.file)
            } else if let t = selectedType {
                switch t {
                case .text: selectFilter(nil)
                case .image: selectFilter(.text)
                case .file: selectFilter(.image)
                }
            } else {
                if AppSettings.pinboardCount > 0 {
                    selectPinboardFilter(index: AppSettings.pinboardCount - 1)
                } else {
                    selectRegexPresetFilter()
                }
            }
        }
    }
    
    // MARK: - Paste Stack
    
    var isShowingPasteStack: Bool { panelMode == .pasteStack }
    
    func enterPasteStack() {
        panelMode = .pasteStack
    }
    
    func exitPasteStack() {
        panelMode = .history
    }
    
    func addToPasteStack(_ item: ClipboardItemModel) {
        pasteStackService.push(itemId: item.id)
        if panelMode == .pasteStack {
            loadItems()
        }
    }
    
    func removeFromPasteStack(_ item: ClipboardItemModel) {
        pasteStackService.removeTopEntry(for: item.id)
        if panelMode == .pasteStack {
            loadItems()
        }
    }
    
    // MARK: - Navigation
    
    func selectPrevious() {
        selectedIndices = []
        selectionAnchor = nil
        if selectedIndex > 0 {
            selectedIndex -= 1
        }
        selectionAnchor = selectedIndex
    }

    func selectNext() {
        selectedIndices = []
        selectionAnchor = nil
        let count = displayItemCount
        if selectedIndex < count - 1 {
            selectedIndex += 1
        }
        selectionAnchor = selectedIndex
    }

    func selectFirst() {
        selectedIndices = []
        selectionAnchor = nil
        selectedIndex = 0
        selectionAnchor = 0
    }

    func selectLast() {
        selectedIndices = []
        selectionAnchor = nil
        selectedIndex = max(0, displayItemCount - 1)
        selectionAnchor = selectedIndex
    }

    func selectAll() {
        let count = displayItemCount
        guard count > 0 else { return }
        selectedIndices = Set(0..<count)
        selectionAnchor = 0
        selectedIndex = 0
    }

    /// Closed range from a to b that is always valid (lowerBound <= upperBound).
    private func selectionRange(from a: Int, to b: Int) -> ClosedRange<Int> {
        min(a, b)...max(a, b)
    }

    func extendSelection(left: Bool) {
        let count = displayItemCount
        guard count > 0 else { return }
        let anchor = selectionAnchor ?? selectedIndex
        if left {
            if selectedIndices.count > 1 {
                guard let rightmost = selectedIndices.max() else { return }
                selectedIndices.remove(rightmost)
                selectedIndex = selectedIndices.max() ?? max(0, rightmost - 1)
                if selectedIndices.isEmpty {
                    selectionAnchor = selectedIndex
                } else if selectedIndices.count == 1, selectedIndex > 0 {
                    selectedIndex -= 1
                    selectedIndices.insert(selectedIndex)
                }
            } else if selectedIndex > 0 {
                selectedIndex -= 1
                selectedIndices = selectedIndices.union(Set(selectionRange(from: selectedIndex, to: anchor)))
            }
        } else {
            if selectedIndex < count - 1 {
                selectedIndex += 1
                selectedIndices = selectedIndices.union(Set(selectionRange(from: anchor, to: selectedIndex)))
            } else if selectedIndices.count > 1 {
                guard let leftmost = selectedIndices.min() else { return }
                selectedIndices.remove(leftmost)
                selectedIndex = selectedIndices.min() ?? selectedIndex
                if selectedIndices.isEmpty {
                    selectionAnchor = selectedIndex
                } else if selectedIndices.count == 1, selectedIndex < count - 1 {
                    selectedIndex += 1
                    selectedIndices.insert(selectedIndex)
                }
            }
        }
    }
    
    /// Returns the currently selected item (valid only in history mode).
    var selectedItem: ClipboardItemModel? {
        guard filteredItems.indices.contains(selectedIndex) else { return nil }
        return filteredItems[selectedIndex]
    }

    // MARK: - Display Items (history or regex presets)

    var displayItemCount: Int {
        isRegexPresetMode ? RegexPreset.all.count : filteredItems.count
    }

    func displayItem(at index: Int) -> DisplayItem? {
        guard index >= 0 else { return nil }
        if isRegexPresetMode {
            let presets = RegexPreset.all
            guard index < presets.count else { return nil }
            return .preset(presets[index])
        }
        guard index < filteredItems.count else { return nil }
        return .history(filteredItems[index])
    }

    var effectiveDisplayItems: [DisplayItem] {
        if isRegexPresetMode {
            return RegexPreset.all.map { .preset($0) }
        }
        return filteredItems.map { .history($0) }
    }

    var selectedDisplayItem: DisplayItem? {
        guard !isFiltering else { return nil }
        return displayItem(at: selectedIndex)
    }

    func renameSelectedItem(to newText: String) {
        guard let item = itemForEdit, item.itemType == .text else { return }
        let t = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        clipboardService.updatePlainText(id: item.id, newText: t)
        loadItems()
        showRenameSheet = false
    }

    func editSelectedItem(to newText: String) {
        guard let item = itemForEdit, item.itemType == .text else { return }
        clipboardService.updatePlainText(id: item.id, newText: newText)
        loadItems()
        showEditSheet = false
    }

    func createNewTextItem(text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        let content = ClipboardContent(
            type: .text,
            plainText: t,
            rtfData: nil,
            imageData: nil,
            filePaths: nil,
            sourceApp: nil,
            contentHash: HashUtil.sha256(t)
        )
        clipboardService.saveItem(content)
        loadItems()
        showNewItemSheet = false
    }

    func undoLastDelete() {
        guard let item = lastDeletedItem else { return }
        clipboardService.restoreItem(item)
        lastDeletedItem = nil
        loadItems()
    }

    var canUndo: Bool { lastDeletedItem != nil }

    func openSelectedItem() {
        guard let display = selectedDisplayItem else { return }
        switch display {
        case .history(let item):
            if item.itemType == .text, let text = item.plainText?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
                if text.hasPrefix("http://") || text.hasPrefix("https://"), let url = URL(string: text) {
                    NSWorkspace.shared.open(url)
                    return
                }
                if text.hasPrefix("/") || text.hasPrefix("~") || (text.count <= 1024 && FileManager.default.fileExists(atPath: (text as NSString).expandingTildeInPath)) {
                    let path = (text as NSString).expandingTildeInPath
                    let url = URL(fileURLWithPath: path)
                    NSWorkspace.shared.open(url)
                    return
                }
            }
            if item.itemType == .file, let paths = item.filePathsArray, let first = paths.first {
                NSWorkspace.shared.open(URL(fileURLWithPath: first))
            }
        case .preset:
            break
        }
    }

    /// Paste selected: for preset writes pattern to clipboard and closes; for history pastes item.
    func pasteSelectedDisplayItem(plainTextOnly: Bool = false) {
        guard let display = selectedDisplayItem else { return }
        switch display {
        case .preset(let p):
            clipboardService.copyPlainTextToClipboard(p.pattern)
            announceToVoiceOver(String(localized: "voiceover.announce.copied.text \(String(p.pattern.prefix(50)))"))
            if AppSettings.directPasteEnabled {
                NotificationCenter.default.post(name: AppNotification.requestCloseAndPaste, object: nil)
            } else {
                NotificationCenter.default.post(name: AppNotification.requestClosePanel, object: nil)
            }
        case .history(let item):
            pasteItem(item, plainTextOnly: plainTextOnly)
            if panelMode == .pasteStack {
                pasteStackService.removeTopEntry(for: item.id)
                loadItems()
            }
        }
    }

    // MARK: - VoiceOver Announcement

    private func announceToVoiceOver(_ message: String) {
        guard AppSettings.voiceOverAnnounceEnabled,
              NSWorkspace.shared.isVoiceOverEnabled else { return }
        let element = NSApp.mainWindow as Any
        NSAccessibility.post(
            element: element,
            notification: .announcementRequested,
            userInfo: [
                .announcement: message,
                .priority: NSAccessibilityPriorityLevel.high.rawValue
            ]
        )
    }

    private func voiceOverSummary(for item: ClipboardItemModel) -> String {
        switch item.itemType {
        case .text:
            let preview = (item.plainText ?? "").prefix(50)
            return String(localized: "voiceover.announce.copied.text \(String(preview))")
        case .image:
            return String(localized: "voiceover.announce.copied.image")
        case .file:
            let count = item.filePathsArray?.count ?? 1
            return String(localized: "voiceover.announce.copied.file \(count)")
        }
    }

    // MARK: - Private Methods
}
