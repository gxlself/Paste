//
//  ImageCompressor.swift
//  Paste
//
//  Shrinks oversized clipboard images before they are persisted (and mirrored to iCloud).
//

import Foundation
import ImageIO
import UniformTypeIdentifiers
import CoreGraphics

/// Stored clipboard images dominate both the local store and the CloudKit container: screenshots
/// arrive as full-resolution PNG, which is typically an order of magnitude larger than it needs
/// to be for a clipboard history.
///
/// Only images above `sizeThreshold` are touched, so ordinary small copies stay byte-identical.
enum ImageCompressor {

    /// Images at or below this stay untouched.
    static let sizeThreshold = 1_024 * 1_024

    /// Longest edge kept after downsampling.
    static let maxPixelSize: CGFloat = 2_048

    /// HEIC quality. 0.8 is visually indistinguishable for screenshots and UI captures.
    static let quality: CGFloat = 0.8

    /// Returns the data to persist: a smaller re-encode when that is worth doing, otherwise the
    /// original. Never returns something larger than what it was given.
    static func compressedForStorage(_ data: Data?) -> Data? {
        guard let data, data.count > sizeThreshold else { return data }
        guard let compressed = compress(data), compressed.count < data.count else { return data }
        return compressed
    }

    // MARK: - Internals

    private static func compress(_ data: Data) -> Data? {
        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions as CFDictionary) else {
            return nil
        }

        // Downsample only when the image is actually bigger than the cap; otherwise re-encode
        // at full resolution and let the codec do the work.
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        let cgImage: CGImage?
        if let size = pixelSize(of: source), max(size.width, size.height) > maxPixelSize {
            cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary)
        } else {
            cgImage = CGImageSourceCreateImageAtIndex(source, 0, sourceOptions as CFDictionary)
        }
        guard let cgImage else { return nil }

        // HEIC keeps alpha, so screenshots with transparency survive. PNG is the fallback for
        // images with alpha on the rare system where HEIC encoding is unavailable.
        if let heic = encode(cgImage, as: UTType.heic.identifier as CFString, lossy: true) {
            return heic
        }
        if cgImage.alphaInfo == .none || cgImage.alphaInfo == .noneSkipFirst || cgImage.alphaInfo == .noneSkipLast,
           let jpeg = encode(cgImage, as: UTType.jpeg.identifier as CFString, lossy: true) {
            return jpeg
        }
        return encode(cgImage, as: UTType.png.identifier as CFString, lossy: false)
    }

    private static func pixelSize(of source: CGImageSource) -> CGSize? {
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = props[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = props[kCGImagePropertyPixelHeight] as? CGFloat else { return nil }
        return CGSize(width: width, height: height)
    }

    private static func encode(_ image: CGImage, as type: CFString, lossy: Bool) -> Data? {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, type, 1, nil) else { return nil }

        let properties: [CFString: Any] = lossy ? [kCGImageDestinationLossyCompressionQuality: quality] : [:]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}
