//
//  ClipboardItem.swift
//  Paste
//
//  Clipboard item model (view layer)
//

import Foundation
import AppKit
import UniformTypeIdentifiers

private enum ClipboardFileIconCache {
    static let cache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 128
        return cache
    }()

    static func icon(for path: String) -> NSImage? {
        let key = path as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        let icon = NSWorkspace.shared.icon(forFile: path)
        cache.setObject(icon, forKey: key)
        return icon
    }
}

/// View-layer snapshot of a clipboard item.
struct ClipboardItemModel: Identifiable, Equatable {
    let id: UUID
    let itemType: ClipboardItemType
    let plainText: String?
    let rtfData: Data?
    let imageData: Data?
    let appBundleId: String?
    let appIconData: Data?
    let createdAt: Date
    let contentHash: String
    let isPinned: Bool

    /// File paths, decoded once at init. Decoding lazily meant re-running JSONDecoder on
    /// every access — several times per row per filter pass with thousands of rows.
    let filePathsArray: [String]?
    /// Raw tag strings, decoded once at init.
    let tagsArray: [String]
    /// Typed tags, parsed once at init. Use this instead of `tagsArray.parsedTags()` in hot paths.
    let parsedTags: [ItemTag]

    // MARK: - Computed Properties
    
    /// Display text for list preview.
    var displayText: String {
        switch itemType {
        case .text:
            return plainText ?? ""
        case .image:
            return String(localized: "clipboard.item.placeholder.image")
        case .file:
            if let paths = filePathsArray {
                return paths.map { URL(fileURLWithPath: $0).lastPathComponent }.joined(separator: ", ")
            }
            return String(localized: "clipboard.item.placeholder.file")
        }
    }
    
    /// Thumbnail image (image items only).
    var thumbnail: NSImage? {
        guard itemType == .image, let data = imageData else { return nil }
        return NSImage(data: data)
    }
    
    /// Whether this is a single-file item whose extension is a known image type.
    /// Used to decide whether to show a thumbnail preview instead of the generic file view.
    var isImageFile: Bool {
        guard itemType == .file,
              let paths = filePathsArray,
              paths.count == 1 else { return false }
        let ext = URL(fileURLWithPath: paths[0]).pathExtension
        return UTType(filenameExtension: ext)?.conforms(to: .image) ?? false
    }

    /// File icon (file items only).
    var fileIcon: NSImage? {
        guard itemType == .file, let paths = filePathsArray, let firstPath = paths.first else { return nil }
        return ClipboardFileIconCache.icon(for: firstPath)
    }
    
    /// Icon of the source application.
    var sourceAppIcon: NSImage? {
        guard let bundleId = appBundleId,
              let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: appURL.path)
    }
    
    /// Display name of the source application.
    var sourceAppName: String? {
        guard let bundleId = appBundleId,
              let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            return nil
        }
        return FileManager.default.displayName(atPath: appURL.path)
    }
    
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    private static let detailedDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var formattedTime: String {
        Self.relativeFormatter.localizedString(for: createdAt, relativeTo: Date())
    }
    
    var detailedTime: String {
        Self.detailedDateFormatter.string(from: createdAt)
    }
    
    /// Character count (text items only).
    var characterCount: Int? {
        guard itemType == .text else { return nil }
        return plainText?.count
    }
    
    /// Image dimension string (image items only).
    var imageSizeInfo: String? {
        guard itemType == .image, let image = thumbnail else { return nil }
        return "\(Int(image.size.width)) × \(Int(image.size.height))"
    }
    
    /// Number of files (file items only).
    var fileCount: Int? {
        guard itemType == .file else { return nil }
        return filePathsArray?.count
    }
    
    // MARK: - Initializers
    
    init(entity: ClipboardItemEntity, loadBinaryData: Bool = true) {
        self.id = entity.id ?? UUID()
        self.itemType = ClipboardItemType(rawValue: entity.type) ?? .text
        self.plainText = entity.plainText
        self.rtfData = loadBinaryData ? entity.rtfData : nil
        self.imageData = loadBinaryData ? entity.imageData : nil
        self.filePathsArray = Self.decodeStrings(entity.filePaths)
        self.appBundleId = entity.appBundleId
        // macOS draws the source-app badge live from NSWorkspace; the stored PNG only exists
        // for the iOS client. It averages ~10 KB per row, so never pull it into list fetches.
        self.appIconData = loadBinaryData ? entity.appIconData : nil
        self.createdAt = entity.createdAt ?? Date()
        self.contentHash = entity.contentHash ?? ""
        self.isPinned = entity.isPinned
        let tags = Self.decodeStrings(entity.tags) ?? []
        self.tagsArray = tags
        self.parsedTags = tags.parsedTags()
    }

    /// Builds a model from a dictionary-result fetch (see `ClipboardService.listProperties`).
    /// Dictionary fetches read only the requested columns, so the binary blobs stay on disk.
    init?(dictionary: NSDictionary) {
        guard let id = dictionary["id"] as? UUID else { return nil }
        self.id = id
        self.itemType = ClipboardItemType(rawValue: (dictionary["type"] as? NSNumber)?.int16Value ?? 0) ?? .text
        self.plainText = dictionary["plainText"] as? String
        self.rtfData = nil
        self.imageData = nil
        self.filePathsArray = Self.decodeStrings(dictionary["filePaths"] as? Data)
        self.appBundleId = dictionary["appBundleId"] as? String
        self.appIconData = nil
        self.createdAt = (dictionary["createdAt"] as? Date) ?? Date()
        self.contentHash = (dictionary["contentHash"] as? String) ?? ""
        self.isPinned = (dictionary["isPinned"] as? NSNumber)?.boolValue ?? false
        let tags = Self.decodeStrings(dictionary["tags"] as? Data) ?? []
        self.tagsArray = tags
        self.parsedTags = tags.parsedTags()
    }

    private static func decodeStrings(_ data: Data?) -> [String]? {
        guard let data else { return nil }
        return try? JSONDecoder().decode([String].self, from: data)
    }
    
    // Convenience initialiser for tests.
    init(
        id: UUID = UUID(),
        itemType: ClipboardItemType,
        plainText: String? = nil,
        rtfData: Data? = nil,
        imageData: Data? = nil,
        filePaths: [String]? = nil,
        appBundleId: String? = nil,
        appIconData: Data? = nil,
        createdAt: Date = Date(),
        contentHash: String = "",
        isPinned: Bool = false,
        tags: [String] = []
    ) {
        self.id = id
        self.itemType = itemType
        self.plainText = plainText
        self.rtfData = rtfData
        self.imageData = imageData
        self.filePathsArray = filePaths
        self.appBundleId = appBundleId
        self.appIconData = appIconData
        self.createdAt = createdAt
        self.contentHash = contentHash
        self.isPinned = isPinned
        self.tagsArray = tags
        self.parsedTags = tags.parsedTags()
    }
    
    static func == (lhs: ClipboardItemModel, rhs: ClipboardItemModel) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Time Group

enum TimeGroup: String, CaseIterable {
    case today = "today"
    case yesterday = "yesterday"
    case thisWeek = "thisWeek"
    case earlier = "earlier"
    case pinned = "pinned"

    var displayName: String {
        switch self {
        case .today: return String(localized: "clipboard.timeGroup.today")
        case .yesterday: return String(localized: "clipboard.timeGroup.yesterday")
        case .thisWeek: return String(localized: "clipboard.timeGroup.thisWeek")
        case .earlier: return String(localized: "clipboard.timeGroup.earlier")
        case .pinned: return String(localized: "clipboard.timeGroup.pinned")
        }
    }
    
    static func group(for date: Date, isPinned: Bool) -> TimeGroup {
        if isPinned { return .pinned }
        
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            return .today
        } else if calendar.isDateInYesterday(date) {
            return .yesterday
        } else if let weekAgo = calendar.date(byAdding: .day, value: -7, to: now),
                  date > weekAgo {
            return .thisWeek
        } else {
            return .earlier
        }
    }
}
