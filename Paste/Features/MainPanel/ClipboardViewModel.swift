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

@MainActor
class ClipboardViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var items: [ClipboardItemModel] = []
    @Published var filteredItems: [ClipboardItemModel] = []
    @Published var groupedItems: [(TimeGroup, [ClipboardItemModel])] = []
    
    @Published var searchText: String = ""
    @Published var selectedType: ClipboardItemType? {
        didSet {
            if selectedType != nil { isRegexPresetMode = false; selectedCustomTypeId = nil; isAboutMode = false }
            persistSelectedFilter()
            applyFilters()
        }
    }
    /// When true, main list shows regex presets instead of history.
    @Published var isRegexPresetMode: Bool = false {
        didSet {
            if isRegexPresetMode { selectedType = nil; selectedCustomTypeId = nil; isAboutMode = false }
            persistSelectedFilter()
            applyFilters()
            if selectedIndex >= effectiveDisplayItems.count {
                selectedIndex = max(0, effectiveDisplayItems.count - 1)
            }
        }
    }
    @Published var selectedIndex: Int = 0 {
        didSet {
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
            if let idx = activePinboardIndex {
                AppSettings.lastPinboardIndex = idx
            }
            applyFilters()
        }
    }
    
    enum PanelMode: String {
        case history
        case pasteStack
    }
    
    @Published var panelMode: PanelMode = .history {
        didSet {
            if panelMode == .history {
                // Keep activePinboardIndex as-is; user can still be in pinboard while in history mode.
            } else {
                // PasteStack is independent from pinboards.
                activePinboardIndex = nil
            }
            applyFilters()
        }
    }

    // MARK: - Custom Types

    /// All user-defined custom types (loaded from iCloud KV Store).
    @Published var customTypes: [CustomType] = AppSettings.customTypes

    /// When set, only items tagged with this custom type id are shown; clears selectedType and isRegexPresetMode.
    @Published var selectedCustomTypeId: String? {
        didSet {
            if selectedCustomTypeId != nil {
                selectedType = nil
                isRegexPresetMode = false
                isAboutMode = false
            }
            applyFilters()
        }
    }

    /// Controls visibility of the inline new-type input row.
    @Published var showCustomTypeInput: Bool = false
    /// Text bound to the inline new-type TextField.
    @Published var customTypeInputText: String = ""

    /// When true the panel shows the fixed "About" cards instead of clipboard history.
    @Published var isAboutMode: Bool = false {
        didSet {
            if isAboutMode {
                selectedType = nil
                isRegexPresetMode = false
                selectedCustomTypeId = nil
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
        guard !isRegexPresetMode, selectedIndex < filteredItems.count else { return nil }
        return filteredItems[selectedIndex]
    }
    /// Last deleted item for Cmd+Z undo (session-only).
    private(set) var lastDeletedItem: ClipboardItemModel?

    // MARK: - Private Properties
    
    private let clipboardService = ClipboardService.shared
    private let pasteStackService = PasteStackService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        self.activePinboardIndex = nil
        setupBindings()
        loadItems()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Debounce search input.
        $searchText
            .debounce(for: .seconds(Constants.searchDebounceDelay), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.applyFilters()
            }
            .store(in: &cancellables)
        
        // Reload when a new item is saved.
        NotificationCenter.default.publisher(for: .clipboardItemAdded)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.loadItems()
            }
            .store(in: &cancellables)
        
        // On panel show: reload data and restore the last selected filter tab.
        NotificationCenter.default.publisher(for: AppNotification.panelDidShow)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.loadItems()
                self.restoreSelectedFilter()
                self.selectedIndex = 0
                self.firstVisibleIndex = 0
            }
            .store(in: &cancellables)

        // On panel hide: reset transient state. Tab selection is persisted and restored on next show.
        NotificationCenter.default.publisher(for: AppNotification.panelWillHide)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.searchText = ""
                self.selectedIndex = 0
                self.selectedIndices = []
                self.selectionAnchor = nil
                self.panelMode = .history
                self.activePinboardIndex = nil
                self.isCommandHeld = false
                self.isShiftHeld = false
                self.firstVisibleIndex = 0
                self.pasteTargetAppName = ""
                self.pasteTargetAppIcon = nil
                self.showCustomTypeInput = false
                self.customTypeInputText = ""
            }
            .store(in: &cancellables)

        // Reload custom types when iCloud KV Store is updated from another device.
        NotificationCenter.default.publisher(for: NSUbiquitousKeyValueStore.didChangeExternallyNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.customTypes = AppSettings.customTypes
            }
            .store(in: &cancellables)

        // Reload items when CloudKit pushes remote changes into the local store.
        NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange,
                                             object: CoreDataStack.shared.persistentContainer.persistentStoreCoordinator)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.loadItems()
            }
            .store(in: &cancellables)
    }

    /// Persists the current filter tab selection to UserDefaults.
    private func persistSelectedFilter() {
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
        switch raw {
        case 1:
            selectedType = .text
        case 2:
            selectedType = .image
        case 3:
            selectedType = .file
        case 4:
            isRegexPresetMode = true
        default:
            selectedType = nil
            isRegexPresetMode = false
        }
    }
    
    // MARK: - Data Loading
    
    func loadItems() {
        items = clipboardService.fetchAllItems()
        applyFilters()
    }
    
    private func applyFilters() {
        let previousSelectedId = selectedItem?.id
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        var results = items
        
        if panelMode == .pasteStack {
            let entries = pasteStackService.fetchEntries()
            let map = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
            results = entries.compactMap { map[$0.itemId] }
        }
        
        if let pinboardIndex = activePinboardIndex {
            results = results.filter { $0.tagsArray.parsedTags().contains(where: { $0.pinboardIndex == pinboardIndex }) }
        }
        
        if let type = selectedType {
            results = results.filter { $0.itemType == type }
        }

        if let customId = selectedCustomTypeId {
            results = results.filter { $0.tagsArray.parsedTags().contains(where: { $0.customTypeId == customId }) }
        }
        
        if !keyword.isEmpty {
            results = results.filter { matchesKeyword(item: $0, keyword: keyword) }
        }
        
        filteredItems = results
        groupItems()
        
        // When filter/search changes, keep the same item selected if possible; fall back to index 0.
        if let previousSelectedId,
           let newIndex = filteredItems.firstIndex(where: { $0.id == previousSelectedId }) {
            selectedIndex = newIndex
        } else {
            selectedIndex = 0
        }
    }
    
    private func matchesKeyword(item: ClipboardItemModel, keyword: String) -> Bool {
        let lowerKeyword = keyword.lowercased()
        
        switch item.itemType {
        case .text:
            return (item.plainText ?? "").lowercased().contains(lowerKeyword)
            
        case .file:
            let paths = item.filePathsArray ?? []
            for path in paths {
                if path.lowercased().contains(lowerKeyword) { return true }
                if URL(fileURLWithPath: path).lastPathComponent.lowercased().contains(lowerKeyword) { return true }
            }
            return false
            
        case .image:
            // Images do not participate in keyword search (avoids matching placeholder text).
            return false
        }
    }
    
    private func groupItems() {
        var groups: [TimeGroup: [ClipboardItemModel]] = [:]
        
        for item in filteredItems {
            let group = TimeGroup.group(for: item.createdAt, isPinned: item.isPinned)
            groups[group, default: []].append(item)
        }
        
        // Emit groups in the canonical TimeGroup.allCases order.
        groupedItems = TimeGroup.allCases.compactMap { group in
            guard let items = groups[group], !items.isEmpty else { return nil }
            return (group, items)
        }
    }
    
    // MARK: - Actions
    
    /// Pastes the selected item(s). In multi-selection, items are joined with newlines.
    func pasteSelectedItem(plainTextOnly: Bool = false) {
        if isRegexPresetMode {
            pasteSelectedDisplayItem(plainTextOnly: plainTextOnly)
            return
        }
        let list = effectiveDisplayItems
        let indices = selectedIndices.count > 1 ? Array(selectedIndices).sorted() : [selectedIndex]
        guard !indices.isEmpty else { return }
        if indices.count == 1 {
            guard indices[0] < list.count else { return }
            if case .history(let item) = list[indices[0]] {
                pasteItem(item, plainTextOnly: plainTextOnly)
                if panelMode == .pasteStack {
                    pasteStackService.removeTopEntry(for: item.id)
                    loadItems()
                }
            }
            return
        }
        var parts: [String] = []
        for i in indices where i < list.count {
            switch list[i] {
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
        let list = effectiveDisplayItems
        let indices = selectedIndices.count > 1 ? Array(selectedIndices).sorted() : (selectedIndex < list.count ? [selectedIndex] : [])
        guard !indices.isEmpty else { return }
        if indices.count == 1, case .history(let item) = list[indices[0]] {
            copyItem(item)
            return
        }
        if indices.count == 1, case .preset(let p) = list[indices[0]] {
            clipboardService.copyPlainTextToClipboard(p.pattern)
            return
        }
        var parts: [String] = []
        for i in indices where i < list.count {
            switch list[i] {
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
    
    /// Advances to the next filter tab: All → Text → Image → File → Regex → All.
    func selectNextFilterTab() {
        if isRegexPresetMode {
            selectedType = nil
            isRegexPresetMode = false
        } else if let t = selectedType {
            switch t {
            case .text: selectedType = .image
            case .image: selectedType = .file
            case .file: isRegexPresetMode = true
            }
        } else {
            selectedType = .text
        }
    }
    
    /// Moves to the previous filter tab.
    func selectPreviousFilterTab() {
        if isRegexPresetMode {
            selectedType = .file
            isRegexPresetMode = false
        } else if let t = selectedType {
            switch t {
            case .text: selectedType = nil
            case .image: selectedType = .text
            case .file: selectedType = .image
            }
        } else {
            isRegexPresetMode = true
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
        let count = effectiveDisplayItems.count
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
        selectedIndex = max(0, effectiveDisplayItems.count - 1)
        selectionAnchor = selectedIndex
    }

    func selectAll() {
        let count = effectiveDisplayItems.count
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
        let count = effectiveDisplayItems.count
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
        guard selectedIndex < filteredItems.count else { return nil }
        return filteredItems[selectedIndex]
    }

    // MARK: - Display Items (history or regex presets)

    var effectiveDisplayItems: [DisplayItem] {
        if isRegexPresetMode {
            return RegexPreset.all.map { .preset($0) }
        }
        return filteredItems.map { .history($0) }
    }

    var selectedDisplayItem: DisplayItem? {
        let list = effectiveDisplayItems
        guard selectedIndex < list.count else { return nil }
        return list[selectedIndex]
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
