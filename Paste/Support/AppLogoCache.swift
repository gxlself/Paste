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
    
    /// Monochrome template glyph for the menu bar: a clipboard with a "P" (or pause bars while
    /// monitoring is paused). Template rendering lets macOS tint it for light/dark menu bars,
    /// highlighted state and wallpaper contrast.
    static func menuBarIcon(side: CGFloat = 18, paused: Bool = false) -> NSImage {
        let size = NSSize(width: side, height: side)
        let image = NSImage(size: size, flipped: false) { rect in
            let s = rect.width / 18
            NSColor.black.setStroke()
            NSColor.black.setFill()

            // Board
            let board = NSBezierPath(
                roundedRect: NSRect(x: 3 * s, y: 1.5 * s, width: 12 * s, height: 13 * s),
                xRadius: 2.6 * s, yRadius: 2.6 * s
            )
            board.lineWidth = 1.4 * s
            board.stroke()

            // Clip (knocks out the board outline behind it, then draws solid)
            let clip = NSBezierPath(
                roundedRect: NSRect(x: 6.2 * s, y: 12.6 * s, width: 5.6 * s, height: 3.4 * s),
                xRadius: 1.3 * s, yRadius: 1.3 * s
            )
            NSGraphicsContext.current?.saveGraphicsState()
            NSGraphicsContext.current?.compositingOperation = .clear
            NSBezierPath(
                roundedRect: NSRect(x: 5.4 * s, y: 11.8 * s, width: 7.2 * s, height: 5 * s),
                xRadius: 1.8 * s, yRadius: 1.8 * s
            ).fill()
            NSGraphicsContext.current?.restoreGraphicsState()
            clip.fill()

            if paused {
                for x in [6.9, 10.1] {
                    NSBezierPath(
                        roundedRect: NSRect(x: x * s, y: 4.3 * s, width: 1.4 * s, height: 5.6 * s),
                        xRadius: 0.5 * s, yRadius: 0.5 * s
                    ).fill()
                }
            } else {
                let font = NSFont.systemFont(ofSize: 9.5 * s, weight: .heavy)
                let glyph = NSAttributedString(string: "P", attributes: [.font: font, .foregroundColor: NSColor.black])
                let g = glyph.size()
                glyph.draw(at: NSPoint(x: (rect.width - g.width) / 2, y: 3.4 * s))
            }
            return true
        }
        image.isTemplate = true
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

