//
//  PermissionOnboardingWindowController.swift
//  Paste
//
//  Permission onboarding window: shown on launch when Accessibility is not yet granted.
//

import AppKit
import SwiftUI

@MainActor
final class PermissionOnboardingWindowController: NSWindowController, NSWindowDelegate {

    static func create(onRecheck: @escaping () -> Bool) -> PermissionOnboardingWindowController {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = String(localized: "permission.onboarding.window.title", defaultValue: "需要授权")
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = false
        window.backgroundColor = .windowBackgroundColor
        window.isReleasedWhenClosed = false
        window.center()
        window.isMovableByWindowBackground = true

        let controller = PermissionOnboardingWindowController(window: window)
        window.delegate = controller
        let weakController = controller
        let viewWithClose = PermissionOnboardingView(
            onRecheck: onRecheck,
            onVerified: { [weak weakController] in
                weakController?.close()
            }
        )
        window.contentView = NSHostingView(rootView: viewWithClose)
        return controller
    }

    func windowWillClose(_ notification: Notification) {
        // Controller can be reused or released by owner
    }
}
