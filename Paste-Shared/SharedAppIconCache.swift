// SharedAppIconCache.swift
// Paste-Shared
//
// Reads the deduplicated per-bundle-id icons written by the macOS client.
//
// Add this file to: Paste-iOS target AND Paste-Keyboard target.

import Foundation
import CoreData

#if canImport(UIKit)
import UIKit
#endif

/// Older items carry their own `appIconData` copy; newer ones reference `AppIconEntity` through
/// the bundle id. Look-ups are memoised because the card grid asks for them while scrolling.
enum SharedAppIconCache {

    private static var cache: [String: Data?] = [:]
    private static let lock = NSLock()

    static func iconData(forBundleId bundleId: String?) -> Data? {
        guard let bundleId, !bundleId.isEmpty else { return nil }

        lock.lock()
        if let cached = cache[bundleId] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let context = SharedCoreDataStack.shared.viewContext
        var data: Data?
        context.performAndWait {
            let request = NSFetchRequest<NSManagedObject>(entityName: "AppIconEntity")
            request.predicate = NSPredicate(format: "bundleId == %@", bundleId)
            request.fetchLimit = 1
            data = (try? context.fetch(request))?.first?.value(forKey: "iconData") as? Data
        }

        lock.lock()
        cache[bundleId] = data
        lock.unlock()
        return data
    }

    /// Drops memoised look-ups after a sync brings new icons down.
    static func invalidate() {
        lock.lock()
        cache.removeAll()
        lock.unlock()
    }
}
