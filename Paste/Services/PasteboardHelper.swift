//
//  PasteboardHelper.swift
//  Paste
//
//  NSPasteboard read/write abstraction
//

import AppKit
import ApplicationServices
import UniformTypeIdentifiers

/// Snapshot of clipboard content read from NSPasteboard.
struct ClipboardContent {
    let type: ClipboardItemType
    let plainText: String?
    let rtfData: Data?
    let imageData: Data?
    let filePaths: [String]?
    let sourceApp: String?
    let contentHash: String
    
    var isEmpty: Bool {
        plainText == nil && imageData == nil && (filePaths?.isEmpty ?? true)
    }
}

class PasteboardHelper {
    
    static let shared = PasteboardHelper()
    
    private let pasteboard = NSPasteboard.general
    
    private init() {}
    
    // MARK: - Read from Pasteboard
    
    /// The current NSPasteboard change count.
    var changeCount: Int {
        pasteboard.changeCount
    }
    
    /// Reads the current clipboard content, returning a ClipboardContent snapshot or nil if empty.
    func readContent() -> ClipboardContent? {
        // Get the source application.
        let sourceApp = getSourceApplication()
        
        // Detect content type in priority order: file > image > text.
        if let filePaths = readFilePaths(), !filePaths.isEmpty {
            if filePaths.count == 1 {
                let filePath = filePaths[0]
                // Try loading pixel data from the file itself.
                if let imageData = Self.imageData(fromFile: filePath) {
                    let hash = HashUtil.sha256(imageData)
                    return ClipboardContent(
                        type: .image,
                        plainText: nil,
                        rtfData: nil,
                        imageData: imageData,
                        filePaths: nil,
                        sourceApp: sourceApp,
                        contentHash: hash
                    )
                }
                // File unreadable (e.g. sandbox restriction): if it is an image extension,
                // fall back to the TIFF/PNG data Finder also places on the pasteboard.
                let url = URL(fileURLWithPath: filePath)
                let isImageExt = UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) ?? false
                if isImageExt, let imageData = readDirectPasteboardImageData() {
                    let hash = HashUtil.sha256(imageData)
                    return ClipboardContent(
                        type: .image,
                        plainText: nil,
                        rtfData: nil,
                        imageData: imageData,
                        filePaths: nil,
                        sourceApp: sourceApp,
                        contentHash: hash
                    )
                }
            }
            let hash = HashUtil.sha256(filePaths: filePaths)
            return ClipboardContent(
                type: .file,
                plainText: filePaths.joined(separator: "\n"),
                rtfData: nil,
                imageData: nil,
                filePaths: filePaths,
                sourceApp: sourceApp,
                contentHash: hash
            )
        }
        
        if let imageData = readImageData() {
            let hash = HashUtil.sha256(imageData)
            return ClipboardContent(
                type: .image,
                plainText: nil,
                rtfData: nil,
                imageData: imageData,
                filePaths: nil,
                sourceApp: sourceApp,
                contentHash: hash
            )
        }
        
        if let text = readPlainText() {
            let rtfData = readRTFData()
            let hash = HashUtil.sha256(text)
            return ClipboardContent(
                type: .text,
                plainText: text,
                rtfData: rtfData,
                imageData: nil,
                filePaths: nil,
                sourceApp: sourceApp,
                contentHash: hash
            )
        }
        
        return nil
    }
    
    /// Reads plain text from the pasteboard.
    func readPlainText() -> String? {
        pasteboard.string(forType: .string)
    }
    
    /// Reads RTF data from the pasteboard.
    func readRTFData() -> Data? {
        pasteboard.data(forType: .rtf)
    }
    
    /// Reads image data (PNG, TIFF, JPEG) or a single image-file URL from the pasteboard, normalised to PNG.
    func readImageData() -> Data? {
        if let data = readDirectPasteboardImageData() { return data }
        // Single image file URL (e.g. a photo copied from Finder): load pixel data.
        if let paths = readFilePaths(), paths.count == 1, let data = Self.imageData(fromFile: paths[0]) {
            return data
        }
        return nil
    }

    /// Reads image data directly from the pasteboard bytes (PNG, TIFF, JPEG) without following file URLs.
    /// Used as a fallback when a file URL is present but the file is not readable from the sandbox.
    private func readDirectPasteboardImageData() -> Data? {
        // Try PNG.
        if let data = pasteboard.data(forType: .png) {
            return data
        }

        // Try TIFF — convert to PNG via CGImageSource for robustness across colour spaces.
        if let tiffData = pasteboard.data(forType: .tiff) {
            if let source = CGImageSourceCreateWithData(tiffData as CFData, nil),
               let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) {
                let rep = NSBitmapImageRep(cgImage: cgImage)
                if let pngData = rep.representation(using: .png, properties: [:]) {
                    return pngData
                }
            }
            // Conversion failed — store raw TIFF; CGImageSource can still decode it for thumbnails.
            return tiffData
        }

        // Try JPEG (Safari and some other apps write public.jpeg).
        let jpegType = NSPasteboard.PasteboardType("public.jpeg")
        if let data = pasteboard.data(forType: jpegType) {
            return data
        }

        return nil
    }
    
    /// Loads image data from a local file path. Returns nil for non-image file types.
    private static func imageData(fromFile path: String) -> Data? {
        let url = URL(fileURLWithPath: path)
        guard let type = UTType(filenameExtension: url.pathExtension), type.conforms(to: .image) else { return nil }
        return try? Data(contentsOf: url)
    }
    
    /// Reads file URLs from the pasteboard and returns their local file paths.
    func readFilePaths() -> [String]? {
        // Look for fileURL pasteboard items.
        guard let items = pasteboard.pasteboardItems else { return nil }
        
        var paths: [String] = []
        
        for item in items {
            if let urlString = item.string(forType: .fileURL),
               let url = URL(string: urlString) {
                paths.append(url.path)
            }
        }
        
        return paths.isEmpty ? nil : paths
    }
    
    /// Returns the bundle ID of the currently frontmost application (an approximation of the clipboard source).
    func getSourceApplication() -> String? {
        // Via NSWorkspace — this is an approximation.
        // Note: this may not always match the true clipboard source.
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }
    
    // MARK: - Write to Pasteboard
    
    /// Writes text to the clipboard.
    /// - Parameters:
    ///   - text: plain text
    ///   - rtfData: optional rich text; if nil, only plain text is written
    func writeText(_ text: String, rtfData: Data? = nil) {
        pasteboard.clearContents()
        
        if let rtfData = rtfData {
            pasteboard.setData(rtfData, forType: .rtf)
        }
        
        pasteboard.setString(text, forType: .string)
    }
    
    /// Writes image data to the clipboard.
    func writeImage(_ imageData: Data) {
        pasteboard.clearContents()
        
        if let image = NSImage(data: imageData) {
            pasteboard.writeObjects([image])
        }
    }
    
    /// Writes file paths to the clipboard.
    func writeFilePaths(_ paths: [String]) {
        pasteboard.clearContents()
        
        let urls = paths.compactMap { URL(fileURLWithPath: $0) }
        pasteboard.writeObjects(urls as [NSURL])
    }
    
    /// Writes a ClipboardItemModel back to the system clipboard, loading binary data from CoreData as needed.
    func writeItem(_ item: ClipboardItemModel, plainTextOnly: Bool = false) {
        switch item.itemType {
        case .text:
            if plainTextOnly {
                writeText(item.plainText ?? "", rtfData: nil)
            } else {
                let rtf = item.rtfData ?? ThumbnailCache.loadRtfData(for: item.id)
                writeText(item.plainText ?? "", rtfData: rtf)
            }
        case .image:
            let data = item.imageData ?? ThumbnailCache.loadImageData(for: item.id)
            if let data {
                writeImage(data)
            }
        case .file:
            if let paths = item.filePathsArray {
                writeFilePaths(paths)
            }
        }
    }
    
    // MARK: - Simulate Paste
    
    /// Simulates a Cmd+V keystroke via CGEvent.
    /// - Returns: `true` if the keystroke was posted successfully; `false` if Accessibility is not granted.
    @discardableResult
    func simulatePaste() -> Bool {
        guard AXIsProcessTrusted() else {
            print("⚠️ simulatePaste: Accessibility not granted — cannot simulate keystrokes")
            return false
        }
        
        let source = CGEventSource(stateID: .combinedSessionState)
        
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyUp?.flags = .maskCommand
        
        keyDown?.post(tap: .cgSessionEventTap)
        usleep(10_000) // 10 ms: ensure the OS processes keyDown before sending keyUp
        keyUp?.post(tap: .cgSessionEventTap)
        return true
    }
}
