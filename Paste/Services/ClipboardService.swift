//
//  ClipboardService.swift
//  Paste
//
//  Clipboard business service — manages CRUD operations
//

import Foundation
import CoreData
import AppKit

class ClipboardService {
    
    static let shared = ClipboardService()
    
    private let coreDataStack = CoreDataStack.shared
    private let pasteboardHelper = PasteboardHelper.shared
    
    private init() {}
    
    // MARK: - Create
    
    /// Persists a new clipboard item, deduplicating by content hash.
    func saveItem(_ content: ClipboardContent) {
        let context = coreDataStack.viewContext
        
        // Deduplicate: if this hash already exists, just update its timestamp.
        if itemExists(hash: content.contentHash) {
            updateTimestamp(hash: content.contentHash, sourceApp: content.sourceApp)
            return
        }
        
        // Create a new CoreData entity.
        let item = ClipboardItemEntity(context: context) 
        item.id = UUID()
        item.type = content.type.rawValue
        item.plainText = content.plainText
        item.rtfData = content.rtfData
        item.imageData = content.imageData
        item.appBundleId = content.sourceApp
        item.createdAt = Date()
        item.contentHash = content.contentHash
        item.isPinned = false
        
        // Encode file paths as JSON.
        if let paths = content.filePaths {
            item.filePaths = try? JSONEncoder().encode(paths)
        }

        // Write the source app name to tags so the iOS client can display it after sync.
        if let bundleId = content.sourceApp,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            let appName = FileManager.default.displayName(atPath: appURL.path)
                .replacingOccurrences(of: ".app", with: "")
            var tags: [String] = []
            if let existing = item.tags {
                tags = (try? JSONDecoder().decode([String].self, from: existing)) ?? []
            }
            tags.removeAll { ItemTag(rawValue: $0)?.isAppName == true }
            tags.append(ItemTag.appName(appName).rawValue)
            item.tags = try? JSONEncoder().encode(tags)

            let icon = NSWorkspace.shared.icon(forFile: appURL.path)
            let targetSize = NSSize(width: 64, height: 64)
            let resized = NSImage(size: targetSize)
            resized.lockFocus()
            icon.draw(in: NSRect(origin: .zero, size: targetSize),
                      from: NSRect(origin: .zero, size: icon.size),
                      operation: .copy, fraction: 1.0)
            resized.unlockFocus()
            if let tiff = resized.tiffRepresentation,
               let rep = NSBitmapImageRep(data: tiff),
               let png = rep.representation(using: .png, properties: [:]) {
                item.appIconData = png
            }
        }
        
        coreDataStack.save()
        
        // Enforce retention limits after saving.
        cleanupOldItems()
        
        // Notify observers that a new item was added.
        NotificationCenter.default.post(name: .clipboardItemAdded, object: nil)
    }
    
    // MARK: - Read
    
    /// Fetches all items sorted by date descending. Binary data is not loaded to conserve memory.
    func fetchAllItems() -> [ClipboardItemModel] {
        let context = coreDataStack.viewContext
        let request: NSFetchRequest<ClipboardItemEntity> = ClipboardItemEntity.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ClipboardItemEntity.createdAt, ascending: false),
            NSSortDescriptor(keyPath: \ClipboardItemEntity.isPinned, ascending: false)
        ]
        request.fetchBatchSize = 50
        
        do {
            let entities = try context.fetch(request)
            return entities.map { ClipboardItemModel(entity: $0, loadBinaryData: false) }
        } catch {
            print("Fetch error: \(error)")
            return []
        }
    }

    /// Fetches a single item with full binary data (for paste, undo, etc.).
    func fetchItemWithFullData(id: UUID) -> ClipboardItemModel? {
        let context = coreDataStack.viewContext
        let request: NSFetchRequest<ClipboardItemEntity> = ClipboardItemEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        do {
            if let entity = try context.fetch(request).first {
                return ClipboardItemModel(entity: entity, loadBinaryData: true)
            }
        } catch {
            print("Fetch full data error: \(error)")
        }
        return nil
    }
    
    /// Searches items by keyword and optional type filter.
    func searchItems(keyword: String, type: ClipboardItemType? = nil) -> [ClipboardItemModel] {
        let context = coreDataStack.viewContext
        let request: NSFetchRequest<ClipboardItemEntity> = ClipboardItemEntity.fetchRequest()
        
        var predicates: [NSPredicate] = []
        
        if !keyword.isEmpty {
            predicates.append(NSPredicate(format: "plainText CONTAINS[cd] %@", keyword))
        }
        
        if let type = type {
            predicates.append(NSPredicate(format: "type == %d", type.rawValue))
        }
        
        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ClipboardItemEntity.createdAt, ascending: false),
            NSSortDescriptor(keyPath: \ClipboardItemEntity.isPinned, ascending: false)
        ]
        request.fetchBatchSize = 50
        
        do {
            let entities = try context.fetch(request)
            return entities.map { ClipboardItemModel(entity: $0, loadBinaryData: false) }
        } catch {
            print("Search error: \(error)")
            return []
        }
    }
    
    /// Filters items by source application bundle ID.
    func filterByApp(_ bundleId: String) -> [ClipboardItemModel] {
        let context = coreDataStack.viewContext
        let request: NSFetchRequest<ClipboardItemEntity> = ClipboardItemEntity.fetchRequest()
        request.predicate = NSPredicate(format: "appBundleId == %@", bundleId)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ClipboardItemEntity.createdAt, ascending: false)
        ]
        request.fetchBatchSize = 50
        
        do {
            let entities = try context.fetch(request)
            return entities.map { ClipboardItemModel(entity: $0, loadBinaryData: false) }
        } catch {
            print("Filter error: \(error)")
            return []
        }
    }
    
    // MARK: - Update
    
    /// Toggles the pinned state of an item.
    func togglePin(id: UUID) {
        let context = coreDataStack.viewContext
        let request: NSFetchRequest<ClipboardItemEntity> = ClipboardItemEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            if let item = try context.fetch(request).first {
                item.isPinned.toggle()
                coreDataStack.save()
            }
        } catch {
            print("Toggle pin error: \(error)")
        }
    }
    
    /// Replaces the tags array of an item.
    func updateTags(id: UUID, tags: [String]) {
        let context = coreDataStack.viewContext
        let request: NSFetchRequest<ClipboardItemEntity> = ClipboardItemEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            if let item = try context.fetch(request).first {
                item.tags = try? JSONEncoder().encode(tags)
                coreDataStack.save()
            }
        } catch {
            print("Update tags error: \(error)")
        }
    }

    // MARK: - Pinboard
    
    func isInAnyPinboard(_ item: ClipboardItemModel) -> Bool {
        item.tagsArray.parsedTags().contains(where: \.isPinboard)
    }
    
    func isInPinboard(_ item: ClipboardItemModel, index: Int) -> Bool {
        item.tagsArray.parsedTags().contains(where: { $0.pinboardIndex == index })
    }
    
    func setPinboard(id: UUID, index: Int, enabled: Bool) {
        let context = coreDataStack.viewContext
        let request: NSFetchRequest<ClipboardItemEntity> = ClipboardItemEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        
        do {
            guard let entity = try context.fetch(request).first else { return }
            let existing: [String] = (entity.tags.flatMap { try? JSONDecoder().decode([String].self, from: $0) }) ?? []
            let tag = ItemTag.pinboard(index)
            var updated = existing.filter { ItemTag(rawValue: $0) != tag }
            if enabled {
                updated.append(tag.rawValue)
            }
            entity.tags = try? JSONEncoder().encode(updated)
            coreDataStack.save()
        } catch {
            print("Set pinboard error: \(error)")
        }
    }
    
    func moveToPinboard(id: UUID, index: Int) {
        let context = coreDataStack.viewContext
        let request: NSFetchRequest<ClipboardItemEntity> = ClipboardItemEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        
        do {
            guard let entity = try context.fetch(request).first else { return }
            let existing: [String] = (entity.tags.flatMap { try? JSONDecoder().decode([String].self, from: $0) }) ?? []
            let cleaned = existing.filter { !(ItemTag(rawValue: $0)?.isPinboard == true) }
            let updated = cleaned + [ItemTag.pinboard(index).rawValue]
            entity.tags = try? JSONEncoder().encode(updated)
            coreDataStack.save()
        } catch {
            print("Move pinboard error: \(error)")
        }
    }
    
    // MARK: - Delete
    
    /// Deletes a single item by ID.
    func deleteItem(id: UUID) {
        let context = coreDataStack.viewContext
        let request: NSFetchRequest<ClipboardItemEntity> = ClipboardItemEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            if let item = try context.fetch(request).first {
                context.delete(item)
                coreDataStack.save()
            }
        } catch {
            print("Delete error: \(error)")
        }
    }

    /// Updates the plain-text content of an item (used for rename/edit).
    func updatePlainText(id: UUID, newText: String) {
        let context = coreDataStack.viewContext
        let request: NSFetchRequest<ClipboardItemEntity> = ClipboardItemEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        do {
            if let entity = try context.fetch(request).first {
                entity.plainText = newText
                entity.contentHash = HashUtil.sha256(newText)
                entity.createdAt = Date()
                coreDataStack.save()
                NotificationCenter.default.post(name: .clipboardItemAdded, object: nil)
            }
        } catch {
            print("Update plain text error: \(error)")
        }
    }

    /// Restores a previously deleted item (Cmd+Z undo).
    func restoreItem(_ model: ClipboardItemModel) {
        let content = ClipboardContent(
            type: model.itemType,
            plainText: model.plainText,
            rtfData: model.rtfData,
            imageData: model.imageData,
            filePaths: model.filePathsArray,
            sourceApp: model.appBundleId,
            contentHash: model.contentHash
        )
        saveItem(content)
    }
    
    /// Deletes all items from the store.
    func deleteAllItems() {
        let context = coreDataStack.viewContext
        let request: NSFetchRequest<NSFetchRequestResult> = ClipboardItemEntity.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        do {
            try context.execute(deleteRequest)
            coreDataStack.save()
        } catch {
            print("Delete all error: \(error)")
        }
    }

    /// Deletes all items of a specific type from the store.
    func deleteAllItems(ofType type: ClipboardItemType) {
        let context = coreDataStack.viewContext
        let request: NSFetchRequest<NSFetchRequestResult> = ClipboardItemEntity.fetchRequest()
        request.predicate = NSPredicate(format: "type == %@", type.rawValue)
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        do {
            try context.execute(deleteRequest)
            coreDataStack.save()
        } catch {
            print("Delete all(\(type)) error: \(error)")
        }
    }
    
    // MARK: - Paste
    
    /// Writes an item to the system clipboard and updates its timestamp.
    func pasteItem(_ item: ClipboardItemModel, simulatePaste: Bool = false, plainTextOnly: Bool = false) {
        updateTimestamp(hash: item.contentHash)
        ClipboardMonitor.shared.markSelfWrite(hash: item.contentHash)
        pasteboardHelper.writeItem(item, plainTextOnly: plainTextOnly)
    }
    
    /// Copies an item to the clipboard without triggering paste.
    func copyItem(_ item: ClipboardItemModel, plainTextOnly: Bool = false) {
        ClipboardMonitor.shared.markSelfWrite(hash: item.contentHash)
        pasteboardHelper.writeItem(item, plainTextOnly: plainTextOnly)
    }

    /// Writes plain text to the clipboard (used for regex presets etc.).
    func copyPlainTextToClipboard(_ string: String) {
        pasteboardHelper.writeText(string, rtfData: nil)
    }

    // MARK: - Private Methods
    
    /// Returns true if an item with the given hash already exists.
    private func itemExists(hash: String) -> Bool {
        let context = coreDataStack.viewContext
        let request: NSFetchRequest<ClipboardItemEntity> = ClipboardItemEntity.fetchRequest()
        request.predicate = NSPredicate(format: "contentHash == %@", hash)
        request.fetchLimit = 1
        
        do {
            return try context.count(for: request) > 0
        } catch {
            return false
        }
    }
    
    /// Updates the timestamp (and optionally the source app) of an existing item.
    private func updateTimestamp(hash: String, sourceApp: String? = nil) {
        let context = coreDataStack.viewContext
        let request: NSFetchRequest<ClipboardItemEntity> = ClipboardItemEntity.fetchRequest()
        request.predicate = NSPredicate(format: "contentHash == %@", hash)
        request.fetchLimit = 1
        
        do {
            if let item = try context.fetch(request).first {
                item.createdAt = Date()
                item.appBundleId = sourceApp ?? item.appBundleId

                if let bundleId = sourceApp,
                   let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                    let appName = FileManager.default.displayName(atPath: appURL.path)
                        .replacingOccurrences(of: ".app", with: "")
                    var tags: [String] = []
                    if let existing = item.tags {
                        tags = (try? JSONDecoder().decode([String].self, from: existing)) ?? []
                    }
                    tags.removeAll { ItemTag(rawValue: $0)?.isAppName == true }
                    tags.append(ItemTag.appName(appName).rawValue)
                    item.tags = try? JSONEncoder().encode(tags)
                }

                coreDataStack.save()
            }
        } catch {
            print("Update timestamp error: \(error)")
        }
    }
    
    /// Returns the total number of stored items.
    private func getItemCount() -> Int {
        let context = coreDataStack.viewContext
        let request: NSFetchRequest<ClipboardItemEntity> = ClipboardItemEntity.fetchRequest()
        
        do {
            return try context.count(for: request)
        } catch {
            return 0
        }
    }
    
    /// Deletes the oldest unpinned item.
    private func deleteOldestItem() {
        let context = coreDataStack.viewContext
        let request: NSFetchRequest<ClipboardItemEntity> = ClipboardItemEntity.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ClipboardItemEntity.createdAt, ascending: true),
            NSSortDescriptor(keyPath: \ClipboardItemEntity.isPinned, ascending: false)
        ]
        request.fetchLimit = 1
        
        do {
            if let item = try context.fetch(request).first {
                context.delete(item)
                coreDataStack.save()
            }
        } catch {
            print("Delete oldest item error: \(error)")
        }
    }
    
    /// Enforces time-based and count-based retention limits.
    private func cleanupOldItems() {
        let maxItems = AppSettings.retentionMaxItems
        let retentionPreset = AppSettings.retentionPreset
        
        let context = coreDataStack.viewContext
        let request: NSFetchRequest<ClipboardItemEntity> = ClipboardItemEntity.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ClipboardItemEntity.createdAt, ascending: false),
            NSSortDescriptor(keyPath: \ClipboardItemEntity.isPinned, ascending: false)
        ]
        request.fetchBatchSize = 100
        
        do {
            var items = try context.fetch(request)
            
            // Protect items referenced by Paste Stack (avoid orphan stack entries)
            let stackItemIds: Set<UUID> = {
                let stackReq: NSFetchRequest<StackEntryEntity> = StackEntryEntity.fetchRequest()
                stackReq.fetchBatchSize = 200
                let entries = (try? context.fetch(stackReq)) ?? []
                return Set(entries.compactMap { $0.itemId })
            }()
            
            func isProtected(_ entity: ClipboardItemEntity) -> Bool {
                if entity.isPinned { return true }
                if let id = entity.id, stackItemIds.contains(id) { return true }
                if let tagsData = entity.tags,
                   let tags = try? JSONDecoder().decode([String].self, from: tagsData),
                   tags.parsedTags().contains(where: \.isPinboard) {
                    return true
                }
                return false
            }
            
            // 1) Time-based retention
            if let cutoff = retentionCutoffDate(preset: retentionPreset) {
                let toDelete = items.filter { entity in
                    guard let createdAt = entity.createdAt else { return false }
                    guard createdAt < cutoff else { return false }
                    return !isProtected(entity)
                }
                if !toDelete.isEmpty {
                    for e in toDelete {
                        context.delete(e)
                    }
                    coreDataStack.save()
                    items = try context.fetch(request)
                }
            }
            
            // 2) Count-based retention: delete oldest non-protected items that exceed the limit.
            if items.count > maxItems {
                let itemsToDelete = items.suffix(from: maxItems).filter { !isProtected($0) }
                for item in itemsToDelete {
                    context.delete(item)
                }
                coreDataStack.save()
            }
        } catch {
            print("Cleanup error: \(error)")
        }
    }
    
    private func retentionCutoffDate(preset: AppSettings.RetentionPreset) -> Date? {
        let calendar = Calendar.current
        let now = Date()
        switch preset {
        case .day:
            return calendar.date(byAdding: .day, value: -1, to: now)
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: now)
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: now)
        case .year:
            return calendar.date(byAdding: .year, value: -1, to: now)
        case .unlimited:
            return nil
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let clipboardItemAdded = Notification.Name("clipboardItemAdded")
}
