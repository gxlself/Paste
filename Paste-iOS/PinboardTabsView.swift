//
//  PinboardTabsView.swift
//  Paste-iOS
//

import SwiftUI

struct PinboardTabsView: View {

    @Binding var selectedFilter: ClipboardItemType?
    @Binding var selectedCustomTypeId: String?
    @ObservedObject var settings: iOSAppSettings
    var onClearType: ((ClipboardItemType?) -> Void)?
    var onRenameType: ((ClipboardItemType?) -> Void)?
    var onDeleteCustomType: ((String) -> Void)?
    var onRenameCustomType: ((String, String) -> Void)?

    @State private var showCustomTypeRenameAlert = false
    @State private var renamingCustomTypeId: String = ""
    @State private var renameCustomTypeText: String = ""

    private let filters: [(defaultLabel: String, icon: String, type: ClipboardItemType?)] = [
        ("mainpanel.filter.all", "square.grid.2x2", nil),
        ("mainpanel.filter.text", "doc.text", .text),
        ("mainpanel.filter.image", "photo", .image),
        ("mainpanel.filter.file", "folder", .file),
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                // Built-in type tabs.
                ForEach(0..<filters.count, id: \.self) { i in
                    let f = filters[i]
                    let isActive = selectedCustomTypeId == nil && selectedFilter == f.type
                    let label = settings.filterTabName(for: f.type)
                        ?? String(localized: String.LocalizationValue(f.defaultLabel))
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCustomTypeId = nil
                            selectedFilter = f.type
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
                }

                // Custom type tabs.
                ForEach(settings.customTypes) { ct in
                    let isActive = selectedCustomTypeId == ct.id
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCustomTypeId = ct.id
                            selectedFilter = nil
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "tag")
                                .font(.system(size: 12, weight: .medium))
                            Text(ct.name)
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
                        Button {
                            renamingCustomTypeId = ct.id
                            renameCustomTypeText = ct.name
                            showCustomTypeRenameAlert = true
                        } label: {
                            Label(String(localized: "ios.pinboard.manager.rename"), systemImage: "pencil")
                        }
                        Divider()
                        Button(role: .destructive) {
                            onDeleteCustomType?(ct.id)
                        } label: {
                            Label(String(localized: "ios.pinboard.clearType"), systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
        .alert("Rename Type", isPresented: $showCustomTypeRenameAlert) {
            TextField("Name", text: $renameCustomTypeText)
            Button("Rename") { onRenameCustomType?(renamingCustomTypeId, renameCustomTypeText) }
            Button("Cancel", role: .cancel) { }
        }
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
