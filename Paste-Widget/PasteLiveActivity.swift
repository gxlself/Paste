//
//  PasteLiveActivity.swift
//  Paste-Widget
//
//  Dynamic Island + Lock Screen presentation of the most recent clipboard items.
//

import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

@available(iOS 16.1, *)
struct PasteLiveActivity: Widget {

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PasteActivityAttributes.self) { context in
            LockScreenView(state: context.state)
                .padding(14)
                .activityBackgroundTint(Color(.systemBackground).opacity(0.9))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "doc.on.clipboard.fill")
                        .font(.title3)
                        .foregroundStyle(.tint)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.entries.count)")
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.center) {
                    if let latest = context.state.entries.first {
                        Text(label(for: latest))
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    EntryList(entries: Array(context.state.entries.prefix(3)))
                }
            } compactLeading: {
                Image(systemName: "doc.on.clipboard.fill")
                    .foregroundStyle(.tint)
            } compactTrailing: {
                Image(systemName: context.state.entries.first?.kind.symbol ?? "doc.on.clipboard")
                    .font(.caption)
            } minimal: {
                Image(systemName: "doc.on.clipboard.fill")
                    .foregroundStyle(.tint)
            }
            .keylineTint(.accentColor)
        }
    }
}

@available(iOS 16.1, *)
private func label(for entry: PasteActivityAttributes.ContentState.Entry) -> String {
    if !entry.preview.isEmpty { return entry.preview }
    switch entry.kind {
    case .text:  return "Text"
    case .link:  return "Link"
    case .image: return "Image"
    case .file:  return "File"
    }
}

@available(iOS 16.1, *)
private struct LockScreenView: View {
    let state: PasteActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "doc.on.clipboard.fill").foregroundStyle(.tint)
                Text("Paste").font(.footnote.weight(.semibold))
                Spacer()
            }
            EntryList(entries: state.entries)
        }
    }
}

/// Up to three tappable rows. iOS 17+ copies in place via an App Intent; earlier systems open
/// the app through the `pasteg://copy` deep link, which copies on arrival.
@available(iOS 16.1, *)
private struct EntryList: View {
    let entries: [PasteActivityAttributes.ContentState.Entry]

    var body: some View {
        VStack(spacing: 6) {
            ForEach(entries) { entry in
                if #available(iOS 17.0, *) {
                    Button(intent: CopyClipboardItemIntent(itemID: entry.id)) {
                        EntryRow(entry: entry)
                    }
                    .buttonStyle(.plain)
                } else if let url = URL(string: "pasteg://copy?id=\(entry.id)") {
                    Link(destination: url) { EntryRow(entry: entry) }
                }
            }
        }
    }
}

@available(iOS 16.1, *)
private struct EntryRow: View {
    let entry: PasteActivityAttributes.ContentState.Entry

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: entry.kind.symbol)
                .font(.caption)
                .frame(width: 18)
                .foregroundStyle(.secondary)
            Text(label(for: entry))
                .font(.footnote)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "doc.on.doc")
                .font(.caption)
                .foregroundStyle(.tint)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(Rectangle())
    }
}
