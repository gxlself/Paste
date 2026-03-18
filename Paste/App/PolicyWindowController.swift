//
//  PolicyWindowController.swift
//  Paste
//
//  Standalone windows for Privacy Policy / Terms of Use.
//

import AppKit
import SwiftUI

@MainActor
final class PolicyWindowController: NSWindowController, NSWindowDelegate {

    static func create(document: PolicyDocument) -> PolicyWindowController {
        let hostingView = NSHostingView(rootView: PolicyView(document: document))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 820),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = document.windowTitle
        window.backgroundColor = .windowBackgroundColor
        window.contentView = hostingView
        window.isReleasedWhenClosed = false
        window.center()

        let controller = PolicyWindowController(window: window)
        window.delegate = controller
        return controller
    }

    func windowWillClose(_ notification: Notification) {
        // keep controller alive; caller can reuse it
    }
}

@MainActor
final class PolicyPresenter {

    static let shared = PolicyPresenter()

    private var privacyWindowController: PolicyWindowController?
    private var termsWindowController: PolicyWindowController?

    private init() {}

    func showPrivacyPolicy() {
        if privacyWindowController == nil {
            privacyWindowController = PolicyWindowController.create(document: .privacyPolicy)
        }
        privacyWindowController?.showWindow(nil)
        privacyWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showTermsOfUse() {
        if termsWindowController == nil {
            termsWindowController = PolicyWindowController.create(document: .termsOfUse)
        }
        termsWindowController?.showWindow(nil)
        termsWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

