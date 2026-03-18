//
//  PreviewSheet.swift
//  Paste-iOS
//

import SwiftUI

struct PreviewSheet: View {

    let item: SharedClipboardItem
    var onCopy: ((SharedClipboardItem) -> Void)?
    var onPinToCategory: ((SharedClipboardItem, Int) -> Void)?
    var onShare: ((SharedClipboardItem) -> Void)?
    var onDelete: ((SharedClipboardItem) -> Void)?
    var onUpdateImage: ((SharedClipboardItem, Data) -> Void)?
    var settings: iOSAppSettings?

    @Environment(\.dismiss) private var dismiss
    @State private var currentImage: UIImage?
    @State private var imageDataSize: Int = 0
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var isEditing = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                switch item.itemType {
                case .image:
                    imagePreview
                case .text:
                    textPreview
                case .file:
                    filePreview
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if item.itemType == .image {
                        editMenu
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("ios.preview.title")
                        .font(.headline)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            let data = item.imageData ?? SharedThumbnailCache.loadImageData(for: item.id)
            if let data {
                currentImage = UIImage(data: data)
                imageDataSize = data.count
            }
        }
    }

    // MARK: - Image Preview

    private var imagePreview: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                let img = currentImage ?? UIImage()
                ZStack {
                    Color(UIColor.systemGroupedBackground)

                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(magnificationGesture)
                        .simultaneousGesture(dragGesture)
                        .onTapGesture(count: 2) { resetZoom() }
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
            }

            imageSizeInfo
            Divider()
            bottomToolbar
        }
    }

    // MARK: - Image Size Info

    private var imageSizeInfo: some View {
        Group {
            if let img = currentImage {
                let w = Int(img.size.width * img.scale)
                let h = Int(img.size.height * img.scale)
                let sizeStr = formattedDataSize(imageDataSize)
                Text("\(w) × \(h) px · \(sizeStr)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 10)
            }
        }
    }

    // MARK: - Gestures

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let proposed = lastScale * value
                scale = min(max(proposed, 0.5), 5.0)
            }
            .onEnded { _ in
                if scale < 1.0 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        scale = 1.0
                        offset = .zero
                        lastOffset = .zero
                    }
                }
                lastScale = scale
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > 1.0 else { return }
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }

    private func resetZoom() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            scale = scale > 1.0 ? 1.0 : 2.0
            lastScale = scale
            if scale == 1.0 {
                offset = .zero
                lastOffset = .zero
            }
        }
    }

    // MARK: - Edit Menu (rotate)

    private var editMenu: some View {
        Menu {
            Button {
                rotateImage(.left)
            } label: {
                Label(String(localized: "ios.preview.rotateLeft"), systemImage: "rotate.left")
            }
            Button {
                rotateImage(.right)
            } label: {
                Label(String(localized: "ios.preview.rotateRight"), systemImage: "rotate.right")
            }
        } label: {
            Text("ios.preview.edit")
                .font(.body)
        }
    }

    private enum RotateDirection { case left, right }

    private func rotateImage(_ direction: RotateDirection) {
        guard let source = currentImage else { return }
        let angle: CGFloat = direction == .left ? -.pi / 2 : .pi / 2
        guard let rotated = source.rotated(by: angle) else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            currentImage = rotated
        }
        resetZoom()

        if let data = rotated.pngData() {
            onUpdateImage?(item, data)
        }
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        HStack(spacing: 0) {
            toolbarButton(icon: "doc.on.doc", label: "ios.card.copy") {
                onCopy?(item)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }

            pinMenu

            toolbarButton(icon: "square.and.arrow.up", label: "ios.card.share") {
                onShare?(item)
            }

            toolbarButton(icon: "trash", label: "ios.card.delete", role: .destructive) {
                onDelete?(item)
                dismiss()
            }
        }
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }

    private func toolbarButton(
        icon: String,
        label: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role) {
            action()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(String(localized: String.LocalizationValue(label)))
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .foregroundStyle(role == .destructive ? Color.red : Color.accentColor)
    }

    private var pinMenu: some View {
        let categories: [(type: ClipboardItemType?, label: String, icon: String, index: Int)] = [
            (nil, "mainpanel.filter.all", "square.grid.2x2", 0),
            (.text, "mainpanel.filter.text", "doc.text", 1),
            (.image, "mainpanel.filter.image", "photo", 2),
            (.file, "mainpanel.filter.file", "folder", 3),
        ]
        return Menu {
            ForEach(categories, id: \.index) { cat in
                Button {
                    onPinToCategory?(item, cat.index)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    let name = settings?.filterTabName(for: cat.type)
                        ?? String(localized: String.LocalizationValue(cat.label))
                    Label(name, systemImage: cat.icon)
                }
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: item.isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 20))
                Text(String(localized: item.isPinned ? "ios.card.unpin" : "ios.card.pin"))
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(Color.accentColor)
    }

    // MARK: - Text Preview

    private var textPreview: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerInfo
                    Divider()
                    if let rtf = item.rtfData,
                       let attrStr = try? NSAttributedString(
                        data: rtf,
                        options: [.documentType: NSAttributedString.DocumentType.rtf],
                        documentAttributes: nil
                       ) {
                        Text(AttributedString(attrStr))
                            .font(.body)
                            .textSelection(.enabled)
                    } else {
                        Text(item.plainText ?? "")
                            .font(.body)
                            .textSelection(.enabled)
                    }
                }
                .padding()
            }

            Divider()
            bottomToolbar
        }
    }

    // MARK: - File Preview

    private var filePreview: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerInfo
                    Divider()
                    Label(item.displayText, systemImage: "doc")
                        .font(.body)
                        .textSelection(.enabled)
                }
                .padding()
            }

            Divider()
            bottomToolbar
        }
    }

    // MARK: - Header Info

    private var headerInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: item.itemType.iconName)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text(item.itemType.displayName)
                    .font(.headline)
                Spacer()
                Text(item.formattedTime)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            if let icon = item.sourceAppIcon, let appName = item.sourceAppName {
                HStack(spacing: 4) {
                    Image(uiImage: icon)
                        .resizable()
                        .frame(width: 16, height: 16)
                        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                    Text(String(format: NSLocalizedString("ios.preview.sourceApp", comment: ""), appName))
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }

            if let count = item.characterCount {
                Text(String(format: NSLocalizedString("ios.newText.charCount", comment: ""), count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Helpers

    private func formattedDataSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - UIImage rotation

extension UIImage {
    func rotated(by radians: CGFloat) -> UIImage? {
        let newRect = CGRect(origin: .zero, size: size)
            .applying(CGAffineTransform(rotationAngle: radians))
        let newSize = CGSize(width: abs(newRect.width), height: abs(newRect.height))

        UIGraphicsBeginImageContextWithOptions(newSize, false, scale)
        defer { UIGraphicsEndImageContext() }
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }

        ctx.translateBy(x: newSize.width / 2, y: newSize.height / 2)
        ctx.rotate(by: radians)
        draw(in: CGRect(x: -size.width / 2, y: -size.height / 2,
                        width: size.width, height: size.height))

        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
