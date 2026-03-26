//
//  ClipboardGridView.swift
//  Paste
//
//  Scrollable card grids for the clipboard panel — horizontal (top/bottom) and vertical (left/right).
//

import SwiftUI
import AppKit

// MARK: - ClipboardGridView (horizontal, for top/bottom panels)

struct ClipboardGridView: View {
    @ObservedObject var viewModel: ClipboardViewModel

    var body: some View {
        if !viewModel.isRegexPresetMode && viewModel.filteredItems.isEmpty {
            emptyStateView
        } else {
            scrollContent
        }
    }

    private var scrollContent: some View {
        HorizontalScrollWheelBridge {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: PanelLayout.cardSpacing) {
                        ForEach(Array(viewModel.effectiveDisplayItems.enumerated()), id: \.element.id) { index, displayItem in
                            switch displayItem {
                            case .history(let item):
                                ClipboardCardView(
                                    item: item,
                                    isSelected: index == viewModel.selectedIndex || viewModel.selectedIndices.contains(index),
                                    activePinboardIndex: viewModel.activePinboardIndex,
                                    pinboardCount: AppSettings.pinboardCount,
                                    onSelect: { viewModel.selectedIndices = []; viewModel.selectedIndex = index },
                                    onPaste: { plainTextOnly in viewModel.pasteItem(item, plainTextOnly: plainTextOnly) },
                                    onWriteClipboard: { plainTextOnly in viewModel.writeClipboardOnly(item, plainTextOnly: plainTextOnly) },
                                    onTogglePinboard: { viewModel.toggleInPinboard(item, index: $0) },
                                    onMoveToPinboard: { viewModel.moveToPinboard(item, index: $0) },
                                    onAddToPasteStack: { viewModel.addToPasteStack(item) },
                                    onRemoveFromPasteStack: { viewModel.removeFromPasteStack(item) },
                                    isPasteStackMode: viewModel.panelMode == .pasteStack,
                                    onDelete: { viewModel.deleteItem(item) },
                                    onEdit: { viewModel.selectedIndex = index; viewModel.showEditSheet = true }
                                )
                                .overlay(alignment: .topLeading) { quickPasteHint(for: index) }
                                .id(displayItem.id)
                            case .preset(let preset):
                                RegexPresetCardView(
                                    preset: preset,
                                    isSelected: index == viewModel.selectedIndex || viewModel.selectedIndices.contains(index),
                                    onSelect: { viewModel.selectedIndices = []; viewModel.selectedIndex = index },
                                    onPaste: { viewModel.pasteSelectedDisplayItem(plainTextOnly: $0) }
                                )
                                .overlay(alignment: .topLeading) { quickPasteHint(for: index) }
                                .id(displayItem.id)
                            }
                        }
                    }
                    // Vertical padding is on the content layer; horizontal padding moves to contentMargins for correct viewAligned snapping.
                    .padding(.vertical, PanelLayout.vertPadding)
                    .scrollTargetLayout()
                }
                // Horizontal padding as contentMargins ensures 20pt leading space after each snap.
                .contentMargins(.horizontal, PanelLayout.panelPadding, for: .scrollContent)
                // Card alignment snapping: after each scroll stop, snap to the nearest card boundary.
                .scrollTargetBehavior(.viewAligned)
                .onScrollGeometryChange(for: CGFloat.self, of: { $0.contentOffset.x }) { _, x in
                    let screenW = NSScreen.main?.frame.width ?? 1920
                    let cs = PanelLayout.cardSize(
                        position: AppSettings.panelPosition,
                        screenSize: CGSize(width: screenW, height: 0)
                    )
                    let step = cs.width + PanelLayout.cardSpacing
                    viewModel.firstVisibleIndex = max(0, Int((x / step).rounded()))
                }
                .onChange(of: viewModel.selectedIndex) { _, _ in
                    let list = viewModel.effectiveDisplayItems
                    guard viewModel.selectedIndex < list.count else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(list[viewModel.selectedIndex].id, anchor: .center)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func quickPasteHint(for index: Int) -> some View {
        let offset = index - viewModel.firstVisibleIndex
        if viewModel.isCommandHeld, offset >= 0, offset < 9 {
            Text("\(offset + 1)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .shadow(radius: 2)
                .padding(4)
                .transition(.scale.combined(with: .opacity))
                .animation(.easeInOut(duration: 0.12), value: viewModel.isCommandHeld)
        }
    }

    private var emptyStateView: some View {
        HStack {
            Spacer()
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
            Spacer()
        }
        .frame(maxHeight: .infinity)
    }
}

// MARK: - ClipboardGridVerticalView (for left/right panels)

struct ClipboardGridVerticalView: View {
    @ObservedObject var viewModel: ClipboardViewModel

    var body: some View {
        if !viewModel.isRegexPresetMode && viewModel.filteredItems.isEmpty {
            emptyStateView
        } else {
            scrollContent
        }
    }

    private var scrollContent: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: PanelLayout.cardSpacing) {
                    ForEach(Array(viewModel.effectiveDisplayItems.enumerated()), id: \.element.id) { index, displayItem in
                        switch displayItem {
                        case .history(let item):
                            ClipboardCardView(
                                item: item,
                                isSelected: index == viewModel.selectedIndex || viewModel.selectedIndices.contains(index),
                                activePinboardIndex: viewModel.activePinboardIndex,
                                pinboardCount: AppSettings.pinboardCount,
                                onSelect: { viewModel.selectedIndices = []; viewModel.selectedIndex = index },
                                onPaste: { plainTextOnly in viewModel.pasteItem(item, plainTextOnly: plainTextOnly) },
                                onWriteClipboard: { plainTextOnly in viewModel.writeClipboardOnly(item, plainTextOnly: plainTextOnly) },
                                onTogglePinboard: { viewModel.toggleInPinboard(item, index: $0) },
                                onMoveToPinboard: { viewModel.moveToPinboard(item, index: $0) },
                                onAddToPasteStack: { viewModel.addToPasteStack(item) },
                                onRemoveFromPasteStack: { viewModel.removeFromPasteStack(item) },
                                isPasteStackMode: viewModel.panelMode == .pasteStack,
                                onDelete: { viewModel.deleteItem(item) },
                                onEdit: { viewModel.selectedIndex = index; viewModel.showEditSheet = true }
                            )
                            .overlay(alignment: .topLeading) { quickPasteHint(for: index) }
                            .id(displayItem.id)
                        case .preset(let preset):
                            RegexPresetCardView(
                                preset: preset,
                                isSelected: index == viewModel.selectedIndex || viewModel.selectedIndices.contains(index),
                                onSelect: { viewModel.selectedIndices = []; viewModel.selectedIndex = index },
                                onPaste: { viewModel.pasteSelectedDisplayItem(plainTextOnly: $0) }
                            )
                            .overlay(alignment: .topLeading) { quickPasteHint(for: index) }
                            .id(displayItem.id)
                        }
                    }
                }
                // Horizontal padding is on the content layer; vertical padding moves to contentMargins for correct viewAligned snapping.
                .padding(.horizontal, PanelLayout.panelPadding)
                .scrollTargetLayout()
            }
            // Vertical padding as contentMargins ensures 12pt top space after each snap.
            .contentMargins(.vertical, PanelLayout.vertPadding, for: .scrollContent)
            // Card alignment snapping: after each scroll stop, snap to the nearest card boundary.
            .scrollTargetBehavior(.viewAligned)
            .onScrollGeometryChange(for: CGFloat.self, of: { $0.contentOffset.y }) { _, y in
                let screenH = NSScreen.main?.frame.height ?? 900
                let cs = PanelLayout.cardSize(
                    position: AppSettings.panelPosition,
                    screenSize: CGSize(width: 0, height: screenH)
                )
                let step = cs.height + PanelLayout.cardSpacing
                viewModel.firstVisibleIndex = max(0, Int((y / step).rounded()))
            }
            .onChange(of: viewModel.selectedIndex) { _, _ in
                let list = viewModel.effectiveDisplayItems
                guard viewModel.selectedIndex < list.count else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(list[viewModel.selectedIndex].id, anchor: .center)
                }
            }
        }
    }

    @ViewBuilder
    private func quickPasteHint(for index: Int) -> some View {
        let offset = index - viewModel.firstVisibleIndex
        if viewModel.isCommandHeld, offset >= 0, offset < 9 {
            Text("\(offset + 1)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .shadow(radius: 2)
                .padding(4)
                .transition(.scale.combined(with: .opacity))
                .animation(.easeInOut(duration: 0.12), value: viewModel.isCommandHeld)
        }
    }

    private var emptyStateView: some View {
        HStack {
            Spacer()
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
            Spacer()
        }
        .frame(maxHeight: .infinity)
    }
}
