//
//  PasteLiveActivityManager.swift
//  Paste-iOS
//
//  Keeps a Live Activity (Dynamic Island / Lock Screen) in sync with the most recent clipboard
//  items. Activities can only be started while the app is in the foreground, which is exactly
//  when the clipboard monitor captures new items.
//

import ActivityKit
import UIKit

@MainActor
final class PasteLiveActivityManager {

    static let shared = PasteLiveActivityManager()

    private static let maxEntries = 3
    private static let previewLength = 48

    private var lastState: Any?
    private var lastItems: [SharedClipboardItem] = []
    private init() {}

    // MARK: - Public

    /// Re-applies the latest items after the user changes a Live Activity setting.
    func settingsChanged() {
        lastState = nil
        refresh(with: lastItems)
    }

    func refresh(with items: [SharedClipboardItem]) {
        lastItems = items
        guard #available(iOS 16.1, *) else { return }
        let settings = iOSAppSettings.shared
        guard settings.liveActivityEnabled else {
            end()
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let state = Self.makeState(from: items, hidePreview: settings.liveActivityHidePreview)
        guard !state.entries.isEmpty else {
            end()
            return
        }
        if let previous = lastState as? PasteActivityAttributes.ContentState, previous == state { return }
        lastState = state

        Task { await apply(state) }
    }

    func end() {
        guard #available(iOS 16.1, *) else { return }
        lastState = nil
        Task {
            for activity in Activity<PasteActivityAttributes>.activities {
                if #available(iOS 16.2, *) {
                    await activity.end(nil, dismissalPolicy: .immediate)
                } else {
                    await activity.end(using: nil, dismissalPolicy: .immediate)
                }
            }
        }
    }

    // MARK: - Copy handler (iOS 17 in-place copy from the island)

    /// Installed at launch so a background-launched app can serve the island's copy button.
    nonisolated static func installCopyHandler() {
        LiveActivityBridge.copyHandler = { idString in
            guard let id = UUID(uuidString: idString) else { return }
            Task { @MainActor in
                let repository = ClipboardRepository()
                guard let item = repository.fetchAll().first(where: { $0.id == id }) else { return }
                PasteLiveActivityManager.write(item, to: .general)
                repository.bumpToTop(item)
            }
        }
    }

    static func write(_ item: SharedClipboardItem, to pasteboard: UIPasteboard) {
        switch item.itemType {
        case .text:
            pasteboard.string = item.plainText
        case .image:
            let data = item.imageData ?? SharedThumbnailCache.loadImageData(for: item.id)
            if let data, let image = UIImage(data: data) { pasteboard.image = image }
        case .file:
            pasteboard.string = item.displayText
        }
    }

    // MARK: - Internals

    @available(iOS 16.1, *)
    private static func makeState(from items: [SharedClipboardItem], hidePreview: Bool) -> PasteActivityAttributes.ContentState {
        let recent = items
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(maxEntries)
        let entries = recent.map { item -> PasteActivityAttributes.ContentState.Entry in
            let kind: PasteActivityAttributes.ContentState.Kind
            switch item.itemType {
            case .image: kind = .image
            case .file:  kind = .file
            case .text:
                let text = item.plainText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                kind = text.hasPrefix("http://") || text.hasPrefix("https://") ? .link : .text
            }
            var preview = ""
            if !hidePreview {
                let flat = item.displayText
                    .components(separatedBy: .newlines)
                    .joined(separator: " ")
                    .trimmingCharacters(in: .whitespaces)
                preview = String(flat.prefix(previewLength))
            }
            return .init(id: item.id.uuidString, preview: preview, kind: kind)
        }
        return .init(entries: Array(entries))
    }

    @available(iOS 16.1, *)
    private func apply(_ state: PasteActivityAttributes.ContentState) async {
        if let activity = Activity<PasteActivityAttributes>.activities.first {
            if #available(iOS 16.2, *) {
                await activity.update(ActivityContent(state: state, staleDate: nil))
            } else {
                await activity.update(using: state)
            }
            return
        }
        do {
            let attributes = PasteActivityAttributes(name: "Paste")
            if #available(iOS 16.2, *) {
                _ = try Activity.request(
                    attributes: attributes,
                    content: ActivityContent(state: state, staleDate: nil),
                    pushType: nil
                )
            } else {
                _ = try Activity.request(attributes: attributes, contentState: state, pushType: nil)
            }
        } catch {
            SharedLog.error("Live Activity request failed: \(error)")
        }
    }
}
