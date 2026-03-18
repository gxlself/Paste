// ItemTag.swift
// Paste-Shared
//
// Typed representation of the tag strings stored in ClipboardItemEntity.tags.
// Replaces the scattered string-prefix conventions ("pinboard:0", "alias:My Label", "appName:Safari")
// with a type-safe enum, making typos impossible and intent explicit.

import Foundation

enum ItemTag: Hashable {
    case pinboard(Int)
    case alias(String)
    case appName(String)
    case customType(String)  // associated value is the CustomType.id

    // MARK: - Serialisation

    init?(rawValue: String) {
        if rawValue.hasPrefix("pinboard:") {
            guard let index = Int(rawValue.dropFirst("pinboard:".count)) else { return nil }
            self = .pinboard(index)
        } else if rawValue.hasPrefix("alias:") {
            self = .alias(String(rawValue.dropFirst("alias:".count)))
        } else if rawValue.hasPrefix("appName:") {
            self = .appName(String(rawValue.dropFirst("appName:".count)))
        } else if rawValue.hasPrefix("customType:") {
            self = .customType(String(rawValue.dropFirst("customType:".count)))
        } else {
            return nil
        }
    }

    var rawValue: String {
        switch self {
        case .pinboard(let index):   return "pinboard:\(index)"
        case .alias(let name):       return "alias:\(name)"
        case .appName(let name):     return "appName:\(name)"
        case .customType(let typeId): return "customType:\(typeId)"
        }
    }

    // MARK: - Type checks

    var isPinboard:   Bool { guard case .pinboard   = self else { return false }; return true }
    var isAlias:      Bool { guard case .alias       = self else { return false }; return true }
    var isAppName:    Bool { guard case .appName     = self else { return false }; return true }
    var isCustomType: Bool { guard case .customType  = self else { return false }; return true }

    // MARK: - Associated-value accessors

    var pinboardIndex:  Int?    { guard case .pinboard(let i)    = self else { return nil }; return i }
    var aliasValue:     String? { guard case .alias(let s)       = self else { return nil }; return s }
    var appNameValue:   String? { guard case .appName(let s)     = self else { return nil }; return s }
    var customTypeId:   String? { guard case .customType(let id) = self else { return nil }; return id }
}

// MARK: - Array<String> convenience

extension Array where Element == String {
    /// Parses the raw tag strings into typed ItemTag values, silently dropping unrecognised entries.
    func parsedTags() -> [ItemTag] { compactMap { ItemTag(rawValue: $0) } }
}
