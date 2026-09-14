import AppKit
import SwiftUI

struct ClipboardDisplayRows: RandomAccessCollection {
    struct Row: Identifiable {
        struct ID: Hashable {
            let itemID: UUID
            let stackOffset: Int?
        }
        let index: Int
        let displayItem: DisplayItem
        let id: ID
    }
    let items: [ClipboardItemModel]
    let isRegexPresetMode: Bool
    let isPasteStackMode: Bool
    var startIndex: Int { 0 }
    var endIndex: Int { isRegexPresetMode ? RegexPreset.all.count : items.count }
    subscript(index: Int) -> Row {
        let item: DisplayItem = isRegexPresetMode
            ? .preset(RegexPreset.all[index]) : .history(items[index])
        return Row(index: index, displayItem: item,
                   id: Row.ID(itemID: item.id, stackOffset: isPasteStackMode ? index : nil))
    }
}

private struct ClipboardGridCell: View {
    let row: ClipboardDisplayRows.Row
    @ObservedObject var viewModel: ClipboardViewModel
    @Environment(\.cardSize) private var cardSize

    var body: some View {
        Group {
            switch row.displayItem {
            case .history(let item):
                ClipboardCardView(
                    item: item, isSelected: isSelected,
                    activePinboardIndex: viewModel.activePinboardIndex,
                    pinboardCount: AppSettings.pinboardCount,
                    onSelect: select,
                    onPaste: { viewModel.pasteItem(item, plainTextOnly: $0) },
                    onWriteClipboard: { viewModel.writeClipboardOnly(item, plainTextOnly: $0) },
                    onTogglePinboard: { viewModel.toggleInPinboard(item, index: $0) },
                    onMoveToPinboard: { viewModel.moveToPinboard(item, index: $0) },
                    onAddToPasteStack: { viewModel.addToPasteStack(item) },
                    onRemoveFromPasteStack: { viewModel.removeFromPasteStack(item) },
                    isPasteStackMode: viewModel.isShowingPasteStack,
                    onDelete: { viewModel.deleteItem(item) },
                    onEdit: { select(); viewModel.showEditSheet = true }
                )
            case .preset(let preset):
                RegexPresetCardView(
                    preset: preset, isSelected: isSelected, onSelect: select,
                    onPaste: { select(); viewModel.pasteSelectedDisplayItem(plainTextOnly: $0) }
                )
            }
        }
        .frame(width: cardSize.width, height: cardSize.height)
        .overlay(alignment: .topLeading) {
            let offset = row.index - viewModel.firstVisibleIndex
            if viewModel.isCommandHeld, (0..<9).contains(offset) {
                Text("\(offset + 1)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 20, height: 20)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .padding(4)
            }
        }
    }

    private var isSelected: Bool {
        row.index == viewModel.selectedIndex || viewModel.selectedIndices.contains(row.index)
    }
    private func select() {
        viewModel.selectedIndices = []
        viewModel.selectedIndex = row.index
    }
}

struct ClipboardGridView: View {
    @ObservedObject var viewModel: ClipboardViewModel
    var body: some View {
        ClipboardGridContent(viewModel: viewModel, vertical: false)
    }
}

struct ClipboardGridVerticalView: View {
    @ObservedObject var viewModel: ClipboardViewModel
    var body: some View {
        ClipboardGridContent(viewModel: viewModel, vertical: true)
    }
}

private struct ClipboardGridContent: View {
    @ObservedObject var viewModel: ClipboardViewModel
    @Environment(\.cardSize) private var cardSize
    let vertical: Bool

    private var rows: ClipboardDisplayRows {
        ClipboardDisplayRows(items: viewModel.filteredItems,
                             isRegexPresetMode: viewModel.isRegexPresetMode,
                             isPasteStackMode: viewModel.isShowingPasteStack)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(vertical ? .vertical : .horizontal, showsIndicators: false) {
                Group {
                    if vertical {
                        LazyVStack(spacing: PanelLayout.cardSpacing) { cells }
                            .padding(.horizontal, PanelLayout.panelPadding)
                    } else {
                        LazyHStack(spacing: PanelLayout.cardSpacing) { cells }
                            .padding(.vertical, PanelLayout.vertPadding)
                    }
                }
                .scrollTargetLayout()
            }
            .background {
                if !vertical { HorizontalScrollWheelBridge() }
            }
            .contentMargins(vertical ? .vertical : .horizontal,
                            vertical ? PanelLayout.vertPadding : PanelLayout.panelPadding, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .onScrollGeometryChange(for: Int.self, of: { geometry in
                let offset = vertical ? geometry.contentOffset.y + geometry.contentInsets.top
                    : geometry.contentOffset.x + geometry.contentInsets.leading
                let stride = (vertical ? cardSize.height : cardSize.width) + PanelLayout.cardSpacing
                return max(0, Int((offset / max(1, stride)).rounded()))
            }) { _, index in
                viewModel.updateFirstVisibleIndex(index)
            }
            .onChange(of: viewModel.selectedIndex) { _, _ in
                scrollToSelection(proxy, anchor: .center)
            }
            .onChange(of: viewModel.displayRevision) { _, _ in
                if viewModel.selectedIndex != 0 {
                    scrollToSelection(proxy, anchor: vertical ? .top : .leading)
                }
            }
            .overlay {
                if rows.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                        Text(viewModel.searchText.isEmpty
                             ? String(localized: "mainpanel.empty.noHistory")
                             : String(localized: "mainpanel.empty.noMatches"))
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .allowsHitTesting(false)
                }
            }
        }
        .id(viewModel.displayScopeID)
        .transaction {
            $0.animation = nil
            $0.disablesAnimations = true
        }
    }

    private var cells: some View {
        ForEach(rows) { row in
            ClipboardGridCell(row: row, viewModel: viewModel)
        }
    }

    private func scrollToSelection(_ proxy: ScrollViewProxy, anchor: UnitPoint) {
        guard rows.indices.contains(viewModel.selectedIndex) else { return }
        proxy.scrollTo(rows[viewModel.selectedIndex].id, anchor: anchor)
    }
}
