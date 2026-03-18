//
//  AppDelegate.swift
//  Paste
//
//  Application lifecycle, menu bar, and key-event routing.
//  Heavy lifting is delegated to PanelCoordinator, HotKeyCoordinator, and InputSourceCoordinator.
//

import AppKit
import SwiftUI
import Carbon

/// Custom NSPanel: forwards keyDown events to AppDelegate (requires only Accessibility, no Input Monitoring).
class MainPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Returns true if the event was handled; stops further propagation.
    var onKeyDown: ((NSEvent) -> Bool)?

    override func keyDown(with event: NSEvent) {
        if onKeyDown?(event) == true { return }
        super.keyDown(with: event)
    }

    /// When the search field's field editor becomes first responder, arrow keys/Return/Tab are
    /// consumed before reaching the panel. Intercept them here and forward to onKeyDown.
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown,
           firstResponder is NSTextView {
            let keyCode = Int(event.keyCode)
            let interceptKeys: Set<Int> = [123, 124, 125, 126, 36, 76, 48] // Arrows, Enter, Keypad Enter, Tab
            if interceptKeys.contains(keyCode), let onKeyDown, onKeyDown(event) { return }
        }
        super.sendEvent(event)
    }

    /// When the search field gains focus, ESC routes through cancelOperation instead of keyDown.
    /// Intercept it here, synthesise a keyCode=53 NSEvent, and forward to onKeyDown.
    override func cancelOperation(_ sender: Any?) {
        let escEvent = NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: windowNumber, context: nil,
            characters: "\u{1B}", charactersIgnoringModifiers: "\u{1B}",
            isARepeat: false, keyCode: 53
        )
        if let escEvent, onKeyDown?(escEvent) == true { return }
        super.cancelOperation(sender)
    }
}

/// Allows SwiftUI views hosted in a non-activating panel to receive first-click events.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Dependencies

    private let viewModel            = ClipboardViewModel()
    private lazy var panelCoordinator = PanelCoordinator(viewModel: viewModel)
    private lazy var hotKeyCoordinator = HotKeyCoordinator(
        viewModel: viewModel,
        onShowPanel: { [weak self] in self?.showMainPanel() },
        onHidePanel: { [weak self] in self?.panelCoordinator.hideWithAnimation() },
        isPanelVisible: { [weak self] in self?.panelCoordinator.isVisible ?? false },
        captureFrontmostApp: { [weak self] in self?.panelCoordinator.capturePreviousFrontmostApp() }
    )
    private let inputSourceCoordinator = InputSourceCoordinator()

    // MARK: - Menu Bar

    private var statusItem: NSStatusItem?
    private var clipboardMonitor: ClipboardMonitor?

    // MARK: - Key-handling state

    private var modifierFlagsMonitor: Any?
    private var lastConfirmAt: CFAbsoluteTime = 0
    private var aboutWindowController: AboutWindowController?

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        panelCoordinator.setupPanel(onKeyDown: { [weak self] event in
            self?.handleKeyEvent(event) ?? false
        })
        panelCoordinator.startObserving()
        setupClipboardMonitor()
        hotKeyCoordinator.setup()
        setupModifierFlagsMonitor()
        applyAppearance(AppSettings.appearance)
        NSApp.setActivationPolicy(.accessory)
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardMonitor?.stopMonitoring()
        HotKeyManager.shared.unregisterAll()
        panelCoordinator.stopObserving()
        if let modifierFlagsMonitor {
            NSEvent.removeMonitor(modifierFlagsMonitor)
            self.modifierFlagsMonitor = nil
        }
    }

    private func applyAppearance(_ appearance: AppSettings.Appearance) {
        switch appearance {
        case .system: NSApp.appearance = nil
        case .light:  NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:   NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    // MARK: - Menu Bar Setup

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            if let icon = AppLogoCache.menuBarIcon(side: 18) {
                button.image = icon
            } else {
                button.image = NSImage(
                    systemSymbolName: "doc.on.clipboard",
                    accessibilityDescription: String(localized: "status.menu.accessibilityDescription")
                )
            }
            button.action = #selector(statusBarButtonClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!
        if event.type == .rightMouseUp {
            showStatusMenu()
        } else {
            panelCoordinator.capturePreviousFrontmostApp()
            toggleMainPanel()
        }
    }

    private func showStatusMenu() {
        let menu = NSMenu()

        let preferencesItem = NSMenuItem(title: String(localized: "status.menu.preferences"), action: #selector(openPreferences), keyEquivalent: ",")
        preferencesItem.target = self
        menu.addItem(preferencesItem)

        let aboutItem = NSMenuItem(title: String(localized: "status.menu.about"), action: #selector(openAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

        let openItem = NSMenuItem(title: String(localized: "status.menu.openClipboard"), action: #selector(showMainPanel), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        let isPaused = !(clipboardMonitor?.isMonitoringActive ?? true)
        let pauseTitle = isPaused ? String(localized: "status.menu.resume") : String(localized: "status.menu.pause")
        let pauseItem = NSMenuItem(title: pauseTitle, action: #selector(togglePause), keyEquivalent: "")
        pauseItem.target = self
        menu.addItem(pauseItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: String(localized: "status.menu.quit"), action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    // MARK: - Clipboard Monitor

    private func setupClipboardMonitor() {
        clipboardMonitor = ClipboardMonitor.shared
        clipboardMonitor?.startMonitoring()
    }

    // MARK: - Modifier Flags Monitor

    private func setupModifierFlagsMonitor() {
        modifierFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self, self.panelCoordinator.isVisible else { return event }
            let flags = event.modifierFlags
            self.viewModel.isCommandHeld = flags.contains(.command)
            self.viewModel.isShiftHeld = flags.contains(.shift)
            return event
        }
    }

    // MARK: - Show / Hide

    @objc func showMainPanel() {
        panelCoordinator.show(updatingInputSource: inputSourceCoordinator)
    }

    private func toggleMainPanel() {
        if panelCoordinator.isVisible {
            panelCoordinator.hideWithAnimation()
        } else {
            showMainPanel()
        }
    }

    // MARK: - Actions

    @objc func openPreferences() {
        PreferencesWindowController.shared.show()
    }

    @objc private func openAbout() {
        if aboutWindowController == nil {
            aboutWindowController = AboutWindowController.create()
        }
        aboutWindowController?.showWindow(nil)
        aboutWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    @objc private func togglePause() {
        guard let monitor = clipboardMonitor else { return }
        if monitor.isMonitoringActive {
            monitor.stopMonitoring()
        } else {
            monitor.startMonitoring()
        }
    }

    // MARK: - Key Event Handling (Accessibility-only; panel is key window, no Input Monitoring needed)

    /// Handles key events forwarded from MainPanel. Returns true if the event was consumed.
    func handleKeyEvent(_ event: NSEvent) -> Bool {
        guard panelCoordinator.isVisible else { return false }
        if panelCoordinator.isInClosingAndPasteFlow { return true }

        let keyCode   = Int(event.keyCode)
        let flags     = event.modifierFlags
        let isCmd     = flags.contains(.command)
        let isCtrl    = flags.contains(.control)
        let isOpt     = flags.contains(.option)
        let isShift   = flags.contains(.shift)
        let panel     = panelCoordinator.panel

        switch keyCode {
        case 3: // F — Cmd+F focus search
            if isCmd { viewModel.focusSearch = true; return true }
        case 17: // T — Cmd+T pause/resume monitoring
            if isCmd { togglePause(); return true }
        case 31: // O — Cmd+O open selected link/file
            if isCmd { viewModel.openSelectedItem(); return true }
        case 45: // N — Cmd+N new item / Shift+Cmd+N new pinboard
            if isCmd {
                if isShift { viewModel.createNewPinboard() } else { viewModel.showNewItemSheet = true }
                return true
            }
        case 6: // Z — Cmd+Z undo
            if isCmd { viewModel.undoLastDelete(); return true }
        case 14: // E — Cmd+E edit
            if isCmd { viewModel.showEditSheet = true; return true }
        case 15: // R — Cmd+R rename
            if isCmd { viewModel.showRenameSheet = true; return true }
        case 48: // Tab — cycle filter tabs
            if !isCmd && !isOpt {
                if isShift { viewModel.selectPreviousFilterTab() } else { viewModel.selectNextFilterTab() }
                return true
            }
        case 49: // Space
            if isCtrl && !isCmd {
                inputSourceCoordinator.selectNext()
                if let info = inputSourceCoordinator.currentInfo() {
                    viewModel.currentInputSourceId = info.id
                    viewModel.currentInputSourceName = info.name
                }
                return true
            }
            if !isSearchFieldActive() {
                panelCoordinator.showPreviewWindow()
                return true
            }
        case 0: // A — Cmd+A select all
            if isCmd { viewModel.selectAll(); return true }
        case 123: // Left
            // When search is empty and focused, defocus first; when non-empty, navigate items directly.
            if viewModel.focusSearch && viewModel.searchText.isEmpty { defocusSearch(panel: panel) }
            if isShift { viewModel.extendSelection(left: true) }
            else if isCmd { viewModel.previousPinboard() }
            else { viewModel.selectPrevious() }
            return true
        case 124: // Right
            if viewModel.focusSearch && viewModel.searchText.isEmpty { defocusSearch(panel: panel) }
            if isShift { viewModel.extendSelection(left: false) }
            else if isCmd { viewModel.nextPinboard() }
            else { viewModel.selectNext() }
            return true
        case 126: // Up
            if viewModel.focusSearch && viewModel.searchText.isEmpty { defocusSearch(panel: panel) }
            if isCmd { viewModel.selectFirst() } else { viewModel.selectPrevious() }
            return true
        case 125: // Down
            if viewModel.focusSearch && viewModel.searchText.isEmpty { defocusSearch(panel: panel) }
            if isCmd { viewModel.selectLast() } else { viewModel.selectNext() }
            return true
        case 36, 76: // Return / Keypad Enter
            let now = CFAbsoluteTimeGetCurrent()
            if now - lastConfirmAt < 0.20 { return true }
            lastConfirmAt = now
            let plainTextOnly = AppSettings.pastePlainTextByDefault
                || flags.contains(AppSettings.plainTextModifier)
                || flags.contains(.shift)
            viewModel.pasteSelectedItem(plainTextOnly: plainTextOnly)
            return true
        case 53: // Esc
            if viewModel.isPreviewVisible {
                panelCoordinator.hidePreviewWindow()
            } else if viewModel.focusSearch || !viewModel.searchText.isEmpty {
                viewModel.searchText = ""
                viewModel.focusSearch = false
                viewModel.selectedIndex = 0
                panel?.makeFirstResponder(nil)
            } else if viewModel.selectedIndices.count > 1 {
                viewModel.exitMultiSelection()
            } else if viewModel.isShowingPasteStack {
                viewModel.exitPasteStack()
            } else if viewModel.isShowingPinboard {
                viewModel.exitPinboard()
            } else {
                panelCoordinator.hideWithAnimation()
            }
            return true
        case 117: // Forward Delete
            viewModel.deleteSelectedItem(); return true
        case 51: // Delete/Backspace
            if isCmd { viewModel.deleteSelectedItem(); return true }
            if !viewModel.searchText.isEmpty { viewModel.searchText.removeLast() }
            return true
        case 8: // C — Cmd+C copy
            if isCmd, viewModel.selectedDisplayItem != nil {
                viewModel.copySelectedDisplayItem()
                if AppSettings.soundEnabled { NSSound(named: "Pop")?.play() }
                return true
            }
        default:
            break
        }

        // Printable characters → append to search.
        if !isCmd && !isCtrl && !isOpt,
           let str = event.characters, !str.isEmpty,
           str.unicodeScalars.allSatisfy({ $0.value >= 0x20 }) {
            viewModel.searchText.append(str)
            viewModel.focusSearch = true
            if let info = inputSourceCoordinator.currentInfo() {
                viewModel.currentInputSourceId = info.id
                viewModel.currentInputSourceName = info.name
            }
            // Move cursor to end after SwiftUI updates focus to avoid default select-all.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                guard let panel = self?.panelCoordinator.panel,
                      let textView = panel.firstResponder as? NSTextView else { return }
                let len = textView.string.count
                textView.setSelectedRange(NSRange(location: len, length: 0))
            }
            return true
        }

        // Quick-paste via configured modifier + digit keys.
        let quickMod = AppSettings.quickPasteModifier
        if flags.contains(quickMod), let offset = quickPasteIndex(for: keyCode) {
            let list = viewModel.effectiveDisplayItems
            let actualIndex = viewModel.firstVisibleIndex + offset
            if actualIndex < list.count {
                viewModel.selectedIndex = actualIndex
                let plainTextOnly = AppSettings.pastePlainTextByDefault
                    || flags.contains(AppSettings.plainTextModifier)
                    || flags.contains(.shift)
                viewModel.pasteSelectedItem(plainTextOnly: plainTextOnly)
                return true
            }
        }

        return false
    }

    // MARK: - Key Event Helpers

    /// True when the search field should absorb Space (i.e., it has non-empty text).
    private func isSearchFieldActive() -> Bool { !viewModel.searchText.isEmpty }

    private func defocusSearch(panel: NSPanel?) {
        viewModel.focusSearch = false
        panel?.makeFirstResponder(nil)
    }

    private func quickPasteIndex(for keyCode: Int) -> Int? {
        // US keyboard key codes for digits 1–9.
        switch keyCode {
        case 18: return 0
        case 19: return 1
        case 20: return 2
        case 21: return 3
        case 23: return 4
        case 22: return 5
        case 26: return 6
        case 28: return 7
        case 25: return 8
        default: return nil
        }
    }
}
