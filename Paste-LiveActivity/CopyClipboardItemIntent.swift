//
//  CopyClipboardItemIntent.swift
//  Paste-LiveActivity
//
//  Tapping an entry in the Dynamic Island copies it without opening the app (iOS 17+).
//  A `LiveActivityIntent` runs in the app's process; the app installs `LiveActivityBridge.copyHandler`
//  at launch (also on background launches), so this file stays free of app-only types.
//

import AppIntents
import Foundation

nonisolated enum LiveActivityBridge {
    /// Set by the app; receives the `ClipboardItem` id string.
    nonisolated(unsafe) static var copyHandler: (@Sendable (String) -> Void)?
}

@available(iOS 17.0, *)
nonisolated struct CopyClipboardItemIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Copy"
    static var openAppWhenRun = false

    @Parameter(title: "Item")
    var itemID: String

    init() {}

    init(itemID: String) {
        self.itemID = itemID
    }

    func perform() async throws -> some IntentResult {
        LiveActivityBridge.copyHandler?(itemID)
        return .result()
    }
}
