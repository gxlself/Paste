//
//  Persistence.swift
//  Paste-iOS
//
//
//  Copyright © 2026 Gxlself. All rights reserved.
//

import CoreData

/// Thin wrapper that delegates to SharedCoreDataStack (App Group container).
/// This keeps the iOS app and keyboard extension reading from the same SQLite store.
struct PersistenceController {

    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init() {
        container = SharedCoreDataStack.shared.persistentContainer
    }

    var viewContext: NSManagedObjectContext {
        container.viewContext
    }
}
