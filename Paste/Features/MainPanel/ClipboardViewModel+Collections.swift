//
//  ClipboardViewModel+Collections.swift
//  Paste
//
//  Custom types, pinboards, filter tabs and the Paste Stack.
//

import Foundation
import Combine
import AppKit
import CoreData

@MainActor
extension ClipboardViewModel {
    // MARK: - Custom Types

    /// Confirms the inline input, creating a new custom type.
    func confirmAddCustomType() {
        let trimmed = customTypeInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { cancelAddCustomType(); return }
        AppSettings.addCustomType(name: trimmed)
        customTypes = AppSettings.customTypes
        customTypeInputText = ""
        showCustomTypeInput = false
    }

    func cancelAddCustomType() {
        customTypeInputText = ""
        showCustomTypeInput = false
    }

    func removeCustomType(id: String) {
        // Strip the tag from all items that carry it.
        let tagRaw = ItemTag.customType(id).rawValue
        for item in items where item.tagsArray.contains(tagRaw) {
            let updated = item.tagsArray.filter { $0 != tagRaw }
            clipboardService.updateTags(id: item.id, tags: updated)
        }
        AppSettings.removeCustomType(id: id)
        customTypes = AppSettings.customTypes
        if selectedCustomTypeId == id { selectedCustomTypeId = nil }
        loadItems()
    }

    func renameCustomType(id: String, name: String) {
        AppSettings.renameCustomType(id: id, name: name)
        customTypes = AppSettings.customTypes
    }

    /// Assigns item to a custom type (or removes it if already assigned — toggling).
    func toggleCustomType(id: String, for item: ClipboardItemModel) {
        let tagRaw = ItemTag.customType(id).rawValue
        var tags = item.tagsArray
        if tags.contains(tagRaw) {
            tags.removeAll { $0 == tagRaw }
        } else {
            tags.append(tagRaw)
        }
        clipboardService.updateTags(id: item.id, tags: tags)
        loadItems()
    }

    // MARK: - Pinboard

    var isShowingPinboard: Bool { activePinboardIndex != nil }
    
    func showPinboard(index: Int) {
        let clamped = max(0, min(index, AppSettings.pinboardCount - 1))
        activePinboardIndex = clamped
    }
    
    func exitPinboard() {
        activePinboardIndex = nil
    }
    
    func nextPinboard() {
        let current = activePinboardIndex ?? AppSettings.lastPinboardIndex
        let next = (current + 1) % AppSettings.pinboardCount
        activePinboardIndex = next
    }
    
    func previousPinboard() {
        let current = activePinboardIndex ?? AppSettings.lastPinboardIndex
        let prev = (current - 1 + AppSettings.pinboardCount) % AppSettings.pinboardCount
        activePinboardIndex = prev
    }

    func createNewPinboard() {
        let current = AppSettings.pinboardCount
        if current < AppSettings.pinboardCountMax {
            AppSettings.pinboardCount = current + 1
            AppSettings.savePinboardsToKVS()
        }
        showPinboard(index: AppSettings.pinboardCount - 1)
    }
    
    func toggleInPinboard(_ item: ClipboardItemModel, index: Int) {
        let enabled = !clipboardService.isInPinboard(item, index: index)
        clipboardService.setPinboard(id: item.id, index: index, enabled: enabled)
        loadItems()
    }
    
    func moveToPinboard(_ item: ClipboardItemModel, index: Int) {
        clipboardService.moveToPinboard(id: item.id, index: index)
        loadItems()
    }
    
    // MARK: - Filter Tab (All / Text / Image / File / Regex)
    
    /// Advances to the next tab: All → Text → Image → File → Regex → Pinboard 0…N-1 → All.
    func selectNextFilterTab() {
        withFilterMutation {
            if let pbIdx = activePinboardIndex {
                if pbIdx + 1 < AppSettings.pinboardCount {
                    selectPinboardFilter(index: pbIdx + 1)
                } else {
                    selectFilter(nil)
                }
            } else if isRegexPresetMode {
                if AppSettings.pinboardCount > 0 {
                    selectPinboardFilter(index: 0)
                } else {
                    selectFilter(nil)
                }
            } else if let t = selectedType {
                switch t {
                case .text: selectFilter(.image)
                case .image: selectFilter(.file)
                case .file: selectRegexPresetFilter()
                }
            } else {
                selectFilter(.text)
            }
        }
    }

    /// Moves to the previous tab: All → Pinboard N-1…0 → Regex → File → Image → Text → All.
    func selectPreviousFilterTab() {
        withFilterMutation {
            if let pbIdx = activePinboardIndex {
                if pbIdx > 0 {
                    selectPinboardFilter(index: pbIdx - 1)
                } else {
                    selectRegexPresetFilter()
                }
            } else if isRegexPresetMode {
                selectFilter(.file)
            } else if let t = selectedType {
                switch t {
                case .text: selectFilter(nil)
                case .image: selectFilter(.text)
                case .file: selectFilter(.image)
                }
            } else {
                if AppSettings.pinboardCount > 0 {
                    selectPinboardFilter(index: AppSettings.pinboardCount - 1)
                } else {
                    selectRegexPresetFilter()
                }
            }
        }
    }
    
    // MARK: - Paste Stack
    
    var isShowingPasteStack: Bool { panelMode == .pasteStack }
    
    func enterPasteStack() {
        panelMode = .pasteStack
    }
    
    func exitPasteStack() {
        panelMode = .history
    }
    
    func addToPasteStack(_ item: ClipboardItemModel) {
        pasteStackService.push(itemId: item.id)
        if panelMode == .pasteStack {
            loadItems()
        }
    }
    
    func removeFromPasteStack(_ item: ClipboardItemModel) {
        pasteStackService.removeTopEntry(for: item.id)
        if panelMode == .pasteStack {
            loadItems()
        }
    }
}
