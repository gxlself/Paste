// SharedCoreDataStack.swift
// Paste-Shared
//
// CoreData stack backed by an App Group container so both the iOS app
// and the keyboard extension read/write the same SQLite store.
// Uses NSPersistentCloudKitContainer for iCloud sync when enabled.
//
// App Group ID: group.gxlself.paste-tool
// Add this file to: Paste-iOS target AND Paste-Keyboard target.

import CoreData

final class SharedCoreDataStack {

    static let shared = SharedCoreDataStack()

    /// Set to `true` in the keyboard extension — opens the store read-only
    /// to avoid write conflicts if the extension and the app are both active.
    var isReadOnly: Bool = false

    private init() {}

    // MARK: - iCloud settings

    private var iCloudSyncEnabled: Bool {
        let ud = UserDefaults(suiteName: "group.gxlself.paste-tool") ?? .standard
        return ud.bool(forKey: "iCloudSyncEnabled")
    }

    private static let iCloudContainerID = "iCloud.gxlself.paste-tool"

    private var isAppExtension: Bool {
        Bundle.main.bundlePath.hasSuffix(".appex")
    }

    // MARK: - Persistent container

    lazy var persistentContainer: NSPersistentContainer = {
        let useCloudKit = iCloudSyncEnabled && !isAppExtension
        let container: NSPersistentContainer

        if let modelURL = Bundle.main.url(forResource: "PasteTool", withExtension: "momd"),
           let model = NSManagedObjectModel(contentsOf: modelURL) {
            if useCloudKit {
                container = NSPersistentCloudKitContainer(name: "PasteTool", managedObjectModel: model)
            } else {
                container = NSPersistentContainer(name: "PasteTool", managedObjectModel: model)
            }
        } else {
            if useCloudKit {
                container = NSPersistentCloudKitContainer(name: "PasteTool")
            } else {
                container = NSPersistentContainer(name: "PasteTool")
            }
        }

        let groupID = "group.gxlself.paste-tool"
        if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: groupID
        ) {
            let storeURL = groupURL.appendingPathComponent("PasteTool.sqlite")
            let desc = NSPersistentStoreDescription(url: storeURL)
            desc.shouldMigrateStoreAutomatically = true
            desc.shouldInferMappingModelAutomatically = true
            desc.isReadOnly = isReadOnly

            desc.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            desc.setOption(
                true as NSNumber,
                forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey
            )

            if useCloudKit {
                desc.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                    containerIdentifier: Self.iCloudContainerID
                )
            } else {
                desc.cloudKitContainerOptions = nil
            }

            container.persistentStoreDescriptions = [desc]
        }

        container.loadPersistentStores { _, error in
            if let error {
                print("SharedCoreDataStack load failed: \(error)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return container
    }()

    // MARK: - Convenience

    var viewContext: NSManagedObjectContext { persistentContainer.viewContext }

    func newBackgroundContext() -> NSManagedObjectContext {
        persistentContainer.newBackgroundContext()
    }

    func save() {
        let ctx = viewContext
        guard ctx.hasChanges else { return }
        do { try ctx.save() }
        catch { print("SharedCoreDataStack save error: \(error)") }
    }
}
