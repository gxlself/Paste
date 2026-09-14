//
//  AppIconStore.swift
//  Paste
//
//  Deduplicated storage for source-application icons.
//

import Foundation
import CoreData
import AppKit

/// Every clipboard item used to carry its own copy of the source app's icon PNG in
/// `ClipboardItemEntity.appIconData`. With thousands of rows but only a few dozen distinct apps
/// that is almost entirely duplication — and CloudKit mirrors every copy.
///
/// Icons now live once per bundle id in `AppIconEntity`; items reference them through the
/// `appBundleId` they already store.
final class AppIconStore {

    static let shared = AppIconStore()

    private let coreDataStack = CoreDataStack.shared

    /// Bundle ids already known to have a stored icon, so the common path is a dictionary hit.
    private var knownBundleIds = Set<String>()
    private var didLoadKnownBundleIds = false

    private init() {}

    // MARK: - Write

    /// Stores the icon for `bundleId` if it is not on record yet. Cheap to call on every copy.
    func registerIconIfNeeded(bundleId: String, appURL: URL) {
        loadKnownBundleIdsIfNeeded()
        guard !knownBundleIds.contains(bundleId) else { return }

        guard let png = Self.iconPNG(for: appURL) else { return }

        let context = coreDataStack.viewContext
        let entity = existingEntity(bundleId: bundleId, in: context) ?? AppIconEntity(context: context)
        entity.bundleId = bundleId
        entity.iconData = png
        entity.updatedAt = Date()
        knownBundleIds.insert(bundleId)
        coreDataStack.save()
    }

    // MARK: - Read

    /// Icon bytes for a bundle id, or nil when none has been recorded.
    func iconData(for bundleId: String) -> Data? {
        let context = coreDataStack.viewContext
        return existingEntity(bundleId: bundleId, in: context)?.iconData
    }

    // MARK: - Compaction

    /// Moves every per-item icon into `AppIconEntity` and clears the duplicated copies.
    ///
    /// This rewrites each affected row, so CloudKit has to push one update per item — it is a
    /// deliberate, user-triggered action rather than something that runs at launch.
    /// - Returns: the number of rows whose icon copy was cleared.
    @discardableResult
    func compactDuplicatedIcons() -> Int {
        let context = coreDataStack.viewContext

        let request: NSFetchRequest<ClipboardItemEntity> = ClipboardItemEntity.fetchRequest()
        request.predicate = NSPredicate(format: "appIconData != nil")
        request.fetchBatchSize = 200

        guard let items = try? context.fetch(request), !items.isEmpty else { return 0 }

        loadKnownBundleIdsIfNeeded()
        var cleared = 0

        for item in items {
            // Keep one copy per bundle id before dropping the rest.
            if let bundleId = item.appBundleId, !bundleId.isEmpty {
                if !knownBundleIds.contains(bundleId), let data = item.appIconData {
                    let entity = existingEntity(bundleId: bundleId, in: context) ?? AppIconEntity(context: context)
                    entity.bundleId = bundleId
                    entity.iconData = data
                    entity.updatedAt = Date()
                    knownBundleIds.insert(bundleId)
                }
            }
            item.appIconData = nil
            cleared += 1
        }

        coreDataStack.save()
        return cleared
    }

    /// Number of rows still carrying a duplicated icon copy.
    func duplicatedIconCount() -> Int {
        let context = coreDataStack.viewContext
        let request: NSFetchRequest<ClipboardItemEntity> = ClipboardItemEntity.fetchRequest()
        request.predicate = NSPredicate(format: "appIconData != nil")
        return (try? context.count(for: request)) ?? 0
    }

    // MARK: - Internals

    private func existingEntity(bundleId: String, in context: NSManagedObjectContext) -> AppIconEntity? {
        let request: NSFetchRequest<AppIconEntity> = AppIconEntity.fetchRequest()
        request.predicate = NSPredicate(format: "bundleId == %@", bundleId)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    private func loadKnownBundleIdsIfNeeded() {
        guard !didLoadKnownBundleIds else { return }
        didLoadKnownBundleIds = true

        let context = coreDataStack.viewContext
        let request = NSFetchRequest<NSDictionary>(entityName: "AppIconEntity")
        request.resultType = .dictionaryResultType
        request.propertiesToFetch = ["bundleId"]
        request.includesPendingChanges = false

        let rows = (try? context.fetch(request)) ?? []
        knownBundleIds = Set(rows.compactMap { $0["bundleId"] as? String })
    }

    /// Renders an app icon down to a 64×64 PNG.
    private static func iconPNG(for appURL: URL) -> Data? {
        let icon = NSWorkspace.shared.icon(forFile: appURL.path)
        let targetSize = NSSize(width: 64, height: 64)
        let resized = NSImage(size: targetSize)
        resized.lockFocus()
        icon.draw(in: NSRect(origin: .zero, size: targetSize),
                  from: NSRect(origin: .zero, size: icon.size),
                  operation: .copy, fraction: 1.0)
        resized.unlockFocus()

        guard let tiff = resized.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}
