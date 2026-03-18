//
//  ClipboardItem.swift
//  Paste
//
//  Clipboard item model (view layer)
//

import Foundation
import AppKit
import UniformTypeIdentifiers

/// View-layer snapshot of a clipboard item.
struct ClipboardItemModel: Identifiable, Equatable {
    let id: UUID
    let itemType: ClipboardItemType
    let plainText: String?
    let rtfData: Data?
    let imageData: Data?
    private let filePathsData: Data?
    let appBundleId: String?
    let appIconData: Data?
    let createdAt: Date
    let contentHash: String
    let isPinned: Bool
    private let tagsData: Data?
    
    // MARK: - Computed Properties
    
    /// Decodes the file paths JSON array.
    var filePathsArray: [String]? {
        guard let data = filePathsData else { return nil }
        return try? JSONDecoder().decode([String].self, from: data)
    }
    
    /// Decodes the tags JSON array.
    var tagsArray: [String] {
        guard let data = tagsData else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }
    
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
        return NSWorkspace.shared.icon(forFile: firstPath)
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
        self.filePathsData = entity.filePaths
        self.appBundleId = entity.appBundleId
        self.appIconData = entity.appIconData
        self.createdAt = entity.createdAt ?? Date()
        self.contentHash = entity.contentHash ?? ""
        self.isPinned = entity.isPinned
        self.tagsData = entity.tags
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
        self.filePathsData = filePaths != nil ? try? JSONEncoder().encode(filePaths) : nil
        self.appBundleId = appBundleId
        self.appIconData = appIconData
        self.createdAt = createdAt
        self.contentHash = contentHash
        self.isPinned = isPinned
        self.tagsData = !tags.isEmpty ? try? JSONEncoder().encode(tags) : nil
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
