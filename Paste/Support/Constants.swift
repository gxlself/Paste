//
//  Constants.swift
//  Paste
//
//  Application-level constants
//

import Foundation
import AppKit

enum Constants {
    
    // MARK: - App Info
    
    static let appName = "Paste"
    static let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.pastetool"
    static let iCloudContainerIdentifier = "iCloud.\(bundleIdentifier)"
    
    // MARK: - Clipboard
    
    /// Polling interval for clipboard monitoring (seconds).
    static let clipboardPollingInterval: TimeInterval = 0.3
    
    /// Default maximum number of stored items.
    static let defaultMaxItems = 1000
    
    /// Minimum allowed value for the max-items limit.
    static let minMaxItems = 100
    
    /// Maximum allowed value for the max-items limit.
    static let maxMaxItems = 10000
    
    // MARK: - UI
    
    /// Main panel width.
    static let mainPanelWidth: CGFloat = 600
    
    /// Maximum height of the main panel.
    static let mainPanelMaxHeight: CGFloat = 500
    
    /// List row height.
    static let listRowHeight: CGFloat = 60
    
    /// Thumbnail size for images.
    static let thumbnailSize: CGFloat = 48
    
    // MARK: - Search
    
    /// Search debounce delay (seconds).
    static let searchDebounceDelay: TimeInterval = 0.15
    
    // MARK: - HotKey
    
    /// Default hotkey: Cmd + Shift + V.
    static let defaultHotKeyModifiers: UInt32 = UInt32(NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue)
    static let defaultHotKeyKeyCode: UInt32 = 9 // V key
    
    // MARK: - UserDefaults Keys
    
    enum UserDefaultsKey {
        static let maxItems = "maxItems"
        static let excludedApps = "excludedApps"
        static let recordImages = "recordImages"
        static let hotKeyKeyCode = "hotKeyKeyCode"
        static let hotKeyModifiers = "hotKeyModifiers"
        static let launchAtLogin = "launchAtLogin"
    }
}

// MARK: - Panel Layout

enum PanelLayout {
    /// Fixed height for horizontal panels (bottom/top).
    static let panelBarHeight: CGFloat = 240
    /// Fixed width for vertical panels (left/right).
    static let panelVerticalWidth: CGFloat = 360
    /// Top bar height for horizontal layout.
    static let topBarHeightH: CGFloat = 50
    /// Top bar height for vertical layout (2-row compact).
    static let topBarHeightV: CGFloat = 70
    /// Spacing between cards.
    static let cardSpacing: CGFloat = 12
    /// Horizontal padding inside the panel.
    static let panelPadding: CGFloat = 20
    /// Vertical padding inside the panel (top and bottom).
    static let vertPadding: CGFloat = 12
    /// Fixed card height in horizontal layout.
    static let cardHeightH: CGFloat = 160

    /// Computes card size based on panel position and screen dimensions, filling exactly 9 cards across the visible area.
    static func cardSize(position: AppSettings.PanelPosition, screenSize: CGSize) -> CGSize {
        switch position {
        case .bottom, .top:
            // Divide screen width into 9 columns, subtracting left/right padding and 8 gaps.
            let w = (screenSize.width - 2 * panelPadding - 8 * cardSpacing) / 9
            return CGSize(width: max(80, w), height: cardHeightH)
        case .left, .right:
            // Vertical card width fills the panel width minus left/right padding.
            let w = panelVerticalWidth - 2 * panelPadding // 320
            // Divide screen height into 9 rows, subtracting top bar, top/bottom padding, and 8 gaps.
            let h = (screenSize.height - topBarHeightV - 2 * vertPadding - 8 * cardSpacing) / 9
            return CGSize(width: w, height: max(60, h))
        }
    }
}

// ClipboardItemType is defined in Paste-Shared/SharedClipboardItemType.swift
// and is compiled into all targets (Paste, Paste-iOS, Paste-Keyboard).
