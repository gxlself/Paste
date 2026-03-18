//
//  PermissionChecker.swift
//  Paste
//
//  Checks Accessibility / Input Monitoring permissions and opens the relevant System Settings pane.
//

import AppKit
import ApplicationServices

enum PermissionChecker {

    /// Whether the current process has been granted Accessibility trust.
    static var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    /// Requests Accessibility permission via the standard system prompt.
    /// The system shows an "Allow XXX to control your computer?" dialog with an "Open System Settings" button.
    /// Returns the current permission status immediately (does not wait for the user's response).
    @discardableResult
    static func requestWithSystemPrompt() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Opens System Settings → Privacy & Security → Accessibility (for manual user invocation).
    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
