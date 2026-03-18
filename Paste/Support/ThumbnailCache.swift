//
//  ThumbnailCache.swift
//  Paste
//
//  Image thumbnail cache for macOS: uses CGImageSource for efficient downsampling
//  to avoid decoding full-resolution image data into memory.
//

import AppKit
import CoreData
import ImageIO

@MainActor
final class ThumbnailCache {

    static let shared = ThumbnailCache()

    private let cache = NSCache<NSString, NSImage>()
    private let maxPixelSize: CGFloat = 300

    private init() {
        cache.countLimit = 200
        cache.totalCostLimit = 30 * 1024 * 1024 // 30 MB
    }

    func thumbnail(for itemID: UUID) -> NSImage? {
        let key = itemID.uuidString as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        guard let data = Self.loadImageData(for: itemID) else { return nil }
        guard let thumb = Self.downsample(data: data, maxPixelSize: maxPixelSize) else { return nil }
        cache.setObject(thumb, forKey: key)
        return thumb
    }

    func invalidate(_ itemID: UUID) {
        cache.removeObject(forKey: itemID.uuidString as NSString)
    }

    func clearAll() {
        cache.removeAllObjects()
    }

    // MARK: - Full-resolution helpers (for preview / paste)

    nonisolated static func fullImage(for itemID: UUID) -> NSImage? {
        guard let data = loadImageData(for: itemID) else { return nil }
        return NSImage(data: data)
    }

    nonisolated static func imageDimensions(for itemID: UUID) -> (width: Int, height: Int)? {
        guard let data = loadImageData(for: itemID) else { return nil }
        return imageDimensions(from: data)
    }

    nonisolated static func imageDimensions(from data: Data) -> (width: Int, height: Int)? {
        let opts: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let src = CGImageSourceCreateWithData(data as CFData, opts as CFDictionary),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int,
              let h = props[kCGImagePropertyPixelHeight] as? Int else { return nil }
        return (w, h)
    }

    // MARK: - CoreData lazy data loading

    nonisolated static func loadImageData(for itemID: UUID) -> Data? {
        let ctx = CoreDataStack.shared.viewContext
        var result: Data?
        ctx.performAndWait {
            let req: NSFetchRequest<ClipboardItemEntity> = ClipboardItemEntity.fetchRequest()
            req.predicate = NSPredicate(format: "id == %@", itemID as CVarArg)
            req.fetchLimit = 1
            result = (try? ctx.fetch(req))?.first?.imageData
        }
        return result
    }

    nonisolated static func loadRtfData(for itemID: UUID) -> Data? {
        let ctx = CoreDataStack.shared.viewContext
        var result: Data?
        ctx.performAndWait {
            let req: NSFetchRequest<ClipboardItemEntity> = ClipboardItemEntity.fetchRequest()
            req.predicate = NSPredicate(format: "id == %@", itemID as CVarArg)
            req.fetchLimit = 1
            result = (try? ctx.fetch(req))?.first?.rtfData
        }
        return result
    }

    // MARK: - Efficient downsampling via ImageIO

    nonisolated private static func downsample(data: Data, maxPixelSize: CGFloat) -> NSImage? {
        let sourceOpts: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOpts as CFDictionary) else {
            return nil
        }
        let thumbOpts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOpts as CFDictionary) else {
            return nil
        }
        return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
    }
}
