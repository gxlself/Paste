//
//  PasteActivityAttributes.swift
//  Paste-LiveActivity
//
//  Shared by the iOS app (starts/updates the activity) and the widget extension (renders it).
//

import ActivityKit
import Foundation

@available(iOS 16.1, *)
nonisolated struct PasteActivityAttributes: ActivityAttributes {

    nonisolated struct ContentState: Codable, Hashable {

        nonisolated enum Kind: String, Codable, Hashable {
            case text, link, image, file

            var symbol: String {
                switch self {
                case .text:  return "text.alignleft"
                case .link:  return "link"
                case .image: return "photo"
                case .file:  return "doc"
                }
            }
        }

        nonisolated struct Entry: Codable, Hashable, Identifiable {
            /// `ClipboardItem` id (UUID string).
            var id: String
            /// Already truncated; empty when the user chose to hide previews.
            var preview: String
            var kind: Kind
        }

        /// Newest first, capped by the app (state payload is limited to ~4 KB).
        var entries: [Entry]
    }

    var name: String
}
