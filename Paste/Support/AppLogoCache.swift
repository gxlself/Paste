//
//  AppLogoCache.swift
//  Paste
//
//  Centralized app logo loading + in-memory caching.
//

import AppKit

@MainActor
enum AppLogoCache {
    
    private static var originalLogo: NSImage? = loadOriginalLogo()
    private static let resizedCache = NSCache<NSNumber, NSImage>()
    
    /// The raw logo image (prefers the `Logo` asset; falls back to the app icon).
    static func logoImage() -> NSImage {
        originalLogo ?? NSApp.applicationIconImage
    }
    
    /// Returns the logo at the specified square side length, caching resized results in memory.
    static func logoImage(side: CGFloat) -> NSImage {
        let key = NSNumber(value: Double(side))
        if let cached = resizedCache.object(forKey: key) { return cached }
        
        let resized = resize(icon: logoImage(), to: side)
        resizedCache.setObject(resized, forKey: key)
        return resized
    }
    
    /// Recommended sizes for the menu bar icon are 18 or 22 pt.
    static func menuBarIcon(side: CGFloat = 18) -> NSImage? {
        let image = logoImage(side: side)
        image.isTemplate = false
        return image
    }
    
    // MARK: - Internals
    
    private static func loadOriginalLogo() -> NSImage? {
        // 1) Load from Assets.xcassets imageset (preferred).
        if let image = NSImage(named: NSImage.Name("Logo")) {
            return image
        }
        
        // 2) Load directly from bundle resources (fallback).
        if let path = Bundle.main.path(forResource: "logo", ofType: "png"),
           let image = NSImage(contentsOfFile: path) {
            return image
        }
        
        return nil
    }
    
    private static func resize(icon: NSImage, to side: CGFloat) -> NSImage {
        let resized = NSImage(size: NSSize(width: side, height: side))
        autoreleasepool {
            resized.lockFocus()
            defer { resized.unlockFocus() }
            
            if let context = NSGraphicsContext.current {
                context.imageInterpolation = .high
                context.shouldAntialias = true
            }
            
            let sourceRect = NSRect(x: 0, y: 0, width: icon.size.width, height: icon.size.height)
            let destRect = NSRect(x: 0, y: 0, width: side, height: side)
            icon.draw(in: destRect, from: sourceRect, operation: .sourceOver, fraction: 1.0)
        }
        
        resized.isTemplate = false
        resized.cacheMode = .never
        resized.recache()
        return resized
    }
}

