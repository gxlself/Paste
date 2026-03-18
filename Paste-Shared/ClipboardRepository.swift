// ClipboardRepository.swift
// Paste-Shared
//
// Cross-platform CoreData abstraction layer for clipboard items.
// The iOS ViewModel and Keyboard extension call this instead of
// touching NSManagedObjectContext directly.

import Foundation
import CoreData

// MARK: - Protocol

protocol ClipboardRepositoryProtocol {
    func fetchAll() -> [SharedClipboardItem]
    func create(type: ClipboardItemType, plainText: String?, rtfData: Data?,
                imageData: Data?, appBundleId: String?, contentHash: String?)
    func delete(_ item: SharedClipboardItem)
    func deleteAll()
    func togglePin(_ item: SharedClipboardItem)
    func bumpToTop(_ item: SharedClipboardItem)
    func updateText(_ item: SharedClipboardItem, plainText: String, rtfData: Data?)
    func updateImageData(_ item: SharedClipboardItem, newData: Data)
    func setAlias(_ item: SharedClipboardItem, name: String)
    func pinToBoard(_ item: SharedClipboardItem, index: Int)
    func unpinFromBoard(_ item: SharedClipboardItem)
    func pinSelectedToBoard(ids: Set<UUID>, index: Int)
    func exists(plainText: String?, contentHash: String?, type: ClipboardItemType) -> Bool
    func deduplicate()
    func updateTags(id: UUID, tags: [String])
}

// MARK: - Implementation

final class ClipboardRepository: ClipboardRepositoryProtocol {

    private let stack: SharedCoreDataStack

    init(stack: SharedCoreDataStack = .shared) {
        self.stack = stack
    }

    // MARK: - Fetch

    func fetchAll() -> [SharedClipboardItem] {
        let ctx = stack.viewContext
        let request: NSFetchRequest<ClipboardItemEntity> = ClipboardItemEntity.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ClipboardItemEntity.isPinned,   ascending: false),
            NSSortDescriptor(keyPath: \ClipboardItemEntity.createdAt,  ascending: false),
        ]
        request.fetchBatchSize = 50
        do {
            return try ctx.fetch(request).map { SharedClipboardItem(entity: $0, loadBinaryData: false) }
        } catch {
            print("ClipboardRepository fetchAll error: \(error)")
            return []
        }
    }

    // MARK: - Create

    func create(
        type: ClipboardItemType,
        plainText: String? = nil,
        rtfData: Data? = nil,
        imageData: Data? = nil,
        appBundleId: String? = nil,
        contentHash: String? = nil
    ) {
        let ctx = stack.viewContext
        let entity = ClipboardItemEntity(context: ctx)
        entity.id = UUID()
        entity.type = type.rawValue
        entity.plainText = plainText
        entity.rtfData = rtfData
        entity.imageData = imageData
        entity.appBundleId = appBundleId
        entity.contentHash = contentHash ?? UUID().uuidString
        entity.createdAt = Date()
        entity.isPinned = false
        stack.save()
    }

    // MARK: - Delete

    func delete(_ item: SharedClipboardItem) {
        performMutation(id: item.id) { entity, ctx in
            ctx.delete(entity)
        }
    }

    func deleteAll() {
        let ctx = stack.viewContext
        let request: NSFetchRequest<NSFetchRequestResult> = ClipboardItemEntity.fetchRequest()
        let batch = NSBatchDeleteRequest(fetchRequest: request)
        do {
            try ctx.execute(batch)
            stack.save()
        } catch {
            print("ClipboardRepository deleteAll error: \(error)")
        }
    }

    // MARK: - Update

    func togglePin(_ item: SharedClipboardItem) {
        performMutation(id: item.id) { entity, _ in
            entity.isPinned.toggle()
        }
    }

    func bumpToTop(_ item: SharedClipboardItem) {
        performMutation(id: item.id) { entity, _ in
            entity.createdAt = Date()
        }
    }

    func updateText(_ item: SharedClipboardItem, plainText: String, rtfData: Data?) {
        performMutation(id: item.id) { entity, _ in
            entity.plainText = plainText
            entity.rtfData = rtfData
        }
    }

    func updateImageData(_ item: SharedClipboardItem, newData: Data) {
        performMutation(id: item.id) { entity, _ in
            entity.imageData = newData
        }
    }

    // MARK: - Tags

    func setAlias(_ item: SharedClipboardItem, name: String) {
        performMutation(id: item.id) { entity, _ in
            var tags = decodeTags(entity.tags)
            tags.removeAll { ItemTag(rawValue: $0)?.isAlias == true }
            if !name.isEmpty { tags.append(ItemTag.alias(name).rawValue) }
            entity.tags = try? JSONEncoder().encode(tags)
        }
    }

    func pinToBoard(_ item: SharedClipboardItem, index: Int) {
        performMutation(id: item.id) { entity, _ in
            var tags = decodeTags(entity.tags)
            tags.removeAll { ItemTag(rawValue: $0)?.isPinboard == true }
            tags.append(ItemTag.pinboard(index).rawValue)
            entity.tags = try? JSONEncoder().encode(tags)
            entity.isPinned = true
        }
    }

    func unpinFromBoard(_ item: SharedClipboardItem) {
        performMutation(id: item.id) { entity, _ in
            var tags = decodeTags(entity.tags)
            tags.removeAll { ItemTag(rawValue: $0)?.isPinboard == true }
            entity.tags = try? JSONEncoder().encode(tags)
            entity.isPinned = false
        }
    }

    func pinSelectedToBoard(ids: Set<UUID>, index: Int) {
        let newTag = ItemTag.pinboard(index).rawValue
        let ctx = stack.viewContext
        let request: NSFetchRequest<ClipboardItemEntity> = ClipboardItemEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id IN %@", ids)
        guard let entities = try? ctx.fetch(request) else { return }
        for entity in entities {
            var tags = decodeTags(entity.tags)
            tags.removeAll { ItemTag(rawValue: $0)?.isPinboard == true }
            tags.append(newTag)
            entity.tags = try? JSONEncoder().encode(tags)
        }
        stack.save()
    }

    func updateTags(id: UUID, tags: [String]) {
        performMutation(id: id) { entity, _ in
            entity.tags = try? JSONEncoder().encode(tags)
        }
    }

    // MARK: - Existence check

    func exists(plainText: String? = nil, contentHash: String? = nil, type: ClipboardItemType) -> Bool {
        let ctx = stack.viewContext
        let request: NSFetchRequest<ClipboardItemEntity> = ClipboardItemEntity.fetchRequest()
        if let text = plainText {
            request.predicate = NSPredicate(format: "type == %d AND plainText == %@", type.rawValue, text)
        } else if let hash = contentHash {
            request.predicate = NSPredicate(format: "type == %d AND contentHash == %@", type.rawValue, hash)
        } else {
            return false
        }
        request.fetchLimit = 1
        return (try? ctx.count(for: request)) ?? 0 > 0
    }

    // MARK: - Deduplication

    func deduplicate() {
        let ctx = stack.viewContext
        let request: NSFetchRequest<ClipboardItemEntity> = ClipboardItemEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ClipboardItemEntity.createdAt, ascending: false)]
        guard let entities = try? ctx.fetch(request) else { return }

        var needsSave = false

        var seenTexts: [String: ClipboardItemEntity] = [:]
        for entity in entities where entity.type == ClipboardItemType.text.rawValue {
            guard let text = entity.plainText, !text.isEmpty else { continue }
            if let existing = seenTexts[text] {
                let keepCurrent = (entity.appIconData != nil) && (existing.appIconData == nil)
                ctx.delete(keepCurrent ? existing : entity)
                if keepCurrent { seenTexts[text] = entity }
                needsSave = true
            } else {
                seenTexts[text] = entity
            }
        }

        var seenImageHashes: [String: ClipboardItemEntity] = [:]
        for entity in entities where entity.type == ClipboardItemType.image.rawValue {
            guard let hash = entity.contentHash, !hash.isEmpty else { continue }
            if let existing = seenImageHashes[hash] {
                let keepCurrent = (entity.appIconData != nil) && (existing.appIconData == nil)
                ctx.delete(keepCurrent ? existing : entity)
                if keepCurrent { seenImageHashes[hash] = entity }
                needsSave = true
            } else {
                seenImageHashes[hash] = entity
            }
        }

        if needsSave { stack.save() }
    }

    // MARK: - Helpers

    private func performMutation(id: UUID, _ block: (ClipboardItemEntity, NSManagedObjectContext) -> Void) {
        let ctx = stack.viewContext
        let request: NSFetchRequest<ClipboardItemEntity> = ClipboardItemEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        guard let entity = try? ctx.fetch(request).first else { return }
        block(entity, ctx)
        stack.save()
    }

    private func decodeTags(_ data: Data?) -> [String] {
        guard let data else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }
}
