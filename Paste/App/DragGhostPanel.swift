//
//  DragGhostPanel.swift
//  Paste
//
//  Floating card preview panel that follows the cursor during drag-to-paste.
//  Matches the appearance of ClipboardCardView, with a slight rotation and shadow to convey a "lifted card" feel.
//

import AppKit
import SwiftUI

// MARK: - Ghost Panel

final class DragGhostPanel: NSPanel {

    init(item: ClipboardItemModel, cardSize: CGSize) {
        super.init(
            contentRect: NSRect(origin: .zero, size: cardSize),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 2)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let ghostView = DragGhostCardView(item: item, cardSize: cardSize)
        contentView = NSHostingView(rootView: ghostView)
    }
}

// MARK: - Ghost Card View

private struct DragGhostCardView: View {
    let item: ClipboardItemModel
    let cardSize: CGSize

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            contentPreview
                .frame(height: cardSize.height - bottomBarHeight)

            Divider()
                .background(Color(nsColor: .separatorColor))

            ghostBottomBar
        }
        .frame(width: cardSize.width, height: cardSize.height)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.accentColor.opacity(0.6), lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.45), radius: 20, x: 0, y: 8)
        .opacity(0.92)
    }

    private let bottomBarHeight: CGFloat = 32

    // MARK: Content

    @ViewBuilder
    private var contentPreview: some View {
        switch item.itemType {
        case .text:
            textPreview
        case .image:
            imagePreview
        case .file:
            filePreview
        }
    }

    private var textPreview: some View {
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
                Text(item.displayText)
                    .font(.system(size: 11))
                    .lineLimit(5)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(8)
            }
        }
    }

    private var imagePreview: some View {
        Group {
            if let thumbnail = ThumbnailCache.shared.thumbnail(for: item.id) {
                Image(nsImage: thumbnail)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(6)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var filePreview: some View {
        VStack(spacing: 6) {
            if let icon = item.fileIcon {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
            } else {
                Image(systemName: "doc")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
            }
            Text(item.displayText)
                .font(.system(size: 10))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(8)
    }

    // MARK: Bottom bar

    private var ghostBottomBar: some View {
        HStack(spacing: 4) {
            if let icon = item.sourceAppIcon {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
            }

            Spacer()

            Text(String(localized: "drag.ghost.releaseHint"))
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .frame(height: bottomBarHeight)
    }
}
