//
//  paste_toolTests.swift
//  PasteTests
//
//
//

import Testing
import AppKit
@testable import Paste

@MainActor
@Suite(.serialized)
struct ClipboardPanelTests {
    private func fixtures(_ count: Int = 6_000) -> [ClipboardItemModel] {
        (0..<count).map {
            ClipboardItemModel(itemType: $0 % 5 == 0 ? .image : .text,
                               plainText: "fixture \($0)",
                               tags: $0 % 9 == 0 ? ["pinboard:0"] : [])
        }
    }

    @Test func allToTextUsesCachedSnapshot() {
        let model = ClipboardViewModel(initialItems: fixtures())
        let revision = model.displayRevision
        model.selectNextFilterTab()
        #expect(model.selectedType == .text)
        #expect(model.filteredItems.count == 4_800)
        #expect(model.filteredItems.allSatisfy { $0.itemType == .text })
        #expect(!model.isFiltering)
        #expect(model.displayRevision == revision + 1)
        model.selectFilter(.text)
        #expect(model.displayRevision == revision + 1)
    }

    @Test func rapidTabCyclesDoNotLeaveStaleResults() async {
        let model = ClipboardViewModel(initialItems: fixtures())
        for _ in 0..<15 {
            model.selectPinboardFilter(index: 0)
            model.selectFilter(.image)
            model.selectFilter(nil)
            model.selectFilter(.text)
        }
        await model.waitForPendingFilters()
        await Task.yield()
        #expect(model.filteredItems.count == 4_800)
        #expect(model.selectedType == .text)
        #expect(!model.isFiltering)
    }

    @Test func hideCancelsPendingFilterAndReopenUsesCurrentTab() async {
        let model = ClipboardViewModel(initialItems: fixtures())
        model.selectPinboardFilter(index: 0)
        let revision = model.displayRevision
        model.suspendForHiddenPanel()
        model.selectFilter(.text)
        await model.waitForPendingFilters()
        #expect(model.displayRevision == revision)
        model.prepareForPresentation()
        #expect(model.filteredItems.count == 4_800)
        #expect(model.selectedIndex == 0)
        #expect(!model.isFiltering)
    }

    @Test func repeatedShowDoesNotRebuildUnchangedSnapshot() {
        let model = ClipboardViewModel(initialItems: fixtures())
        model.selectFilter(.text)
        let revision = model.displayRevision
        for _ in 0..<10 {
            model.suspendForHiddenPanel()
            model.prepareForPresentation()
        }
        #expect(model.displayRevision == revision)
        #expect(model.filteredItems.count == 4_800)
    }

    @Test func tabChangeResetsSelectionAndClearsMultiSelection() {
        let values = fixtures(40)
        let model = ClipboardViewModel(initialItems: values)
        model.selectedIndex = 7
        model.selectedIndices = [6, 7, 8]
        model.selectFilter(.text)
        #expect(model.selectedIndex == 0)
        #expect(model.selectedItem?.id == values[1].id)
        #expect(model.selectedIndices.isEmpty)
        model.selectRegexPresetFilter()
        #expect(model.displayItemCount == RegexPreset.all.count)
        #expect(model.selectedIndex < model.displayItemCount)
        model.selectFilter(.file)
        #expect(model.selectedDisplayItem == nil)
        #expect(model.selectedIndex == 0)
    }

    @Test func sparsePinboardDoesNotScrollAllToAnOldItem() async {
        var values = fixtures()
        values.append(ClipboardItemModel(itemType: .text, plainText: "old pinboard item", tags: ["pinboard:1"]))
        let model = ClipboardViewModel(initialItems: values)
        model.activePinboardIndex = 1
        await model.waitForPendingFilters()
        #expect(model.filteredItems.count == 1)
        #expect(model.selectedItem?.id == values.last?.id)
        let oldScope = model.displayScopeID
        model.selectFilter(nil)
        #expect(model.selectedIndex == 0)
        #expect(model.selectedItem?.id == values.first?.id)
        #expect(model.displayScopeID > oldScope)
        model.selectFilter(.text)
        #expect(model.selectedIndex == 0)
        #expect(model.selectedItem?.id == values[1].id)
    }

    @Test func emptyHistorySupportsEveryTab() async {
        let model = ClipboardViewModel(initialItems: [])
        for _ in 0..<16 { model.selectNextFilterTab() }
        model.selectFilter(nil)
        await model.waitForPendingFilters()
        #expect(model.filteredItems.isEmpty)
        #expect(model.selectedItem == nil)
        #expect(model.displayItem(at: -1) == nil)
        #expect(model.displayItem(at: 0) == nil)
    }

    @Test func filterMatchesFilesAndTextWithoutMatchingImages() {
        let values = [
            ClipboardItemModel(itemType: .text, plainText: "Hello Swift", tags: ["pinboard:0"]),
            ClipboardItemModel(itemType: .file, filePaths: ["/tmp/Swift.txt"], tags: ["pinboard:0"]),
            ClipboardItemModel(itemType: .image, plainText: "Swift")
        ]
        let results = ClipboardFilterEngine.filter(
            items: values, panelMode: .history, pasteStackItemIDs: [],
            activePinboardIndex: 0, selectedType: nil, selectedCustomTypeId: nil,
            normalizedKeyword: "swift"
        )
        #expect(results.map(\.id) == Array(values.prefix(2)).map(\.id))
    }

    @Test func repeatedStackItemsHaveDistinctRowIDs() {
        let item = ClipboardItemModel(itemType: .text, plainText: "repeat")
        let rows = ClipboardDisplayRows(items: [item, item], isRegexPresetMode: false, isPasteStackMode: true)
        #expect(rows.count == 2)
        #expect(rows[0].id != rows[1].id)
    }

    @Test func historyRowIdentitySurvivesChangedIndex() {
        let values = fixtures(20)
        let all = ClipboardDisplayRows(items: values, isRegexPresetMode: false, isPasteStackMode: false)
        let text = ClipboardDisplayRows(items: values.filter { $0.itemType == .text },
                                       isRegexPresetMode: false, isPasteStackMode: false)
        #expect(all[1].id == text[0].id)
    }

    @Test func displayRowsUseDirectIndexedAccess() {
        let values = fixtures(50_000)
        let rows = ClipboardDisplayRows(items: values, isRegexPresetMode: false, isPasteStackMode: false)
        #expect(rows.count == 50_000)
        #expect(rows[49_999].id.itemID == values[49_999].id)
        #expect(rows[49_999].index == 49_999)
    }

    @Test func cardPreviewIsBoundedWithoutChangingClipboardText() {
        let text = String(repeating: "large text ", count: 50_000)
        let item = ClipboardItemModel(itemType: .text, plainText: text)
        #expect(item.cardPreviewText.count == 512)
        #expect(item.plainText == text)
        #expect(item.displayText == text)
    }

    @Test func escapeHidesPanelSynchronously() {
        let model = ClipboardViewModel(initialItems: [])
        let coordinator = PanelCoordinator(viewModel: model)
        coordinator.setupPanel { _ in false }
        coordinator.panel?.orderFrontRegardless()
        #expect(coordinator.isVisible)
        var completionCalled = false
        coordinator.hideWithAnimation { completionCalled = true }
        #expect(!coordinator.isVisible)
        #expect(completionCalled)
        coordinator.panel?.orderFrontRegardless()
        #expect(coordinator.isVisible)
        coordinator.hide()
        #expect(!coordinator.isVisible)
    }
}
