//
//  CoreDataStack.swift
//  Paste
//
//  CoreData stack management
//

import CoreData

class CoreDataStack {
    
    static let shared = CoreDataStack()
    
    private init() {}
    
    // MARK: - Persistent Container
    
    lazy var persistentContainer: NSPersistentCloudKitContainer = {
        let container = NSPersistentCloudKitContainer(name: "PasteTool")
        
        // Configure store options.
        let description = container.persistentStoreDescriptions.first
        description?.shouldMigrateStoreAutomatically = true
        description?.shouldInferMappingModelAutomatically = true

        // CloudKit mirroring requires WAL journalling, but nothing caps the WAL on its own —
        // it had grown to a few hundred MB, and every read has to walk it. Let SQLite truncate
        // it back down after each checkpoint.
        description?.setOption(
            ["journal_mode": "WAL", "journal_size_limit": "4194304"] as NSDictionary,
            forKey: NSSQLitePragmasOption
        )
        
        // Enable remote change notifications & history for CloudKit sync.
        description?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        if AppSettings.iCloudSyncEnabled {
            description?.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: Constants.iCloudContainerIdentifier
            )
        } else {
            description?.cloudKitContainerOptions = nil
        }
        
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                // In production a more graceful recovery should be attempted.
                fatalError("CoreData failed to load: \(error), \(error.userInfo)")
            }
        }
        
        // Automatically merge changes from the persistent store.
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return container
    }()
    
    // MARK: - Context
    
    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    /// Creates a private-queue background context.
    func newBackgroundContext() -> NSManagedObjectContext {
        persistentContainer.newBackgroundContext()
    }
    
    // MARK: - Save
    
    func save() {
        let context = viewContext
        
        guard context.hasChanges else { return }
        
        do {
            try context.save()
        } catch {
            print("CoreData save failed: \(error)")
        }
    }
    
    /// Performs a save on a background context.
    func saveInBackground(_ block: @escaping (NSManagedObjectContext) -> Void) {
        let context = newBackgroundContext()
        context.perform {
            block(context)
            
            if context.hasChanges {
                do {
                    try context.save()
                } catch {
                    print("CoreData background save failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - CloudKit schema

    #if DEBUG
    /// Publishes the current Core Data model to the CloudKit **Development** schema.
    ///
    /// CloudKit only auto-creates record types in Development, and only when a record of that
    /// type is actually exported — so a newly added entity stays invisible until something
    /// happens to use it. Production never auto-creates anything at all. After running this,
    /// deploy Development → Production in the CloudKit Dashboard.
    ///
    /// Run from a development-signed build (Debug configuration):
    ///     Paste.app/Contents/MacOS/Paste --initialize-cloudkit-schema
    ///
    /// - Returns: true when the launch argument was present and handled.
    func initializeCloudKitSchemaIfRequested() -> Bool {
        let wantsUpload = CommandLine.arguments.contains("--initialize-cloudkit-schema")
        // `--print-cloudkit-schema` is the offline variant: it derives the record types from the
        // model and prints them without contacting CloudKit, which is useful when the upload
        // path keeps hitting its fixed 30s timeout.
        let wantsPrint = CommandLine.arguments.contains("--print-cloudkit-schema")
        guard wantsUpload || wantsPrint else { return false }

        guard ICloudCapability.environment == .development else {
            print("Refusing to initialize schema: build targets the \(ICloudCapability.environment.rawValue) "
                  + "CloudKit environment. Use a Debug (development-signed) build.")
            exit(1)
        }

        // Deliberately not `persistentContainer`: loading that would migrate the real store
        // (and fight the copy of the app the user already has running). The schema is derived
        // from the model, so a throwaway store publishes exactly the same record types.
        let scratchURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("PasteSchemaInit-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: scratchURL) }

        let container = NSPersistentCloudKitContainer(name: "PasteTool")
        let description = NSPersistentStoreDescription(url: scratchURL)
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: Constants.iCloudContainerIdentifier
        )
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError {
            print("Failed to open scratch store: \(loadError)")
            exit(1)
        }

        do {
            let options: NSPersistentCloudKitContainerSchemaInitializationOptions =
                wantsPrint ? [.dryRun, .printSchema] : []
            try container.initializeCloudKitSchema(options: options)
            if wantsPrint {
                print("--- schema printed above (dry run, nothing uploaded) ---")
            } else {
                print("CloudKit Development schema initialized from the current model.")
                print("Next: CloudKit Dashboard -> Schema -> Deploy Schema Changes.")
            }
            exit(0)
        } catch {
            print("initializeCloudKitSchema failed: \(error)")
            exit(1)
        }
    }
    #endif

    // MARK: - Maintenance

    /// Drops persistent-history transactions older than `days`.
    ///
    /// CloudKit mirroring records a history transaction for every change and never prunes them,
    /// so the history tables (and with them the WAL) grow without bound. Only history that has
    /// already been exported may be deleted — a week of head-room is what Apple's own sample
    /// code uses.
    func purgeOldHistory(olderThan days: Int = 7) {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else { return }

        let context = newBackgroundContext()
        context.perform {
            let request = NSPersistentHistoryChangeRequest.deleteHistory(before: cutoff)
            do {
                try context.execute(request)
            } catch {
                print("CoreData history purge failed: \(error)")
            }
        }
    }

    // MARK: - Sync helpers
    
    /// Best-effort: trigger a save and let CloudKit container schedule pushes.
    /// - Parameter completion: Called on main queue with nil on success or the save error.
    func requestSyncNow(completion: ((Error?) -> Void)? = nil) {
        let context = viewContext
        context.perform {
            var saveError: Error?
            do {
                if context.hasChanges {
                    try context.save()
                }
            } catch {
                print("CoreData syncNow save failed: \(error)")
                saveError = error
            }
            if let completion {
                DispatchQueue.main.async { completion(saveError) }
            }
        }
    }
}
