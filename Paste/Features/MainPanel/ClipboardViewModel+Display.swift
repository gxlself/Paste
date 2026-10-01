//
//  ClipboardViewModel+Display.swift
//  Paste
//
//  Display items and VoiceOver announcements.
//

import Foundation
import Combine
import AppKit
import CoreData

@MainActor
extension ClipboardViewModel {
    // MARK: - Display Items (history or regex presets)

    var displayItemCount: Int {
        isRegexPresetMode ? RegexPreset.all.count : filteredItems.count
    }

    func displayItem(at index: Int) -> DisplayItem? {
        guard index >= 0 else { return nil }
        if isRegexPresetMode {
            let presets = RegexPreset.all
            guard index < presets.count else { return nil }
            return .preset(presets[index])
        }
        guard index < filteredItems.count else { return nil }
        return .history(filteredItems[index])
    }

    var effectiveDisplayItems: [DisplayItem] {
        if isRegexPresetMode {
            return RegexPreset.all.map { .preset($0) }
        }
        return filteredItems.map { .history($0) }
    }

    var selectedDisplayItem: DisplayItem? {
        guard !isFiltering else { return nil }
        return displayItem(at: selectedIndex)
    }

    func renameSelectedItem(to newText: String) {
        guard let item = itemForEdit, item.itemType == .text else { return }
        let t = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        clipboardService.updatePlainText(id: item.id, newText: t)
        loadItems()
        showRenameSheet = false
    }

    func editSelectedItem(to newText: String) {
        guard let item = itemForEdit, item.itemType == .text else { return }
        clipboardService.updatePlainText(id: item.id, newText: newText)
        loadItems()
        showEditSheet = false
    }

    func createNewTextItem(text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        let content = ClipboardContent(
            type: .text,
            plainText: t,
            rtfData: nil,
            imageData: nil,
            filePaths: nil,
            sourceApp: nil,
            contentHash: HashUtil.sha256(t)
        )
        clipboardService.saveItem(content)
        loadItems()
        showNewItemSheet = false
    }

    func undoLastDelete() {
        guard let item = lastDeletedItem else { return }
        clipboardService.restoreItem(item)
        lastDeletedItem = nil
        loadItems()
    }

    var canUndo: Bool { lastDeletedItem != nil }

    func openSelectedItem() {
        guard let display = selectedDisplayItem else { return }
        switch display {
        case .history(let item):
            if item.itemType == .text, let text = item.plainText?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
                if text.hasPrefix("http://") || text.hasPrefix("https://"), let url = URL(string: text) {
                    NSWorkspace.shared.open(url)
                    return
                }
                if text.hasPrefix("/") || text.hasPrefix("~") || (text.count <= 1024 && FileManager.default.fileExists(atPath: (text as NSString).expandingTildeInPath)) {
                    let path = (text as NSString).expandingTildeInPath
                    let url = URL(fileURLWithPath: path)
                    NSWorkspace.shared.open(url)
                    return
                }
            }
            if item.itemType == .file, let paths = item.filePathsArray, let first = paths.first {
                NSWorkspace.shared.open(URL(fileURLWithPath: first))
            }
        case .preset:
            break
        }
    }

    /// Paste selected: for preset writes pattern to clipboard and closes; for history pastes item.
    func pasteSelectedDisplayItem(plainTextOnly: Bool = false) {
        guard let display = selectedDisplayItem else { return }
        switch display {
        case .preset(let p):
            clipboardService.copyPlainTextToClipboard(p.pattern)
            announceToVoiceOver(String(localized: "voiceover.announce.copied.text \(String(p.pattern.prefix(50)))"))
            if AppSettings.directPasteEnabled {
                NotificationCenter.default.post(name: AppNotification.requestCloseAndPaste, object: nil)
            } else {
                NotificationCenter.default.post(name: AppNotification.requestClosePanel, object: nil)
            }
        case .history(let item):
            pasteItem(item, plainTextOnly: plainTextOnly)
            if panelMode == .pasteStack {
                pasteStackService.removeTopEntry(for: item.id)
                loadItems()
            }
        }
    }

    // MARK: - VoiceOver Announcement

    func announceToVoiceOver(_ message: String) {
        guard AppSettings.voiceOverAnnounceEnabled,
              NSWorkspace.shared.isVoiceOverEnabled else { return }
        let element = NSApp.mainWindow as Any
        NSAccessibility.post(
            element: element,
            notification: .announcementRequested,
            userInfo: [
                .announcement: message,
                .priority: NSAccessibilityPriorityLevel.high.rawValue
            ]
        )
    }

    func voiceOverSummary(for item: ClipboardItemModel) -> String {
        switch item.itemType {
        case .text:
            let preview = (item.plainText ?? "").prefix(50)
            return String(localized: "voiceover.announce.copied.text \(String(preview))")
        case .image:
            return String(localized: "voiceover.announce.copied.image")
        case .file:
            let count = item.filePathsArray?.count ?? 1
            return String(localized: "voiceover.announce.copied.file \(count)")
        }
    }
}
