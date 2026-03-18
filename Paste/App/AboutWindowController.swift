//
//  AboutWindowController.swift
//  Paste
//
//  About window for menu bar
//

import AppKit
import SwiftUI

@MainActor
final class AboutWindowController: NSWindowController, NSWindowDelegate {
    
    static func create() -> AboutWindowController {
        let hostingView = NSHostingView(rootView: AboutView())
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 420),
                              styleMask: [.titled, .closable, .miniaturizable],
                              backing: .buffered,
                              defer: false)
        
        window.title = String(localized: "about.window.title", defaultValue: "关于")
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = .windowBackgroundColor
        window.contentView = hostingView
        window.isReleasedWhenClosed = false
        window.center()
        
        let controller = AboutWindowController(window: window)
        window.delegate = controller
        return controller
    }
    
    func windowWillClose(_ notification: Notification) {
        // keep controller alive; caller can reuse it
    }
}

