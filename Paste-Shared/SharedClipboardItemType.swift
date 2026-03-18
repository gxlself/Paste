// SharedClipboardItemType.swift
// Paste-Shared
//
// Cross-platform ClipboardItemType — no AppKit dependency.
// Add this file to: Paste-iOS target AND Paste-Keyboard target.

import Foundation

enum ClipboardItemType: Int16 {
    case text  = 0
    case image = 1
    case file  = 2

    var iconName: String {
        switch self {
        case .text:  return "doc.text"
        case .image: return "photo"
        case .file:  return "folder"
        }
    }

    var displayName: String {
        switch self {
        case .text:  return String(localized: "clipboard.type.text",  bundle: .main)
        case .image: return String(localized: "clipboard.type.image", bundle: .main)
        case .file:  return String(localized: "clipboard.type.file",  bundle: .main)
        }
    }
}
