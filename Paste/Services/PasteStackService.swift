//
//  PasteStackService.swift
//  Paste
//
//  Manage Paste Stack entries (CoreData).
//

import Foundation
import CoreData

final class PasteStackService {
    static let shared = PasteStackService()
    
    private let coreDataStack = CoreDataStack.shared
    
    private init() {}
    
    struct Entry: Identifiable, Equatable {
        let id: UUID
        let itemId: UUID
        let createdAt: Date
    }
    
    func fetchEntries() -> [Entry] {
        let context = coreDataStack.viewContext
        let request: NSFetchRequest<StackEntryEntity> = StackEntryEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \StackEntryEntity.createdAt, ascending: false)]
        
        do {
            return try context.fetch(request).compactMap { entity in
                guard let id = entity.id, let itemId = entity.itemId, let createdAt = entity.createdAt else { return nil }
                return Entry(id: id, itemId: itemId, createdAt: createdAt)
            }
        } catch {
            print("PasteStack fetch error: \(error)")
            return []
        }
    }
    
    func push(itemId: UUID) {
        let context = coreDataStack.viewContext
        let entry = StackEntryEntity(context: context)
        entry.id = UUID()
        entry.itemId = itemId
        entry.createdAt = Date()
        coreDataStack.save()
    }
    
    func remove(entryId: UUID) {
        let context = coreDataStack.viewContext
        let request: NSFetchRequest<StackEntryEntity> = StackEntryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", entryId as CVarArg)
        request.fetchLimit = 1
        
        do {
            if let entity = try context.fetch(request).first {
                context.delete(entity)
                coreDataStack.save()
            }
        } catch {
            print("PasteStack remove error: \(error)")
        }
    }
    
    /// Remove the newest entry referencing the given itemId (LIFO per item).
    func removeTopEntry(for itemId: UUID) {
        let context = coreDataStack.viewContext
        let request: NSFetchRequest<StackEntryEntity> = StackEntryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "itemId == %@", itemId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \StackEntryEntity.createdAt, ascending: false)]
        request.fetchLimit = 1
        
        do {
            if let entity = try context.fetch(request).first {
                context.delete(entity)
                coreDataStack.save()
            }
        } catch {
            print("PasteStack removeTopEntry error: \(error)")
        }
    }
    
    func clear() {
        let context = coreDataStack.viewContext
        let request: NSFetchRequest<NSFetchRequestResult> = StackEntryEntity.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        
        do {
            try context.execute(deleteRequest)
            coreDataStack.save()
        } catch {
            print("PasteStack clear error: \(error)")
        }
    }
}

