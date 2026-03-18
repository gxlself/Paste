//
//  AppNotification.swift
//  Paste
//
//  Typed namespace for all Notification.Name values used across the app.
//  Import this file to get auto-complete and avoid stringly-typed lookups.
//

import Foundation

enum AppNotification {
    /// The main panel has finished appearing; SwiftUI views should reveal themselves.
    static let panelDidShow         = Notification.Name("panelDidShow")
    /// The main panel is about to hide; SwiftUI views should start their slide-out animation.
    static let panelWillHide        = Notification.Name("panelWillHide")
    /// The main panel has been ordered out.
    static let panelDidHide         = Notification.Name("panelDidHide")
    /// Receiver should hide the panel, activate the previous app, and simulate Cmd+V.
    static let requestCloseAndPaste = Notification.Name("requestCloseAndPaste")
    /// Close-panel-only variant: content is already on the clipboard; do NOT simulate Cmd+V.
    static let requestClosePanel    = Notification.Name("requestClosePanel")
    /// The user's selected clipboard item index changed; the preview window should update.
    static let selectedIndexChanged  = Notification.Name("selectedIndexChanged")
    /// A clipboard card drag gesture began; object is the ClipboardItemModel being dragged.
    static let clipboardItemDragBegan = Notification.Name("clipboardItemDragBegan")
    /// A clipboard card drag gesture ended; userInfo["location"] carries the drop NSPoint.
    static let clipboardItemDragEnded = Notification.Name("clipboardItemDragEnded")
}
