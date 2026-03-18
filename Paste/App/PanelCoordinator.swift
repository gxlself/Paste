//
//  PanelCoordinator.swift
//  Paste
//
//  Owns the main NSPanel and handles its entire lifecycle:
//  creation, multi-display positioning, show/hide animations, drag-to-paste ghost,
//  preview window, and the direct-paste handoff flow.
//

import AppKit
import SwiftUI
import CoreGraphics

@MainActor
final class PanelCoordinator {

    // MARK: - Public API

    private(set) var panel: NSPanel?

    /// True while the close-and-paste handoff is in progress; used to debounce inputs.
    private(set) var isInClosingAndPasteFlow = false

    var isVisible: Bool { panel?.isVisible ?? false }

    // MARK: - Private

    private weak var viewModel: ClipboardViewModel?
    private var eventMonitor: Any?

    private var previousFrontmostApp: NSRunningApplication?
    private var previousFrontmostPID: pid_t = 0
    private var lastShowTime: Date?

    private var dragGhostPanel: DragGhostPanel?
    private var dragMouseMonitor: Any?

    private var previewWindowController: PreviewWindowController?
    private var previewUpdateWorkItem: DispatchWorkItem?

    private var observers: [Any] = []

    // MARK: - Init

    init(viewModel: ClipboardViewModel) {
        self.viewModel = viewModel
    }

    // MARK: - Panel Setup

    func setupPanel(onKeyDown: @escaping (NSEvent) -> Bool) {
        guard let screen = NSScreen.main else { return }

        panel = MainPanel(
            contentRect: NSRect(x: 0, y: 0, width: screen.frame.width, height: PanelLayout.panelBarHeight),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )

        guard let panel = panel, let viewModel else { return }

        panel.becomesKeyOnlyIfNeeded = true
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovable = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        panel.contentView = FirstMouseHostingView(rootView: MainPanelView(viewModel: viewModel))
        (panel as? MainPanel)?.onKeyDown = onKeyDown

        // Dismiss panel when user clicks outside it.
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, let panel = self.panel, panel.isVisible else { return }
            if let lastShow = self.lastShowTime, Date().timeIntervalSince(lastShow) < 0.25 { return }
            if !panel.frame.contains(NSEvent.mouseLocation) {
                self.hideWithAnimation()
            }
        }
    }

    // MARK: - Notification Observers

    func startObserving() {
        let nc = NotificationCenter.default

        observers.append(nc.addObserver(forName: AppNotification.requestCloseAndPaste, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, !self.isInClosingAndPasteFlow else { return }
                self.isInClosingAndPasteFlow = true
                self.performDirectPaste()
            }
        })

        observers.append(nc.addObserver(forName: AppNotification.requestClosePanel, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.hideWithAnimation()
                if AppSettings.soundEnabled { NSSound(named: "Pop")?.play() }
            }
        })

        observers.append(nc.addObserver(forName: AppNotification.selectedIndexChanged, object: nil, queue: .main) { [weak self] _ in
            self?.updatePreviewWindow()
        })

        observers.append(nc.addObserver(forName: AppNotification.clipboardItemDragBegan, object: nil, queue: .main) { [weak self] note in
            if let item = note.object as? ClipboardItemModel {
                self?.startDragGhost(item: item)
            }
        })

        observers.append(nc.addObserver(forName: AppNotification.clipboardItemDragEnded, object: nil, queue: .main) { [weak self] note in
            let loc = (note.userInfo?["location"] as? NSValue)?.pointValue ?? NSEvent.mouseLocation
            Task { @MainActor [weak self] in self?.animateGhostAndPaste(to: loc) }
        })
    }

    func stopObserving() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
    }

    // MARK: - Frontmost App Tracking

    func capturePreviousFrontmostApp() {
        let current = NSWorkspace.shared.frontmostApplication
        guard let current, current.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
        previousFrontmostApp = current
        previousFrontmostPID = current.processIdentifier
    }

    // MARK: - Show / Hide

    func show(updatingInputSource inputSourceCoordinator: InputSourceCoordinator) {
        guard let panel else { return }

        if panel.isVisible {
            isInClosingAndPasteFlow = false
            panel.level = .statusBar
            panel.orderFrontRegardless()
            panel.makeKey()
            lastShowTime = Date()
            return
        }

        if previousFrontmostApp == nil { capturePreviousFrontmostApp() }
        guard let targetScreen = targetScreenForFrontmostApp() ?? NSScreen.main else { return }

        panel.setFrame(panelFrame(on: targetScreen), display: false)
        panel.level = .statusBar
        lastShowTime = Date()
        isInClosingAndPasteFlow = false

        // Populate UI state before ordering front so all info participates in the slide-in animation.
        updatePasteTargetInfo()
        if let info = inputSourceCoordinator.currentInfo() {
            viewModel?.currentInputSourceId = info.id
            viewModel?.currentInputSourceName = info.name
        }

        panel.orderFrontRegardless()
        panel.makeKey()
        NotificationCenter.default.post(name: AppNotification.panelDidShow, object: nil)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func hideWithAnimation(completion: (() -> Void)? = nil) {
        hidePreviewWindow()
        NotificationCenter.default.post(name: AppNotification.panelWillHide, object: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.panel?.orderOut(nil)
            completion?()
        }
    }

    // MARK: - Direct Paste

    func performDirectPaste() {
        hidePreviewWindow()
        NotificationCenter.default.post(name: AppNotification.panelWillHide, object: nil)
        panel?.orderOut(nil)

        let target    = previousFrontmostApp
        let targetPID = previousFrontmostPID
        previousFrontmostApp = nil
        previousFrontmostPID = 0

        if let target, !target.isTerminated {
            target.activate(options: [.activateAllWindows])
        } else if targetPID > 0,
                  let fallback = NSRunningApplication(processIdentifier: targetPID),
                  !fallback.isTerminated {
            fallback.activate(options: [.activateAllWindows])
        }

        if PermissionChecker.hasAccessibilityPermission {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                PasteboardHelper.shared.simulatePaste()
                if AppSettings.soundEnabled { NSSound(named: "Tink")?.play() }
                self?.isInClosingAndPasteFlow = false
            }
        } else {
            if AppSettings.soundEnabled { NSSound(named: "Tink")?.play() }
            isInClosingAndPasteFlow = false
        }
    }

    // MARK: - Drag Ghost

    func startDragGhost(item: ClipboardItemModel) {
        endDragGhost()
        let screen   = targetScreenForFrontmostApp() ?? NSScreen.main ?? NSScreen.screens[0]
        let cardSize = PanelLayout.cardSize(position: AppSettings.panelPosition, screenSize: screen.frame.size)
        let ghost    = DragGhostPanel(item: item, cardSize: cardSize)
        ghost.setFrameOrigin(ghostOrigin(from: NSEvent.mouseLocation, cardSize: cardSize))
        ghost.orderFrontRegardless()
        dragGhostPanel = ghost
        dragMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDragged) { [weak self] event in
            self?.dragGhostPanel?.setFrameOrigin(self?.ghostOrigin(from: NSEvent.mouseLocation, cardSize: cardSize) ?? .zero)
            return event
        }
    }

    func endDragGhost() {
        dragGhostPanel?.orderOut(nil)
        dragGhostPanel = nil
        if let monitor = dragMouseMonitor {
            NSEvent.removeMonitor(monitor)
            dragMouseMonitor = nil
        }
    }

    func animateGhostAndPaste(to mousePoint: NSPoint) {
        if let monitor = dragMouseMonitor {
            NSEvent.removeMonitor(monitor)
            dragMouseMonitor = nil
        }
        guard let ghost = dragGhostPanel else { triggerPasteOrClose(); return }

        let phase1 = NSRect(x: mousePoint.x - 20, y: mousePoint.y - 20, width: 40, height: 40)
        let phase2 = NSRect(x: mousePoint.x - 2,  y: mousePoint.y - 2,  width: 4,  height: 4)

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            ghost.animator().setFrame(phase1, display: true)
            ghost.animator().alphaValue = 0.3
        }, completionHandler: {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.12
                ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
                ghost.animator().setFrame(phase2, display: true)
                ghost.animator().alphaValue = 0
            }, completionHandler: { [weak self] in
                ghost.orderOut(nil)
                self?.dragGhostPanel = nil
                self?.triggerPasteOrClose()
            })
        })
    }

    private func triggerPasteOrClose() {
        guard !isInClosingAndPasteFlow else { return }
        if AppSettings.directPasteEnabled {
            isInClosingAndPasteFlow = true
            performDirectPaste()
        } else {
            hideWithAnimation()
            if AppSettings.soundEnabled { NSSound(named: "Pop")?.play() }
        }
    }

    // MARK: - Preview Window

    func showPreviewWindow() {
        guard let panel = panel, panel.isVisible, let viewModel else { return }
        let item: ClipboardItemModel?
        let preset: RegexPreset?
        if viewModel.isRegexPresetMode, case .preset(let p)? = viewModel.selectedDisplayItem {
            item = nil; preset = p
        } else if let selectedItem = viewModel.selectedItem {
            item = selectedItem; preset = nil
        } else {
            return
        }
        panel.orderFrontRegardless()
        if previewWindowController == nil { previewWindowController = PreviewWindowController() }
        previewWindowController?.showPreview(for: item, preset: preset, selectedIndex: viewModel.selectedIndex, relativeTo: panel)
        viewModel.isPreviewVisible = true
    }

    func updatePreviewWindow() {
        previewUpdateWorkItem?.cancel()
        guard let viewModel else { return }
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, let panel = self.panel, panel.isVisible, viewModel.isPreviewVisible else { return }
            let item: ClipboardItemModel?
            let preset: RegexPreset?
            if viewModel.isRegexPresetMode, case .preset(let p)? = viewModel.selectedDisplayItem {
                item = nil; preset = p
            } else if let selectedItem = viewModel.selectedItem {
                item = selectedItem; preset = nil
            } else {
                return
            }
            self.previewWindowController?.showPreview(
                for: item, preset: preset,
                selectedIndex: viewModel.selectedIndex,
                relativeTo: panel
            )
        }
        previewUpdateWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: workItem)
    }

    func hidePreviewWindow() {
        previewWindowController?.hidePreview()
        viewModel?.isPreviewVisible = false
    }

    // MARK: - Helpers

    private func updatePasteTargetInfo() {
        if let app = previousFrontmostApp {
            viewModel?.pasteTargetAppName = app.localizedName ?? ""
            viewModel?.pasteTargetAppIcon = app.icon
        } else {
            viewModel?.pasteTargetAppName = ""
            viewModel?.pasteTargetAppIcon = nil
        }
    }

    private func panelFrame(on screen: NSScreen) -> NSRect {
        let sf = screen.frame
        switch AppSettings.panelPosition {
        case .bottom: return NSRect(x: sf.minX, y: sf.minY, width: sf.width, height: PanelLayout.panelBarHeight)
        case .top:    return NSRect(x: sf.minX, y: sf.maxY - PanelLayout.panelBarHeight, width: sf.width, height: PanelLayout.panelBarHeight)
        case .left:   return NSRect(x: sf.minX, y: sf.minY, width: PanelLayout.panelVerticalWidth, height: sf.height)
        case .right:  return NSRect(x: sf.maxX - PanelLayout.panelVerticalWidth, y: sf.minY, width: PanelLayout.panelVerticalWidth, height: sf.height)
        }
    }

    /// Positions the ghost card so the cursor sits at ~1/4 from the card's top-left, giving a "holding the card" feel.
    private func ghostOrigin(from mouse: NSPoint, cardSize: CGSize) -> NSPoint {
        NSPoint(x: mouse.x - cardSize.width * 0.25, y: mouse.y - cardSize.height * 0.75)
    }

    /// Returns the screen that contains the largest visible window of the frontmost app.
    private func targetScreenForFrontmostApp() -> NSScreen? {
        let pid = (previousFrontmostApp ?? NSWorkspace.shared.frontmostApplication)?.processIdentifier
        guard let pid else { return NSScreen.main }

        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return NSScreen.main
        }

        struct Candidate { let rect: CGRect; let area: CGFloat }
        let candidates: [Candidate] = windowList.compactMap { info in
            guard let ownerPid = info[kCGWindowOwnerPID as String] as? Int, ownerPid == pid else { return nil }
            if let isOnscreen = info[kCGWindowIsOnscreen as String] as? Bool, !isOnscreen { return nil }
            // Standard interactive windows live at layer 0; skip auxiliary/overlay layers.
            let layer = info[kCGWindowLayer as String] as? Int ?? 0
            guard layer == 0 else { return nil }
            let alpha = info[kCGWindowAlpha as String] as? Double ?? 1
            guard alpha > 0.01 else { return nil }
            guard let bounds = info[kCGWindowBounds as String] as? [String: Any],
                  let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary) else { return nil }
            let area = rect.width * rect.height
            guard area > 1 else { return nil }
            return Candidate(rect: rect, area: area)
        }
        guard let best = candidates.max(by: { $0.area < $1.area }) else { return NSScreen.main }
        let center = CGPoint(x: best.rect.midX, y: best.rect.midY)
        return NSScreen.screens.first(where: { $0.frame.contains(center) }) ?? NSScreen.main
    }
}
