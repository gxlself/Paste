//
//  SourceAppIconCache.swift
//  Paste
//
//  Memoised source-application icons for the card badge.
//

import AppKit

/// `NSWorkspace.urlForApplication(withBundleIdentifier:)` + `icon(forFile:)` hits Launch
/// Services on every call. The card badge asked for it inside the view body, so a panel full
/// of cards repeated the lookup on every render pass. Bundle ids repeat constantly across a
/// clipboard history, so cache the result — including the misses.
@MainActor
enum SourceAppIconCache {

    private static var cache: [String: NSImage?] = [:]

    static func icon(forBundleId bundleId: String?) -> NSImage? {
        guard let bundleId else { return nil }
        if let cached = cache[bundleId] { return cached }

        let icon = NSWorkspace.shared
            .urlForApplication(withBundleIdentifier: bundleId)
            .map { NSWorkspace.shared.icon(forFile: $0.path) }
        cache[bundleId] = icon
        return icon
    }

    /// Drops the cache so newly installed or updated apps are picked up.
    static func invalidate() {
        cache.removeAll()
    }
}
