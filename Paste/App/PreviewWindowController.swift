//
//  PreviewWindowController.swift
//  Paste
//
//  Preview window controller — manages show/hide of the preview panel
//

import AppKit
import SwiftUI
import QuartzCore

/// The preview NSPanel.
class PreviewPanel: NSPanel {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return false
    }
}

@MainActor
final class PreviewWindowController {
    private var panel: NSPanel?
    private var hostingView: NSHostingView<PreviewView>?
    private var viewModel: PreviewViewModel
    private var currentItem: ClipboardItemModel?
    private var currentPreset: RegexPreset?
    private var previousSelectedIndex: Int?
    private weak var mainPanel: NSPanel?

    // Preview window dimensions (fixed).
    private let previewWidth: CGFloat = 800
    private let previewHeight: CGFloat = 400
    private let arrowHeight: CGFloat = 10
    private var totalPreviewHeight: CGFloat { previewHeight + arrowHeight }

    // Animation parameters.
    private let animationDuration: TimeInterval = 0.15

    init() {
        self.viewModel = PreviewViewModel()
    }

    // MARK: - Dynamic Card Size

    /// Computes card size dynamically based on the current panel position and screen dimensions.
    private func currentCardSize(mainPanel: NSPanel) -> CGSize {
        let screen = mainPanel.screen ?? NSScreen.main!
        return PanelLayout.cardSize(position: AppSettings.panelPosition, screenSize: screen.frame.size)
    }

    // MARK: - Card Position

    /// Returns the bottom-left screen coordinate of the selected card in AppKit coordinates (origin at bottom-left of screen).
    private func calculateCardPosition(selectedIndex: Int, mainPanel: NSPanel, cardSize: CGSize) -> (x: CGFloat, y: CGFloat) {
        let f = mainPanel.frame
        let position = AppSettings.panelPosition
        let topBarH: CGFloat = position == .left || position == .right
            ? PanelLayout.topBarHeightV : PanelLayout.topBarHeightH

        switch position {
        case .bottom:
            // Horizontal layout, panel at bottom.
            let cardX = PanelLayout.panelPadding + CGFloat(selectedIndex) * (cardSize.width + PanelLayout.cardSpacing)
            let screenX = f.minX + cardX
            let screenY = f.maxY - topBarH - cardSize.height
            return (screenX, screenY)
        case .top:
            // Horizontal layout, panel at top.
            let cardX = PanelLayout.panelPadding + CGFloat(selectedIndex) * (cardSize.width + PanelLayout.cardSpacing)
            let screenX = f.minX + cardX
            let screenY = f.minY + topBarH  // SwiftUI top bar grows downward; AppKit Y is measured from the bottom.
            return (screenX, screenY)
        case .left, .right:
            // Vertical layout, cards from panel top downward.
            let cardY = f.maxY - topBarH - PanelLayout.vertPadding
                        - CGFloat(selectedIndex + 1) * cardSize.height
                        - CGFloat(selectedIndex) * PanelLayout.cardSpacing
            let screenX = f.minX + PanelLayout.panelPadding
            return (screenX, cardY)
        }
    }

    // MARK: - Preview Frame Calculation

    /// Computes the target frame for the preview window based on panel orientation.
    private func calculatePreviewFrame(cardPosition: (x: CGFloat, y: CGFloat),
                                       cardSize: CGSize,
                                       mainPanel: NSPanel,
                                       screen: NSScreen) -> (frame: NSRect, arrowOffset: CGFloat) {
        let visibleFrame = screen.visibleFrame
        let position = AppSettings.panelPosition
        let f = mainPanel.frame

        switch position {
        case .bottom:
            // Preview appears above the card.
            let cardCenterX = cardPosition.x + cardSize.width / 2
            let rawX = cardCenterX - previewWidth / 2
            let rawY = cardPosition.y + cardSize.height + 20
            let clampedX = max(visibleFrame.minX + 20, min(rawX, visibleFrame.maxX - previewWidth - 20))
            let maxY = visibleFrame.maxY - totalPreviewHeight - 20
            let clampedY: CGFloat
            if rawY + totalPreviewHeight > maxY {
                clampedY = max(visibleFrame.minY + 20, cardPosition.y - totalPreviewHeight - 20)
            } else {
                clampedY = rawY
            }
            let arrowOffset = cardCenterX - clampedX - previewWidth / 2
            return (NSRect(x: clampedX, y: clampedY, width: previewWidth, height: totalPreviewHeight), arrowOffset)

        case .top:
            // Preview appears below the card.
            let cardCenterX = cardPosition.x + cardSize.width / 2
            let rawX = cardCenterX - previewWidth / 2
            let rawY = cardPosition.y - totalPreviewHeight - 20
            let clampedX = max(visibleFrame.minX + 20, min(rawX, visibleFrame.maxX - previewWidth - 20))
            let clampedY = max(visibleFrame.minY + 20, rawY)
            let arrowOffset = cardCenterX - clampedX - previewWidth / 2
            return (NSRect(x: clampedX, y: clampedY, width: previewWidth, height: totalPreviewHeight), arrowOffset)

        case .left:
            // Preview appears to the right of the panel, vertically centred on the selected card.
            let cardCenterY = cardPosition.y + cardSize.height / 2
            let rawX = f.maxX + 20
            let rawY = cardCenterY - previewHeight / 2
            let clampedX = min(rawX, visibleFrame.maxX - previewWidth - 20)
            let clampedY = max(visibleFrame.minY + 20, min(rawY, visibleFrame.maxY - totalPreviewHeight - 20))
            return (NSRect(x: clampedX, y: clampedY, width: previewWidth, height: totalPreviewHeight), 0)

        case .right:
            // Preview appears to the left of the panel, vertically centred on the selected card.
            let cardCenterY = cardPosition.y + cardSize.height / 2
            let rawX = f.minX - previewWidth - 20
            let rawY = cardCenterY - previewHeight / 2
            let clampedX = max(visibleFrame.minX + 20, rawX)
            let clampedY = max(visibleFrame.minY + 20, min(rawY, visibleFrame.maxY - totalPreviewHeight - 20))
            return (NSRect(x: clampedX, y: clampedY, width: previewWidth, height: totalPreviewHeight), 0)
        }
    }

    // MARK: - Public API

    func showPreview(for item: ClipboardItemModel?, preset: RegexPreset?, selectedIndex: Int, relativeTo mainPanel: NSPanel) {
        self.mainPanel = mainPanel
        guard preset != nil || item != nil else { return }
        let sameContent = (preset != nil && currentPreset?.id == preset?.id) || (item != nil && currentItem?.id == item?.id)
        if let existingPanel = panel, existingPanel.isVisible, sameContent {
            updatePreviewPosition(selectedIndex: selectedIndex, relativeTo: mainPanel, animated: false)
            return
        }
        if let p = preset {
            currentPreset = p
            currentItem = nil
            viewModel.updatePreset(p)
            viewModel.updateItem(nil)
        } else if let it = item {
            currentItem = it
            currentPreset = nil
            viewModel.updateItem(it)
            viewModel.updatePreset(nil)
        }
        if let existingPanel = panel, existingPanel.isVisible {
            updatePreviewContentWithAnimation(item: item, preset: preset, selectedIndex: selectedIndex, relativeTo: mainPanel)
            return
        }
        createPreviewWindowWithAnimation(for: item, preset: preset, selectedIndex: selectedIndex, relativeTo: mainPanel)
    }

    private func createPreviewWindowWithAnimation(for item: ClipboardItemModel?, preset: RegexPreset?, selectedIndex: Int, relativeTo mainPanel: NSPanel) {
        guard let screen = mainPanel.screen ?? NSScreen.main else { return }

        let cs = currentCardSize(mainPanel: mainPanel)
        let cardPos = calculateCardPosition(selectedIndex: selectedIndex, mainPanel: mainPanel, cardSize: cs)
        let (targetFrame, arrowOffset) = calculatePreviewFrame(cardPosition: cardPos, cardSize: cs, mainPanel: mainPanel, screen: screen)

        // Start at card size (scale-in animation origin).
        let startFrame = NSRect(x: cardPos.x, y: cardPos.y, width: cs.width, height: cs.height)

        panel = PreviewPanel(
            contentRect: startFrame,
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        guard let panel = panel else { return }

        panel.becomesKeyOnlyIfNeeded = true
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovable = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.alphaValue = 0.0

        viewModel.updatePreset(nil)
        viewModel.updateItem(nil)
        if let item = item { viewModel.updateItem(item) }
        else if let preset = preset { viewModel.updatePreset(preset) }
        viewModel.updateArrowOffset(arrowOffset)

        let contentView = PreviewView(viewModel: viewModel)
        let hostingView = NSHostingView(rootView: contentView)
        self.hostingView = hostingView
        panel.contentView = hostingView
        panel.setFrame(startFrame, display: true)
        panel.orderFrontRegardless()

        currentItem = item
        currentPreset = preset
        previousSelectedIndex = selectedIndex

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            context.allowsImplicitAnimation = true
            panel.animator().setFrame(targetFrame, display: true)
            panel.animator().alphaValue = 1.0
        }, completionHandler: nil)
    }

    private func updatePreviewContentWithAnimation(item: ClipboardItemModel?, preset: RegexPreset?, selectedIndex: Int, relativeTo mainPanel: NSPanel) {
        guard let panel = panel, let screen = mainPanel.screen ?? NSScreen.main else { return }

        let cs = currentCardSize(mainPanel: mainPanel)
        let cardPos = calculateCardPosition(selectedIndex: selectedIndex, mainPanel: mainPanel, cardSize: cs)
        let (targetFrame, arrowOffset) = calculatePreviewFrame(cardPosition: cardPos, cardSize: cs, mainPanel: mainPanel, screen: screen)

        currentItem = item
        currentPreset = preset
        previousSelectedIndex = selectedIndex
        viewModel.updatePreset(nil)
        viewModel.updateItem(nil)
        if let item = item { viewModel.updateItem(item) }
        else if let preset = preset { viewModel.updatePreset(preset) }
        viewModel.updateArrowOffset(arrowOffset)

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            context.allowsImplicitAnimation = true
            panel.animator().setFrame(targetFrame, display: true)
        }, completionHandler: nil)
    }

    private func updatePreviewPosition(selectedIndex: Int, relativeTo mainPanel: NSPanel, animated: Bool = true) {
        guard let panel = panel, let screen = mainPanel.screen ?? NSScreen.main else { return }

        let cs = currentCardSize(mainPanel: mainPanel)
        let cardPos = calculateCardPosition(selectedIndex: selectedIndex, mainPanel: mainPanel, cardSize: cs)
        let (targetFrame, arrowOffset) = calculatePreviewFrame(cardPosition: cardPos, cardSize: cs, mainPanel: mainPanel, screen: screen)

        viewModel.updateArrowOffset(arrowOffset)

        if animated {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = animationDuration * 0.5
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                context.allowsImplicitAnimation = true
                panel.animator().setFrameOrigin(targetFrame.origin)
            }, completionHandler: nil)
        } else {
            panel.setFrameOrigin(targetFrame.origin)
        }
    }

    func hidePreview() {
        guard let panel = panel else { return }

        if (currentItem != nil || currentPreset != nil),
           let selectedIndex = previousSelectedIndex,
           let mainPanel = mainPanel {
            let cs = currentCardSize(mainPanel: mainPanel)
            let cardPos = calculateCardPosition(selectedIndex: selectedIndex, mainPanel: mainPanel, cardSize: cs)

            NSAnimationContext.runAnimationGroup({ context in
                context.duration = animationDuration * 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                context.allowsImplicitAnimation = true
                panel.animator().setFrame(NSRect(x: cardPos.x, y: cardPos.y, width: cs.width, height: cs.height), display: true)
                panel.animator().alphaValue = 0.0
            }, completionHandler: { [weak self] in
                self?.panel?.orderOut(nil)
                self?.panel = nil
                self?.hostingView = nil
                self?.currentItem = nil
                self?.currentPreset = nil
                self?.previousSelectedIndex = nil
                self?.mainPanel = nil
                self?.viewModel.updateItem(nil)
                self?.viewModel.updatePreset(nil)
            })
        } else {
            panel.orderOut(nil)
            self.panel = nil
            self.hostingView = nil
            self.currentItem = nil
            self.currentPreset = nil
            self.previousSelectedIndex = nil
            self.mainPanel = nil
            self.viewModel.updateItem(nil)
            self.viewModel.updatePreset(nil)
        }
    }

    var isVisible: Bool {
        return panel?.isVisible ?? false
    }
}
