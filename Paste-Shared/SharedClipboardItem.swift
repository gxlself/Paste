// SharedClipboardItem.swift
// Paste-Shared
//
// iOS/iPadOS clipboard item model — no AppKit dependency.
// Uses UIKit for image support.
// Add this file to: Paste-iOS target AND Paste-Keyboard target.

import Foundation
#if canImport(UIKit)
import UIKit
#endif

struct SharedClipboardItem: Identifiable, Equatable, Hashable {

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

    // MARK: - Computed

    var filePathsArray: [String]? {
        guard let data = filePathsData else { return nil }
        return try? JSONDecoder().decode([String].self, from: data)
    }

    var tagsArray: [String] {
        guard let data = tagsData else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }

    var displayText: String {
        switch itemType {
        case .text:
            return plainText ?? ""
        case .image:
            return NSLocalizedString("clipboard.item.placeholder.image",
                                     value: "图片", comment: "")
        case .file:
            return filePathsArray?
                .map { URL(fileURLWithPath: $0).lastPathComponent }
                .joined(separator: ", ")
                ?? NSLocalizedString("clipboard.item.placeholder.file", value: "文件", comment: "")
        }
    }

    #if canImport(UIKit)
    var thumbnail: UIImage? {
        guard itemType == .image, let data = imageData else { return nil }
        return UIImage(data: data)
    }
    #endif

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    var formattedTime: String {
        Self.relativeFormatter.localizedString(for: createdAt, relativeTo: Date())
    }

    var characterCount: Int? {
        guard itemType == .text else { return nil }
        return plainText?.count
    }

    var isImage: Bool { itemType == .image }
    var isText:  Bool { itemType == .text  }

    var detectedURL: URL? {
        guard itemType == .text,
              let text = plainText?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return nil }
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        if let match = detector.firstMatch(in: text, range: range),
           match.range.length > text.count / 2 {
            return match.url
        }
        return nil
    }

    /// User-defined alias stored in the tags array as "alias:xxx".
    var alias: String? {
        guard let name = tagsArray.parsedTags().compactMap(\.aliasValue).first, !name.isEmpty else { return nil }
        return name
    }

    /// Returns the app name written by the macOS client from tags, falling back to the last segment of the bundle ID.
    var sourceAppName: String? {
        if let name = tagsArray.parsedTags().compactMap(\.appNameValue).first, !name.isEmpty {
            return name
        }
        guard let bundleId = appBundleId, !bundleId.isEmpty else { return nil }
        let parts = bundleId.split(separator: ".")
        if let last = parts.last { return String(last).capitalized }
        return nil
    }

    #if canImport(UIKit)
    var sourceAppIcon: UIImage? {
        guard let data = appIconData else { return nil }
        return UIImage(data: data)
    }
    #endif

    // MARK: - Init from CoreData entity

    init(entity: ClipboardItemEntity, loadBinaryData: Bool = true) {
        self.id            = entity.id ?? UUID()
        self.itemType      = ClipboardItemType(rawValue: entity.type) ?? .text
        self.plainText     = entity.plainText
        self.rtfData       = loadBinaryData ? entity.rtfData : nil
        self.imageData     = loadBinaryData ? entity.imageData : nil
        self.filePathsData = entity.filePaths
        self.appBundleId   = entity.appBundleId
        self.appIconData   = entity.appIconData
        self.createdAt     = entity.createdAt ?? Date()
        self.contentHash   = entity.contentHash ?? ""
        self.isPinned      = entity.isPinned
        self.tagsData      = entity.tags
    }

    // MARK: - Preview / manual init

    init(
        id: UUID = UUID(),
        itemType: ClipboardItemType = .text,
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
        self.filePathsData = filePaths.flatMap { try? JSONEncoder().encode($0) }
        self.appBundleId = appBundleId
        self.appIconData = appIconData
        self.createdAt = createdAt
        self.contentHash = contentHash
        self.isPinned = isPinned
        self.tagsData = tags.isEmpty ? nil : (try? JSONEncoder().encode(tags))
    }

    // MARK: - Equatable / Hashable

    static func == (lhs: SharedClipboardItem, rhs: SharedClipboardItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
