//
//  ClipboardGridView.swift
//  Paste-iOS
//

import SwiftUI

struct ClipboardGridView: View {

    let items: [SharedClipboardItem]
    let copiedItemID: UUID?
    let isMultiSelectMode: Bool
    let selectedItemIDs: Set<UUID>
    let settings: iOSAppSettings
    let pinboardIndexForItem: (SharedClipboardItem) -> Int?
    let onTap: (SharedClipboardItem) -> Void
    let onDelete: (SharedClipboardItem) -> Void
    let onEdit: (SharedClipboardItem) -> Void
    let onTogglePin: (SharedClipboardItem) -> Void
    var onPreview: ((SharedClipboardItem) -> Void)?
    var onCopyPlainText: ((SharedClipboardItem) -> Void)?
    var onRename: ((SharedClipboardItem) -> Void)?
    var onShare: ((SharedClipboardItem) -> Void)?
    var onStartMultiSelect: (() -> Void)?

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var columns: [GridItem] {
        let count = sizeClass == .regular ? 3 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 10), count: count)
    }

    var body: some View {
        if items.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(items) { item in
                        ClipboardCardView(
                            item: item,
                            isCopied: copiedItemID == item.id,
                            isMultiSelectMode: isMultiSelectMode,
                            isSelected: selectedItemIDs.contains(item.id),
                            pinboardIndex: pinboardIndexForItem(item),
                            settings: settings
                        )
                        .onTapGesture { onTap(item) }
                        .contextMenu { contextMenu(for: item) }
                        .onDrag { itemProvider(for: item) }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(Color(UIColor.systemGroupedBackground))
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clipboard")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.tertiary)
            Text("mainpanel.empty.noHistory")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("mainpanel.empty.copyHint")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
    }

    // MARK: - Context menu

    @ViewBuilder
    private func contextMenu(for item: SharedClipboardItem) -> some View {
        if !isMultiSelectMode {
            if let url = item.detectedURL {
                Button {
                    UIApplication.shared.open(url)
                } label: {
                    Label(String(localized: "ios.card.openLink"), systemImage: "safari")
                }

                Divider()
            }

            Button {
                onTap(item)
            } label: {
                Label(String(localized: "ios.card.copy"), systemImage: "doc.on.doc")
            }

            Button {
                onCopyPlainText?(item)
            } label: {
                Label(String(localized: "ios.card.copyPlainText"), systemImage: "text.alignleft")
            }

            Divider()

            Button {
                onPreview?(item)
            } label: {
                Label(String(localized: "ios.card.preview"), systemImage: "eye")
            }

            Button {
                onEdit(item)
            } label: {
                Label(String(localized: "ios.card.edit"), systemImage: "pencil")
            }

            Button {
                onRename?(item)
            } label: {
                Label(String(localized: "ios.card.rename"), systemImage: "character.cursor.ibeam")
            }

            Divider()

            Button {
                onTogglePin(item)
            } label: {
                Label(
                    String(localized: item.isPinned ? "ios.card.unpin" : "ios.card.pin"),
                    systemImage: item.isPinned ? "pin.slash" : "pin"
                )
            }

            Button {
                onShare?(item)
            } label: {
                Label(String(localized: "ios.card.share"), systemImage: "square.and.arrow.up")
            }

            Divider()

            Button(role: .destructive) {
                onDelete(item)
            } label: {
                Label(String(localized: "ios.card.delete"), systemImage: "trash")
            }

            Button {
                onStartMultiSelect?()
            } label: {
                Label(String(localized: "ios.card.select"), systemImage: "checkmark.circle")
            }
        }
    }

    // MARK: - Drag

    private func itemProvider(for item: SharedClipboardItem) -> NSItemProvider {
        switch item.itemType {
        case .text:
            return NSItemProvider(object: (item.plainText ?? "") as NSString)
        case .image:
            let data = item.imageData ?? SharedThumbnailCache.loadImageData(for: item.id)
            if let data, let image = UIImage(data: data) {
                return NSItemProvider(object: image)
            }
            return NSItemProvider()
        case .file:
            return NSItemProvider(object: (item.displayText) as NSString)
        }
    }
}
