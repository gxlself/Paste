//
//  iOSClipboardViewModel.swift
//  Paste-iOS
//

import SwiftUI
import Combine
import CoreData
import LinkPresentation

@MainActor
final class iOSClipboardViewModel: ObservableObject {

    // MARK: - Published state

    @Published var items: [SharedClipboardItem] = []
    @Published var searchText = ""
    @Published var selectedFilter: ClipboardItemType?
    /// When set, filters items by the custom type id; clears selectedFilter.
    @Published var selectedCustomTypeId: String?
    @Published var copiedItemID: UUID?
    @Published var activePinboardIndex: Int?
    @Published var isMultiSelectMode = false
    @Published var selectedItemIDs: Set<UUID> = []
    @Published var isSearchActive = false

    let settings = iOSAppSettings.shared

    // MARK: - Private

    private let repository: ClipboardRepositoryProtocol
    private var monitor: iOSClipboardMonitor?

    init(repository: ClipboardRepositoryProtocol = ClipboardRepository()) {
        self.repository = repository
    }

    var filteredItems: [SharedClipboardItem] {
        var result = items

        if let pbIndex = activePinboardIndex {
            result = result.filter { $0.tagsArray.parsedTags().contains(where: { $0.pinboardIndex == pbIndex }) }
        }

        if let filter = selectedFilter {
            result = result.filter { $0.itemType == filter }
        }

        if let customId = selectedCustomTypeId {
            result = result.filter { $0.tagsArray.parsedTags().contains(where: { $0.customTypeId == customId }) }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { item in
                if let text = item.plainText, text.localizedCaseInsensitiveContains(query) {
                    return true
                }
                if let appName = item.sourceAppName, appName.localizedCaseInsensitiveContains(query) {
                    return true
                }
                if item.displayText.localizedCaseInsensitiveContains(query) {
                    return true
                }
                return false
            }
        }

        return result
    }

    // MARK: - Lifecycle

    func start() {
        fetchItems()
        monitor = iOSClipboardMonitor { [weak self] in
            self?.captureClipboard()
        }
        monitor?.startMonitoring()

        NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: SharedCoreDataStack.shared.persistentContainer.persistentStoreCoordinator,
            queue: .main
        ) { [weak self] _ in
            self?.repository.deduplicate()
            self?.fetchItems()
        }
    }

    func stop() {
        monitor?.stopMonitoring()
    }

    // MARK: - CRUD

    func fetchItems() {
        items = repository.fetchAll()
    }

    func copyToClipboard(_ item: SharedClipboardItem) {
        let pb = UIPasteboard.general
        switch item.itemType {
        case .text:  pb.string = item.plainText
        case .image:
            let data = item.imageData ?? SharedThumbnailCache.loadImageData(for: item.id)
            if let data, let img = UIImage(data: data) { pb.image = img }
        case .file:  pb.string = item.displayText
        }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        bumpItemToTop(item)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            withAnimation(.easeOut(duration: 0.3)) {
                if self?.copiedItemID == item.id { self?.copiedItemID = nil }
            }
        }
    }

    private func bumpItemToTop(_ item: SharedClipboardItem) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            if let idx = items.firstIndex(where: { $0.id == item.id }), idx > 0 {
                let pinnedCount = items.prefix(while: { $0.isPinned }).count
                let target = item.isPinned ? 0 : pinnedCount
                items.remove(at: idx)
                items.insert(item, at: target)
            }
            copiedItemID = item.id
        }
        repository.bumpToTop(item)
    }

    func deleteItem(_ item: SharedClipboardItem) {
        repository.delete(item)
        fetchItems()
    }

    func togglePin(_ item: SharedClipboardItem) {
        repository.togglePin(item)
        fetchItems()
    }

    func updateItemText(_ item: SharedClipboardItem, newText: String) {
        repository.updateText(item, plainText: newText, rtfData: nil)
        fetchItems()
    }

    func updateItem(_ item: SharedClipboardItem, plainText: String, rtfData: Data?) {
        repository.updateText(item, plainText: plainText, rtfData: rtfData)
        fetchItems()
    }

    func updateImageData(_ item: SharedClipboardItem, newData: Data) {
        repository.updateImageData(item, newData: newData)
        fetchItems()
    }

    func renameItem(_ item: SharedClipboardItem, newName: String) {
        repository.setAlias(item, name: newName)
        fetchItems()
    }

    func pinItemToBoard(_ item: SharedClipboardItem, index: Int) {
        repository.pinToBoard(item, index: index)
        fetchItems()
    }

    func unpinItem(_ item: SharedClipboardItem) {
        repository.unpinFromBoard(item)
        fetchItems()
    }

    func itemByID(_ id: UUID) -> SharedClipboardItem? {
        items.first { $0.id == id }
    }

    // MARK: - Create items

    func createTextItem(text: String) {
        createEntity(type: .text, plainText: text)
    }

    func addScannedText(_ text: String) {
        createEntity(type: .text, plainText: text)
    }

    // MARK: - Multi-select

    func toggleSelection(_ item: SharedClipboardItem) {
        if selectedItemIDs.contains(item.id) {
            selectedItemIDs.remove(item.id)
        } else {
            selectedItemIDs.insert(item.id)
        }
    }

    func exitMultiSelect() {
        isMultiSelectMode = false
        selectedItemIDs.removeAll()
    }

    func mergeSelectedItems() {
        let selected = items.filter { selectedItemIDs.contains($0.id) }
        let merged = selected.compactMap { $0.plainText }.joined(separator: "\n")
        if !merged.isEmpty {
            UIPasteboard.general.string = merged
        }
        exitMultiSelect()
    }

    func deleteSelectedItems() {
        let toDelete = items.filter { selectedItemIDs.contains($0.id) }
        toDelete.forEach { repository.delete($0) }
        exitMultiSelect()
        fetchItems()
    }

    func moveSelectedToPinboard(_ index: Int) {
        repository.pinSelectedToBoard(ids: selectedItemIDs, index: index)
        exitMultiSelect()
        fetchItems()
    }

    // MARK: - Per-filter item lists (for TabView pages)

    func items(for filter: ClipboardItemType?) -> [SharedClipboardItem] {
        var result = items

        if let filter {
            result = result.filter { $0.itemType == filter }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { item in
                if let text = item.plainText, text.localizedCaseInsensitiveContains(query) { return true }
                if let appName = item.sourceAppName, appName.localizedCaseInsensitiveContains(query) { return true }
                if item.displayText.localizedCaseInsensitiveContains(query) { return true }
                return false
            }
        }

        return result
    }

    func pinboardItems(for pinboardIndex: Int) -> [SharedClipboardItem] {
        var result = items.filter { $0.tagsArray.parsedTags().contains(where: { $0.pinboardIndex == pinboardIndex }) }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { item in
                if let text = item.plainText, text.localizedCaseInsensitiveContains(query) { return true }
                if let appName = item.sourceAppName, appName.localizedCaseInsensitiveContains(query) { return true }
                if item.displayText.localizedCaseInsensitiveContains(query) { return true }
                return false
            }
        }

        return result
    }

    func clearItems(ofType type: ClipboardItemType?) {
        settings.clearItems(ofType: type)
        fetchItems()
    }

    func removeCustomType(id: String) {
        // Strip the tag from all items that carry it before deleting the type definition.
        let tagRaw = ItemTag.customType(id).rawValue
        for item in items where item.tagsArray.contains(tagRaw) {
            let updated = item.tagsArray.filter { $0 != tagRaw }
            repository.updateTags(id: item.id, tags: updated)
        }
        settings.removeCustomType(id: id)
        if selectedCustomTypeId == id { selectedCustomTypeId = nil }
        fetchItems()
    }

    // MARK: - Filter navigation

    static let filterOrder: [ClipboardItemType?] = [nil, .text, .image, .file]

    func nextFilter() {
        guard let idx = Self.filterOrder.firstIndex(where: { $0 == selectedFilter }) else { return }
        let next = idx + 1
        selectedFilter = next < Self.filterOrder.count ? Self.filterOrder[next] : Self.filterOrder[0]
    }

    func previousFilter() {
        guard let idx = Self.filterOrder.firstIndex(where: { $0 == selectedFilter }) else { return }
        let prev = idx - 1
        selectedFilter = prev >= 0 ? Self.filterOrder[prev] : Self.filterOrder.last!
    }

    func pinboardIndex(for item: SharedClipboardItem) -> Int? {
        item.tagsArray.parsedTags().compactMap(\.pinboardIndex).first
    }

    // MARK: - Clipboard capture

    private func captureClipboard() {
        guard settings.collectWhenActive else { return }
        let pb = UIPasteboard.general
        if let string = pb.string, !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let hash = contentHash(string: string)
            if !repository.exists(plainText: string, contentHash: hash, type: .text) {
                repository.create(type: .text, plainText: string, rtfData: nil,
                                  imageData: nil, appBundleId: nil, contentHash: hash)
                fetchItems()
            }
        } else if settings.recordImages, let image = pb.image, let data = image.pngData() {
            let hash = contentHash(data: data)
            if !repository.exists(plainText: nil, contentHash: hash, type: .image) {
                repository.create(type: .image, plainText: nil, rtfData: nil,
                                  imageData: data, appBundleId: nil, contentHash: hash)
                fetchItems()
            }
        }
    }

    func createEntity(
        type: ClipboardItemType,
        plainText: String? = nil,
        rtfData: Data? = nil,
        imageData: Data? = nil,
        appBundleId: String? = nil,
        contentHash: String? = nil
    ) {
        repository.create(
            type: type,
            plainText: plainText,
            rtfData: rtfData,
            imageData: imageData,
            appBundleId: appBundleId,
            contentHash: contentHash
        )
        fetchItems()
    }

    private func contentHash(string: String) -> String {
        contentHash(data: Data(string.utf8))
    }

    private func contentHash(data: Data) -> String {
        var hasher = Hasher()
        hasher.combine(data)
        return "\(hasher.finalize())"
    }
}
