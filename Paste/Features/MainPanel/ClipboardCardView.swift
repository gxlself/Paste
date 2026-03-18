//
//  ClipboardCardView.swift
//  Paste
//
//  Card view for individual clipboard history items.
//

import SwiftUI
import AppKit
import QuickLookThumbnailing

// MARK: - Accessibility Helper

func clipboardCardAccessibilityLabel(for item: ClipboardItemModel) -> String {
    let time = item.formattedTime
    switch item.itemType {
    case .text:
        if let raw = item.plainText?.trimmingCharacters(in: .whitespacesAndNewlines),
           !raw.contains("\n"),
           ColorCodeHelper.color(from: raw) != nil {
            return String(format: String(localized: "accessibility.mainpanel.card.colorFormat"), raw, time)
        }
        let preview = String((item.displayText).prefix(50))
        let count = item.characterCount ?? 0
        return String(format: String(localized: "accessibility.mainpanel.card.textFormat"), preview, count, time)
    case .image:
        let sizeInfo = item.imageSizeInfo ?? ""
        return String(format: String(localized: "accessibility.mainpanel.card.imageFormat"), sizeInfo, time)
    case .file:
        let name = item.filePathsArray?.first.flatMap { URL(fileURLWithPath: $0).lastPathComponent } ?? ""
        return String(format: String(localized: "accessibility.mainpanel.card.fileFormat"), name, time)
    }
}

// MARK: - ClipboardCardView

struct ClipboardCardView: View {
    let item: ClipboardItemModel
    let isSelected: Bool
    let activePinboardIndex: Int?
    let pinboardCount: Int
    let onSelect: () -> Void
    let onPaste: (_ plainTextOnly: Bool) -> Void
    /// On drag end, writes to the clipboard only; the paste notification is posted by AppDelegate after the ghost animation.
    let onWriteClipboard: (_ plainTextOnly: Bool) -> Void
    let onTogglePinboard: (_ pinboardIndex: Int) -> Void
    let onMoveToPinboard: (_ pinboardIndex: Int) -> Void
    let onAddToPasteStack: () -> Void
    let onRemoveFromPasteStack: () -> Void
    let isPasteStackMode: Bool
    let onDelete: () -> Void
    var customTypes: [CustomType] = []
    var onToggleCustomType: ((_ typeId: String) -> Void)?

    @State private var isHovered = false
    @State private var isDragging = false
    @Environment(\.cardSize) private var cardSize

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            contentView
                .frame(height: cardSize.height - 32)

            Divider()
                .background(Color(nsColor: .separatorColor))

            bottomBar
        }
        .frame(width: cardSize.width, height: cardSize.height)
        .background(isSelected ? Color.accentColor.opacity(0.3) : Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: isSelected ? 2 : 1)
        )
        .overlay(alignment: .topLeading) {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 1)
                    .padding(6)
            }
        }
        .shadow(color: .black.opacity(isDragging ? 0.5 : isSelected ? 0.3 : 0.1),
                radius: isDragging ? 16 : isSelected ? 8 : 4)
        .scaleEffect(isDragging ? 1.05 : isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.12), value: isDragging)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .contentShape(Rectangle())
        // NSView overlay: directly handles AppKit mouse events, bypassing ScrollView gesture interception,
        // and also handles hover tracking, replacing .onHover and .highPriorityGesture(TapGesture()).
        .overlay(
            CardInteractionOverlay(
                isHovered: $isHovered,
                isDragging: $isDragging,
                onTap: handleTap,
                onDragBegan: {
                    NotificationCenter.default.post(name: AppNotification.clipboardItemDragBegan, object: item)
                },
                onDragEnded: { mouseLocation in
                    onSelect()
                    let plainText = AppSettings.pastePlainTextByDefault
                        || NSEvent.modifierFlags.contains(AppSettings.plainTextModifier)
                    onWriteClipboard(plainText)
                    NotificationCenter.default.post(
                        name: AppNotification.clipboardItemDragEnded,
                        object: nil,
                        userInfo: ["location": NSValue(point: mouseLocation)]
                    )
                }
            )
        )
        .contextMenu {
            Button("mainpanel.context.paste") { onPaste(AppSettings.pastePlainTextByDefault) }
            Button("mainpanel.context.delete", role: .destructive) { onDelete() }
            Divider()

            if isPasteStackMode {
                Button("mainpanel.context.removeFromPasteStack") { onRemoveFromPasteStack() }
            } else {
                Button("mainpanel.context.addToPasteStack") { onAddToPasteStack() }
            }

            if let current = activePinboardIndex {
                Button("mainpanel.context.togglePinboardCurrent") { onTogglePinboard(current) }
            }

            Menu("mainpanel.context.pinboard") {
                ForEach(0..<pinboardCount, id: \.self) { index in
                    Button(String(format: String(localized: "mainpanel.context.pinboard.moveFormat"), index + 1)) {
                        onMoveToPinboard(index)
                    }
                }
            }

            if !customTypes.isEmpty {
                let assignedIds = Set(item.tagsArray.parsedTags().compactMap(\.customTypeId))
                Menu("Assign to Type") {
                    ForEach(customTypes) { ct in
                        Button {
                            onToggleCustomType?(ct.id)
                        } label: {
                            if assignedIds.contains(ct.id) {
                                Label(ct.name, systemImage: "checkmark")
                            } else {
                                Text(ct.name)
                            }
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(clipboardCardAccessibilityLabel(for: item))
        .accessibilityHint(Text("accessibility.mainpanel.card.hint"))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func handleTap() {
        onSelect()
        guard AppSettings.directPasteEnabled else { return }
        let shouldPlainText = AppSettings.pastePlainTextByDefault
            || NSEvent.modifierFlags.contains(AppSettings.plainTextModifier)
        onPaste(shouldPlainText)
    }

    // MARK: - Content View

    @ViewBuilder
    private var contentView: some View {
        switch item.itemType {
        case .text:  textContentView
        case .image: imageContentView
        case .file:
            if item.isImageFile, let path = item.filePathsArray?.first {
                FileImagePreview(path: path)
            } else {
                fileContentView
            }
        }
    }

    private var textContentView: some View {
        Group {
            if let nsColor = ColorCodeHelper.color(from: item.plainText ?? "") {
                Text(item.displayText)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color(nsColor: ColorCodeHelper.contrastingTextColor(for: nsColor)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(8)
                    .background(Color(nsColor: nsColor))
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.displayText)
                        .font(.system(size: 11))
                        .lineLimit(4)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer()
                }
                .padding(8)
            }
        }
    }

    private var imageContentView: some View {
        Group {
            if let thumbnail = ThumbnailCache.shared.thumbnail(for: item.id) {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                Color(nsColor: .controlBackgroundColor)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                    )
            }
        }
    }

    private var fileContentView: some View {
        VStack(spacing: 6) {
            if let icon = item.fileIcon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 36, height: 36)
            } else {
                Image(systemName: "doc")
                    .font(.system(size: 28))
                    .foregroundColor(.secondary)
            }

            if let paths = item.filePathsArray, let firstPath = paths.first {
                let fileName = URL(fileURLWithPath: firstPath).lastPathComponent
                let fileExt = URL(fileURLWithPath: firstPath).pathExtension.uppercased()

                Text(fileName)
                    .font(.system(size: 10))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)

                if !fileExt.isEmpty {
                    HStack(spacing: 2) {
                        Image(systemName: "tag")
                            .font(.system(size: 8))
                        Text(".\(fileExt)")
                            .font(.system(size: 9, weight: .medium))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.2))
                    .foregroundColor(.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(8)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 4) {
            if let appIcon = item.sourceAppIcon {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 14, height: 14)
            } else {
                Image(systemName: item.itemType.iconName)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            extraInfoView

            Text(item.formattedTime)
                .font(.system(size: 9))
                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var extraInfoView: some View {
        switch item.itemType {
        case .text:
            if let count = item.characterCount {
                Text(String(format: String(localized: "mainpanel.text.characterCountFormat"), count))
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        case .image:
            if let sizeInfo = item.imageSizeInfo {
                Text(sizeInfo)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        case .file:
            if let count = item.fileCount, count > 1 {
                Text(String(format: String(localized: "mainpanel.file.fileCountFormat"), count))
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - File Image Preview

/// Asynchronously loads a Quick Look thumbnail for an image file stored as a .file clipboard item.
/// Falls back to a raw NSImage load and then to a generic photo placeholder.
private struct FileImagePreview: View {
    let path: String

    @State private var thumbnail: NSImage?
    @State private var didAttemptLoad = false

    var body: some View {
        Group {
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else if didAttemptLoad {
                Color(nsColor: .controlBackgroundColor)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                    )
            } else {
                Color(nsColor: .controlBackgroundColor)
            }
        }
        .task(id: path) {
            thumbnail = await loadThumbnail(for: path)
            didAttemptLoad = true
        }
    }

    private func loadThumbnail(for path: String) async -> NSImage? {
        let url = URL(fileURLWithPath: path)

        // Try Quick Look (works within sandbox for clipboard-accessible files).
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: 300, height: 300),
            scale: 2.0,
            representationTypes: .thumbnail
        )
        if let rep = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request) {
            return rep.nsImage
        }

        // Fallback: try loading the raw file data directly.
        if let data = try? Data(contentsOf: url), let image = NSImage(data: data) {
            return image
        }

        return nil
    }
}
