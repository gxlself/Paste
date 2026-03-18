// KeyboardGridView.swift
// Paste-Keyboard

import SwiftUI

struct KeyboardGridView: View {

    @ObservedObject var viewModel: KeyboardViewModel
    let onInsertText: (String) -> Void
    let onDeleteBackward: () -> Void
    let onReturnKey: () -> Void

    @State private var copiedItemID: UUID?

    private let accentGold = Color(red: 0.83, green: 0.69, blue: 0.22)

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            itemRow
            Divider()
            controlBar
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(UIColor.systemGroupedBackground))
        .onAppear { viewModel.fetchItems() }
    }

    // MARK: - Top bar: search + filter

    private var topBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            TextField(String(localized: "mainpanel.search.placeholder"), text: $viewModel.searchText)
                .font(.subheadline)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.tertiary)
                }
            }

            Divider().frame(height: 20)

            Menu {
                Button {
                    viewModel.activeTypeFilter = nil
                } label: {
                    Label(String(localized: "mainpanel.filter.all"), systemImage: "square.grid.2x2")
                }
                Button {
                    viewModel.activeTypeFilter = .text
                } label: {
                    Label(String(localized: "mainpanel.filter.text"), systemImage: "doc.text")
                }
                Button {
                    viewModel.activeTypeFilter = .image
                } label: {
                    Label(String(localized: "mainpanel.filter.image"), systemImage: "photo")
                }
                Button {
                    viewModel.activeTypeFilter = .file
                } label: {
                    Label(String(localized: "mainpanel.filter.file"), systemImage: "folder")
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: viewModel.filterIcon)
                        .font(.system(size: 12))
                    Text(viewModel.filterLabel)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(Color(UIColor.label))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    // MARK: - Horizontal item scroll

    private var itemRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            if viewModel.filteredItems.isEmpty {
                emptyKeyboardState
            } else {
                LazyHStack(spacing: 8) {
                    ForEach(viewModel.filteredItems) { item in
                        keyboardCard(for: item)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func keyboardCard(for item: SharedClipboardItem) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            switch item.itemType {
            case .text:
                onInsertText(item.plainText ?? "")
            case .image, .file:
                withAnimation(.easeInOut(duration: 0.2)) { copiedItemID = item.id }
                DispatchQueue.main.async { [viewModel] in
                    viewModel.copyToClipboard(item)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        if copiedItemID == item.id { copiedItemID = nil }
                    }
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                cardHeader(item)
                cardContent(item)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(width: 170, height: 140, alignment: .topLeading)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                if copiedItemID == item.id {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            VStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.green)
                                Text(String(localized: "ios.keyboard.copied.hint"))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .transition(.opacity)
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu { cardContextMenu(for: item) }
    }

    private func cardHeader(_ item: SharedClipboardItem) -> some View {
        HStack(spacing: 4) {
            if let icon = item.sourceAppIcon {
                Image(uiImage: icon)
                    .resizable()
                    .frame(width: 12, height: 12)
                    .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
            }
            Text(item.formattedTime)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
            Spacer()
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(accentGold)
            }
        }
    }

    @ViewBuilder
    private func cardContent(_ item: SharedClipboardItem) -> some View {
        switch item.itemType {
        case .text:
            if let url = item.detectedURL {
                linkPreview(url: url)
            } else {
                Text(item.plainText ?? "")
                    .font(.caption)
                    .foregroundStyle(Color(UIColor.label))
                    .lineLimit(5)
                    .multilineTextAlignment(.leading)
            }
        case .image:
            if let img = SharedThumbnailCache.shared.thumbnail(for: item.id) {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxHeight: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.tertiary)
            }
        case .file:
            Label(item.displayText, systemImage: "doc")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
    }

    private func linkPreview(url: URL) -> some View {
        VStack(spacing: 6) {
            Spacer(minLength: 0)
            KeyboardFaviconView(url: url)
                .frame(width: 32, height: 32)
            Text(url.host ?? url.absoluteString)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Card context menu

    @ViewBuilder
    private func cardContextMenu(for item: SharedClipboardItem) -> some View {
        Button {
            let text: String
            switch item.itemType {
            case .text: text = item.plainText ?? ""
            default:    text = item.displayText
            }
            onInsertText(text)
        } label: {
            Label(String(localized: "ios.keyboard.paste"), systemImage: "doc.on.clipboard")
        }

        Button {
            viewModel.copyToClipboard(item)
        } label: {
            Label(String(localized: "ios.card.copy"), systemImage: "doc.on.doc")
        }

        Divider()

        Button {
            viewModel.togglePin(item)
        } label: {
            Label(
                String(localized: item.isPinned ? "ios.card.unpin" : "ios.card.pin"),
                systemImage: item.isPinned ? "pin.slash" : "pin"
            )
        }

        Button {
            viewModel.openInApp(item, action: "preview")
        } label: {
            Label(String(localized: "ios.card.preview"), systemImage: "eye")
        }

        Button {
            viewModel.openInApp(item, action: "edit")
        } label: {
            Label(String(localized: "ios.card.edit"), systemImage: "pencil")
        }

        Divider()

        Button(role: .destructive) {
            viewModel.deleteItem(item)
        } label: {
            Label(String(localized: "ios.card.delete"), systemImage: "trash")
        }
    }

    // MARK: - Empty state

    private var emptyKeyboardState: some View {
        VStack(spacing: 8) {
            Image(systemName: "clipboard")
                .font(.title2)
                .foregroundStyle(.tertiary)
            Text(String(localized: "mainpanel.empty.noHistory"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Control bar: space / delete / send

    private var controlBar: some View {
        HStack(spacing: 0) {
            Button {
                onInsertText(" ")
            } label: {
                Text(String(localized: "ios.keyboard.space"))
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Color(UIColor.label))
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(Color(UIColor.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            RepeatButton(action: onDeleteBackward) {
                Image(systemName: "delete.backward")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color(UIColor.label))
                    .frame(width: 44, height: 36)
                    .background(Color(UIColor.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .padding(.leading, 4)

            Button(action: onReturnKey) {
                Text(String(localized: "ios.keyboard.send"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 36)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .padding(.leading, 4)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemGroupedBackground))
    }
}

// MARK: - KeyboardFaviconView (lightweight async favicon)

private struct KeyboardFaviconView: View {
    let url: URL
    @State private var favicon: UIImage?

    var body: some View {
        Group {
            if let favicon {
                Image(uiImage: favicon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.accentColor.opacity(0.12))
                    .overlay(
                        Image(systemName: "link")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.accentColor)
                    )
            }
        }
        .task(id: url) {
            guard let host = url.host,
                  let faviconURL = URL(string: "https://www.google.com/s2/favicons?sz=64&domain=\(host)"),
                  let (data, _) = try? await URLSession.shared.data(from: faviconURL),
                  let img = UIImage(data: data) else { return }
            favicon = img
        }
    }
}

// MARK: - RepeatButton (fires on tap + repeats on long press)

private struct RepeatButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    @State private var timer: Timer?

    var body: some View {
        label()
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard timer == nil else { return }
                        action()
                        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                            action()
                        }
                    }
                    .onEnded { _ in
                        timer?.invalidate()
                        timer = nil
                    }
            )
    }
}
