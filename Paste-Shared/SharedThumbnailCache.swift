//
//  ThumbnailCache.swift
//  Paste-Shared
//
//  Image thumbnail cache for iOS / Keyboard: uses CGImageSource for efficient downsampling
//  with NSCache for automatic eviction to prevent memory pressure.
//  Add this file to: Paste-iOS target AND Paste-Keyboard target.
//

#if canImport(UIKit)
import UIKit
import CoreData
import ImageIO

final class SharedThumbnailCache {

    static let shared = SharedThumbnailCache()

    private let cache = NSCache<NSString, UIImage>()
    private let maxPixelSize: CGFloat

    init(maxPixelSize: CGFloat = 200, countLimit: Int = 150, totalCostLimit: Int = 20_000_000) {
        self.maxPixelSize = maxPixelSize
        cache.countLimit = countLimit
        cache.totalCostLimit = totalCostLimit
    }

    func thumbnail(for itemID: UUID) -> UIImage? {
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

    static func fullImage(for itemID: UUID) -> UIImage? {
        guard let data = loadImageData(for: itemID) else { return nil }
        return UIImage(data: data)
    }

    // MARK: - CoreData lazy data loading

    static func loadImageData(for itemID: UUID) -> Data? {
        let ctx = SharedCoreDataStack.shared.viewContext
        var result: Data?
        ctx.performAndWait {
            let req: NSFetchRequest<ClipboardItemEntity> = ClipboardItemEntity.fetchRequest()
            req.predicate = NSPredicate(format: "id == %@", itemID as CVarArg)
            req.fetchLimit = 1
            result = (try? ctx.fetch(req))?.first?.imageData
        }
        return result
    }

    static func loadRtfData(for itemID: UUID) -> Data? {
        let ctx = SharedCoreDataStack.shared.viewContext
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

    private static func downsample(data: Data, maxPixelSize: CGFloat) -> UIImage? {
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
        return UIImage(cgImage: cg)
    }
}
#endif // canImport(UIKit)
