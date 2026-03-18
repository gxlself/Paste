//
//  HotKeyCoordinator.swift
//  Paste
//
//  Registers global hot keys and handles the corresponding panel actions.
//  Delegates panel show/hide to PanelCoordinator via callbacks.
//

import AppKit

@MainActor
final class HotKeyCoordinator {

    private weak var viewModel: ClipboardViewModel?
    private let onShowPanel: () -> Void
    private let onHidePanel: () -> Void
    private let isPanelVisible: () -> Bool
    private let captureFrontmostApp: () -> Void

    init(
        viewModel: ClipboardViewModel,
        onShowPanel: @escaping () -> Void,
        onHidePanel: @escaping () -> Void,
        isPanelVisible: @escaping () -> Bool,
        captureFrontmostApp: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.onShowPanel = onShowPanel
        self.onHidePanel = onHidePanel
        self.isPanelVisible = isPanelVisible
        self.captureFrontmostApp = captureFrontmostApp
    }

    // MARK: - Setup

    func setup() {
        HotKeyManager.shared.registerAll(handlers: [
            .paste: { [weak self] in
                self?.captureFrontmostApp()
                self?.viewModel?.exitPasteStack()
                self?.togglePanel()
            },
            .pasteStack: { [weak self] in
                self?.captureFrontmostApp()
                self?.togglePasteStackPanel()
            },
            .nextPinboard: { [weak self] in
                self?.captureFrontmostApp()
                self?.handleNextPinboard()
            },
            .previousPinboard: { [weak self] in
                self?.captureFrontmostApp()
                self?.handlePreviousPinboard()
            },
        ])
    }

    // MARK: - Handlers

    private func togglePanel() {
        if isPanelVisible() { onHidePanel() } else { onShowPanel() }
    }

    private func togglePasteStackPanel() {
        if isPanelVisible(), viewModel?.panelMode == .pasteStack {
            onHidePanel()
            return
        }
        viewModel?.enterPasteStack()
        onShowPanel()
    }

    private func handleNextPinboard() {
        if !isPanelVisible() { onShowPanel() }
        viewModel?.nextPinboard()
    }

    private func handlePreviousPinboard() {
        if !isPanelVisible() { onShowPanel() }
        viewModel?.previousPinboard()
    }
}
