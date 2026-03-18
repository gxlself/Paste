//
//  ClipboardCardView.swift
//  Paste-iOS
//

import SwiftUI
import LinkPresentation

struct ClipboardCardView: View {

    let item: SharedClipboardItem
    let isCopied: Bool
    let isMultiSelectMode: Bool
    let isSelected: Bool
    let pinboardIndex: Int?
    let settings: iOSAppSettings

    private let cornerRadius: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            content
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .aspectRatio(1, contentMode: .fit)
        .clipped()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(selectionOverlay)
        .overlay(copiedOverlay)
        .scaleEffect(isCopied ? 0.97 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isCopied)
    }

    // MARK: - Header: type + alias + time + pinboard dot + sync icon

    private var header: some View {
        HStack(spacing: 5) {
            if let alias = item.alias {
                Text(alias)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(UIColor.label))
                    .lineLimit(1)
            } else {
                Text(typeLabel)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Text(item.formattedTime)
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer(minLength: 4)

            if let pbIdx = pinboardIndex {
                Circle()
                    .fill(Color(hex: settings.pinboardColorHex(at: pbIdx)))
                    .frame(width: 8, height: 8)
            }

            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.orange)
            }

            sourceAppBadge
        }
    }

    @ViewBuilder
    private var sourceAppBadge: some View {
        if let icon = item.sourceAppIcon {
            Image(uiImage: icon)
                .resizable()
                .frame(width: 14, height: 14)
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        }
    }

    /// Infers an SF Symbol from the app display name (not the bundle ID), works for any source app.
    static func sfSymbol(forAppName name: String) -> String {
        let n = name.lowercased()
        // Browsers.
        if n.contains("safari") { return "safari" }
        if ["chrome", "firefox", "brave", "opera", "arc", "edge", "vivaldi"]
            .contains(where: n.contains) { return "globe" }
        // Mail clients.
        if ["mail", "outlook", "spark", "airmail", "postbox"]
            .contains(where: n.contains) { return "envelope" }
        // Messaging apps.
        if ["messages", "wechat", "微信"].contains(where: n.contains) { return "bubble.left.and.bubble.right" }
        if ["telegram"].contains(where: n.contains) { return "paperplane" }
        if ["slack", "discord"].contains(where: n.contains) { return "number" }
        if ["qq"].contains(where: n.contains) { return "person.2" }
        if ["skype", "zoom", "facetime"].contains(where: n.contains) { return "video" }
        // Notes / document apps.
        if ["notes", "备忘录"].contains(where: n.contains) { return "note.text" }
        if ["notion", "obsidian", "bear"].contains(where: n.contains) { return "doc.plaintext" }
        if ["word", "textedit", "pages"].contains(where: n.contains) { return "doc.text" }
        if ["excel", "numbers"].contains(where: n.contains) { return "tablecells" }
        if ["powerpoint", "keynote"].contains(where: n.contains) { return "rectangle.on.rectangle" }
        // Developer tools.
        if ["xcode"].contains(where: n.contains) { return "hammer" }
        if ["terminal", "ghostty", "wezterm", "iterm", "alacritty", "kitty"]
            .contains(where: n.contains) { return "terminal" }
        if ["code", "cursor", "sublime", "intellij", "webstorm", "pycharm", "android studio"]
            .contains(where: n.contains) { return "chevron.left.forwardslash.chevron.right" }
        // Media apps.
        if ["photos", "照片"].contains(where: n.contains) { return "photo" }
        if ["preview", "预览"].contains(where: n.contains) { return "eye" }
        if ["figma", "sketch"].contains(where: n.contains) { return "paintbrush" }
        if ["spotify", "music", "音乐"].contains(where: n.contains) { return "music.note" }
        // System apps.
        if ["finder", "访达", "files", "文件"].contains(where: n.contains) { return "folder" }
        if ["reminders", "提醒事项"].contains(where: n.contains) { return "checklist" }
        if ["maps", "地图"].contains(where: n.contains) { return "map" }
        if ["settings", "preferences", "设置", "偏好设置", "系统设置"]
            .contains(where: n.contains) { return "gearshape" }
        if ["calculator", "计算器"].contains(where: n.contains) { return "equal" }
        return "app"
    }

    private var typeLabel: String {
        switch item.itemType {
        case .text:  return String(localized: "clipboard.type.text")
        case .image: return String(localized: "clipboard.type.image")
        case .file:  return String(localized: "clipboard.type.file")
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch item.itemType {
        case .text:
            if let url = item.detectedURL {
                linkPreview(url: url)
            } else {
                Text(item.plainText ?? "")
                    .font(.subheadline)
                    .foregroundStyle(Color(UIColor.label))
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
            }

        case .image:
            if let img = SharedThumbnailCache.shared.thumbnail(for: item.id) {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: 80)
                    .contentShape(Rectangle())
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.gray.opacity(0.08))
                    .frame(height: 60)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundStyle(.tertiary)
                    )
            }

        case .file:
            Label(item.displayText, systemImage: "doc")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    // MARK: - Link preview

    private func linkPreview(url: URL) -> some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)

            LinkFaviconView(url: url)
                .frame(width: 40, height: 40)

            Text(url.host ?? url.absoluteString)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 0)

            LinkTitleView(url: url)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color(UIColor.label))
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Overlays

    @ViewBuilder
    private var selectionOverlay: some View {
        if isMultiSelectMode {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                .overlay(alignment: .topTrailing) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isSelected ? Color.accentColor : Color.gray.opacity(0.3))
                        .padding(8)
                }
        }
    }

    @ViewBuilder
    private var copiedOverlay: some View {
        if isCopied && !isMultiSelectMode {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                )
                .transition(.opacity)
        }
    }
}

// MARK: - Link Favicon View (async favicon fetch)

private struct LinkFaviconView: View {
    let url: URL
    @State private var favicon: UIImage?
    @State private var didLoad = false

    var body: some View {
        Group {
            if let favicon {
                Image(uiImage: favicon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentColor.opacity(0.12))
                    .overlay(
                        Image(systemName: "link")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Color.accentColor)
                    )
            }
        }
        .task(id: url) {
            guard !didLoad else { return }
            didLoad = true

            if let cached = LinkPreviewCache.shared.get(url) {
                self.favicon = cached.favicon
                return
            }

            if let host = url.host {
                let faviconURL = URL(string: "https://www.google.com/s2/favicons?sz=128&domain=\(host)")!
                if let (data, _) = try? await URLSession.shared.data(from: faviconURL),
                   let img = UIImage(data: data) {
                    self.favicon = img
                    LinkPreviewCache.shared.update(url, favicon: img)
                    return
                }
            }

            let provider = LPMetadataProvider()
            provider.shouldFetchSubresources = false
            if let metadata = try? await provider.startFetchingMetadata(for: url),
               let iconProvider = metadata.iconProvider {
                let data: Data? = try? await withCheckedThrowingContinuation { continuation in
                    iconProvider.loadDataRepresentation(forTypeIdentifier: "public.image") { data, error in
                        if let data {
                            continuation.resume(returning: data)
                        } else {
                            continuation.resume(throwing: error ?? NSError(domain: "Favicon", code: -1))
                        }
                    }
                }
                if let data, let img = UIImage(data: data) {
                    self.favicon = img
                    LinkPreviewCache.shared.update(url, favicon: img)
                }
            }
        }
    }
}

// MARK: - Link Title View (async title fetch)

private struct LinkTitleView: View {
    let url: URL
    @State private var title: String?
    @State private var didLoad = false

    var body: some View {
        Group {
            if let title, !title.isEmpty {
                Text(title)
            } else {
                Text(url.host ?? url.absoluteString)
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: url) {
            guard !didLoad else { return }
            didLoad = true

            if let cached = LinkPreviewCache.shared.get(url), cached.title != nil {
                self.title = cached.title
                return
            }

            let provider = LPMetadataProvider()
            provider.shouldFetchSubresources = false
            if let metadata = try? await provider.startFetchingMetadata(for: url) {
                self.title = metadata.title
                LinkPreviewCache.shared.update(url, title: metadata.title)
            }
        }
    }
}

// MARK: - Link preview cache (NSCache-based, auto-eviction)

private final class LinkPreviewCache {
    static let shared = LinkPreviewCache()

    private let cache = NSCache<NSURL, CacheEntry>()

    init() {
        cache.countLimit = 100
        cache.totalCostLimit = 10_000_000 // 10 MB
    }

    final class CacheEntry {
        var title: String?
        var favicon: UIImage?
    }

    func get(_ url: URL) -> CacheEntry? {
        cache.object(forKey: url as NSURL)
    }

    func update(_ url: URL, title: String? = nil, favicon: UIImage? = nil) {
        let key = url as NSURL
        let entry = cache.object(forKey: key) ?? CacheEntry()
        if let title { entry.title = title }
        if let favicon { entry.favicon = favicon }
        cache.setObject(entry, forKey: key)
    }
}
