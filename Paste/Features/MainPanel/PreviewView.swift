//
//  PreviewView.swift
//  Paste
//
//  Preview window view — shows detailed content for the selected item
//

import SwiftUI
import AppKit

// MARK: - Arrow Indicator View

/// Arrow indicator that points down toward the item card (rendered below the preview frame).
struct ArrowIndicatorView: View {
    let arrowOffset: CGFloat // Horizontal offset from window center (positive = right, negative = left).
    
    private let arrowWidth: CGFloat = 20
    private let arrowHeight: CGFloat = 10
    
    var body: some View {
        GeometryReader { geometry in
            // Arrow shape pointing downward toward the item card.
            // The arrow area is transparent, but the arrow itself uses the same VisualEffectView as the preview frame for colour consistency.
            ZStack(alignment: .top) {
                // Use VisualEffectView for the arrow background so it matches the preview frame exactly.
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                    .frame(height: arrowHeight)
                    .clipShape(
                        // Clip to the arrow triangle shape.
                        Path { path in
                            let windowCenterX = geometry.size.width / 2
                            let centerX = windowCenterX + arrowOffset
                            // Clamp offset so the arrow stays within the window bounds.
                            let minX = max(arrowWidth / 2, min(centerX, geometry.size.width - arrowWidth / 2))
                            
                            // Arrow points downward from below the preview frame toward the item card.
                            path.move(to: CGPoint(x: minX - arrowWidth / 2, y: 0))
                            path.addLine(to: CGPoint(x: minX, y: arrowHeight))
                            path.addLine(to: CGPoint(x: minX + arrowWidth / 2, y: 0))
                            path.closeSubpath()
                        }
                    )
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            }
        }
        .frame(height: arrowHeight)
        .background(Color.clear) // Ensure transparent background.
    }
}

// MARK: - Async File Icon View

/// View component that loads a file icon asynchronously to avoid blocking the main thread.
struct AsyncFileIconView: View {
    let filePath: String
    @State private var icon: NSImage?
    
    var body: some View {
        Group {
            if let icon = icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 32, height: 32)
            } else {
                Image(systemName: "doc")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
                    .frame(width: 32, height: 32)
            }
        }
        .task(id: filePath) {
            await loadIcon()
        }
    }
    
    private func loadIcon() async {
        // Reset the icon first.
        icon = nil
        
        guard FileManager.default.fileExists(atPath: filePath) else {
            return
        }
        
        // Load the icon asynchronously.
        // Note: NSWorkspace.shared.icon(forFile:) is synchronous,
        // but running it on a background task avoids blocking main-thread UI updates.
        let loadedIcon = await Task.detached(priority: .userInitiated) {
            return NSWorkspace.shared.icon(forFile: filePath)
        }.value
        
        await MainActor.run {
            icon = loadedIcon
        }
    }
}

// MARK: - Preview View

struct PreviewView: View {
    @ObservedObject var viewModel: PreviewViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            Group {
                if let preset = viewModel.preset {
                    presetPreviewView(preset: preset)
                } else if let item = viewModel.item {
                    previewContent(for: item)
                } else {
                    emptyStateView
                }
            }
            .frame(width: 800, height: 400)
            .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
            .accessibilityElement(children: .contain)
            .accessibilityLabel(previewAccessibilityLabel())
            
            if viewModel.item != nil || viewModel.preset != nil {
                ArrowIndicatorView(arrowOffset: viewModel.arrowOffset)
                    .frame(width: 800)
            }
        }
        .id(viewModel.item?.id ?? viewModel.preset?.id)
    }
    
    private func previewAccessibilityLabel() -> String {
        if viewModel.preset != nil {
            return String(localized: "accessibility.preview.text")
        }
        guard let item = viewModel.item else { return "" }
        switch item.itemType {
        case .text: return String(localized: "accessibility.preview.text")
        case .image: return String(localized: "accessibility.preview.image")
        case .file: return String(localized: "accessibility.preview.file")
        }
    }

    private func presetPreviewView(preset: RegexPreset) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "curlybraces")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                Text("Regex")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            Divider()
                .background(Color(nsColor: .separatorColor))
            VStack(alignment: .leading, spacing: 8) {
                Text(preset.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                Text(preset.pattern)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)
            Spacer()
        }
    }
    
    @ViewBuilder
    private func previewContent(for item: ClipboardItemModel) -> some View {
        switch item.itemType {
        case .text:
            // Text: show plain text only, without type/word-count/time metadata.
            textPreviewView(for: item)
        case .image:
            // Image: show header info and the image.
            VStack(spacing: 0) {
                topBar(for: item)
                Divider()
                    .background(Color(nsColor: .separatorColor))
                imagePreviewView(for: item)
                    .padding(20)
            }
        case .file:
            // File: show header info and the file list.
            VStack(spacing: 0) {
                topBar(for: item)
                Divider()
                    .background(Color(nsColor: .separatorColor))
                ScrollView {
                    filePreviewView(for: item)
                        .padding(20)
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack {
            Spacer()
            Text(String(localized: "mainpanel.empty.noMatches"))
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Spacer()
        }
    }
    
    // MARK: - Top Bar
    
    private func topBar(for item: ClipboardItemModel) -> some View {
        HStack(spacing: 12) {
            // Type icon and name — from item properties.
            Image(systemName: item.itemType.iconName)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            Text(item.itemType.displayName)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer()
            
            // Source app info — matches the main panel display.
            if let appIcon = item.sourceAppIcon {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 16, height: 16)
            }
            
            if let appName = item.sourceAppName {
                Text(appName)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            // Timestamp — from item properties.
            Text(item.detailedTime)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    // MARK: - Content View
    
    @ViewBuilder
    private func contentView(for item: ClipboardItemModel) -> some View {
        switch item.itemType {
        case .text:
            textPreviewView(for: item)
        case .image:
            imagePreviewView(for: item)
        case .file:
            filePreviewView(for: item)
        }
    }
    
    // MARK: - Text Preview
    
    private func textPreviewView(for item: ClipboardItemModel) -> some View {
        // Plain text preview: show text only, no metadata, for optimal render performance.
        ScrollView {
            if let text = item.plainText, !text.isEmpty {
                Text(text)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true) // Optimise layout performance.
                    .padding(20)
                    .id(item.id) // Help SwiftUI identify view changes.
            } else {
                VStack {
                    Spacer()
                    Text(String(localized: "mainpanel.empty.noMatches"))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Image Preview
    
    private func imagePreviewView(for item: ClipboardItemModel) -> some View {
        VStack(spacing: 12) {
            if let sizeInfo = viewModel.previewImageSizeInfo {
                Text(sizeInfo)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            if let image = viewModel.previewImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .id(item.id)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text(String(localized: "mainpanel.empty.noMatches"))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    // MARK: - File Preview
    
    private func filePreviewView(for item: ClipboardItemModel) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // File count — matches the main panel display.
            if let count = item.fileCount {
                Text(String(format: String(localized: "mainpanel.file.fileCountFormat"), count))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            // File list — LazyVStack for performance.
            if let paths = item.filePathsArray, !paths.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(paths.enumerated()), id: \.offset) { index, path in
                            fileRow(path: path, index: index)
                        }
                    }
                }
                .frame(maxHeight: 300)
            } else {
                Text(String(localized: "mainpanel.empty.noMatches"))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    private func fileRow(path: String, index: Int) -> some View {
        HStack(spacing: 12) {
            // File icon — loaded asynchronously.
            AsyncFileIconView(filePath: path)
            
            VStack(alignment: .leading, spacing: 4) {
                // File name.
                let fileURL = URL(fileURLWithPath: path)
                Text(fileURL.lastPathComponent)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                
                // File path.
                Text(path)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // File extension.
            let fileURL = URL(fileURLWithPath: path)
            if !fileURL.pathExtension.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "tag")
                        .font(.system(size: 9))
                    Text(fileURL.pathExtension.uppercased())
                        .font(.system(size: 10, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.2))
                .foregroundColor(.orange)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

#Preview {
    let viewModel = PreviewViewModel()
    viewModel.updateItem(ClipboardItemModel(
        itemType: .text,
        plainText: "这是一段预览文本内容\n可以包含多行\n用于测试预览窗口的显示效果"
    ))
    viewModel.updateArrowOffset(0)
    return PreviewView(viewModel: viewModel)
}
