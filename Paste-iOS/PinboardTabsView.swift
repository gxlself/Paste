//
//  PinboardTabsView.swift
//  Paste-iOS
//

import SwiftUI

struct PinboardTabsView: View {

    @Binding var selectedPageIndex: Int
    @ObservedObject var settings: iOSAppSettings
    var onClearType: ((ClipboardItemType?) -> Void)?
    var onRenameType: ((ClipboardItemType?) -> Void)?
    var onAddPinboard: (() -> Void)?
    var onRenamePinboard: ((Int) -> Void)?
    var onRemovePinboard: ((Int) -> Void)?

    static let filterCount = 4

    private let filters: [(defaultLabel: String, icon: String, type: ClipboardItemType?)] = [
        ("mainpanel.filter.all", "square.grid.2x2", nil),
        ("mainpanel.filter.text", "doc.text", .text),
        ("mainpanel.filter.image", "photo", .image),
        ("mainpanel.filter.file", "folder", .file),
    ]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(0..<filters.count, id: \.self) { i in
                        let f = filters[i]
                        let isActive = selectedPageIndex == i
                        let label = settings.filterTabName(for: f.type)
                            ?? String(localized: String.LocalizationValue(f.defaultLabel))
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedPageIndex = i
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: f.icon)
                                    .font(.system(size: 12, weight: .medium))
                                Text(label)
                                    .font(.subheadline.weight(isActive ? .semibold : .regular))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(isActive ? Color(UIColor.label).opacity(0.08) : Color.clear)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(isActive ? Color(UIColor.label) : Color.secondary)
                        .contextMenu {
                            Button { onRenameType?(f.type) } label: {
                                Label(String(localized: "ios.pinboard.manager.rename"), systemImage: "pencil")
                            }
                            Divider()
                            Button(role: .destructive) { onClearType?(f.type) } label: {
                                Label(String(localized: "ios.pinboard.clearType"), systemImage: "trash")
                            }
                        }
                        .id(i)
                    }

                    if settings.pinboardCount > 0 {
                        Divider()
                            .frame(height: 20)
                            .padding(.horizontal, 4)
                    }

                    ForEach(0..<settings.pinboardCount, id: \.self) { index in
                        let pageIndex = Self.filterCount + index
                        let isActive = selectedPageIndex == pageIndex
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedPageIndex = pageIndex
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color(hex: settings.pinboardColorHex(at: index)))
                                    .frame(width: 8, height: 8)
                                Text(settings.pinboardName(at: index))
                                    .font(.subheadline.weight(isActive ? .semibold : .regular))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(isActive ? Color(hex: settings.pinboardColorHex(at: index)).opacity(0.15) : Color.clear)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(isActive ? Color(hex: settings.pinboardColorHex(at: index)) : Color.secondary)
                        .contextMenu {
                            Button { onRenamePinboard?(index) } label: {
                                Label(String(localized: "ios.pinboard.manager.rename"), systemImage: "pencil")
                            }
                            Divider()
                            if settings.pinboardCount > 1 {
                                Button(role: .destructive) { onRemovePinboard?(index) } label: {
                                    Label(String(localized: "ios.card.delete"), systemImage: "trash")
                                }
                            }
                        }
                        .id(pageIndex)
                    }

                    if settings.pinboardCount < iOSAppSettings.pinboardCountMax {
                        Button {
                            onAddPinboard?()
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Color(UIColor.label).opacity(0.05))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
            }
            .onChange(of: selectedPageIndex) { newValue in
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Color hex extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
        default:
            r = 0; g = 0; b = 0
        }
        self.init(red: r, green: g, blue: b)
    }
}
