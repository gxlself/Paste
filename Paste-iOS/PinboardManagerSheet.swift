//
//  PinboardManagerSheet.swift
//  Paste-iOS
//

import SwiftUI

struct PinboardManagerSheet: View {

    @ObservedObject var settings: iOSAppSettings
    let onClearType: (ClipboardItemType?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showRenameAlert = false
    @State private var editingTypeIndex: Int = -1
    @State private var editingName = ""
    @State private var showRenamePinboardAlert = false
    @State private var editingPinboardIndex: Int = -1
    @State private var editingPinboardName = ""
    @State private var draggingPinboardIndex: Int?

    private let categories: [(type: ClipboardItemType?, icon: String, defaultLabel: String)] = [
        (nil, "square.grid.2x2", "mainpanel.filter.all"),
        (.text, "doc.text", "mainpanel.filter.text"),
        (.image, "photo", "mainpanel.filter.image"),
        (.file, "folder", "mainpanel.filter.file"),
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(0..<categories.count, id: \.self) { i in
                        let cat = categories[i]
                        categoryRow(index: i, type: cat.type, icon: cat.icon, defaultLabel: cat.defaultLabel)
                    }
                } header: {
                    Text("ios.pinboard.manager.title")
                }

                Section {
                    ForEach(0..<settings.pinboardCount, id: \.self) { idx in
                        pinboardRow(index: idx)
                    }
                    .onMove { source, destination in
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            movePinboards(from: source, to: destination)
                        }
                    }

                    if settings.pinboardCount < iOSAppSettings.pinboardCountMax {
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                settings.addPinboard()
                            }
                        } label: {
                            Label(String(localized: "ios.pinboard.manager.add"), systemImage: "plus.circle.fill")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                } header: {
                    Text("Pinboards")
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle(Text("ios.pinboard.manager.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "ios.pinboard.manager.done")) { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .alert(String(localized: "ios.pinboard.manager.rename"), isPresented: $showRenameAlert) {
                TextField(String(localized: "ios.pinboard.manager.rename.name"), text: $editingName)
                Button(String(localized: "ios.pinboard.manager.rename.cancel"), role: .cancel) {
                    editingTypeIndex = -1
                }
                Button(String(localized: "ios.pinboard.manager.rename.confirm")) {
                    if editingTypeIndex >= 0 && editingTypeIndex < categories.count {
                        settings.setFilterTabName(editingName, for: categories[editingTypeIndex].type)
                    }
                    editingTypeIndex = -1
                }
            }
            .alert(String(localized: "ios.pinboard.manager.rename"), isPresented: $showRenamePinboardAlert) {
                TextField(String(localized: "ios.pinboard.manager.rename.name"), text: $editingPinboardName)
                Button(String(localized: "ios.pinboard.manager.rename.cancel"), role: .cancel) {
                    editingPinboardIndex = -1
                }
                Button(String(localized: "ios.pinboard.manager.rename.confirm")) {
                    if editingPinboardIndex >= 0 {
                        settings.setPinboardName(editingPinboardName, at: editingPinboardIndex)
                    }
                    editingPinboardIndex = -1
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Category Row

    private func categoryRow(index: Int, type: ClipboardItemType?, icon: String, defaultLabel: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)

            Text(settings.filterTabName(for: type)
                 ?? String(localized: String.LocalizationValue(defaultLabel)))
                .font(.body)

            Spacer()

            Button {
                editingName = settings.filterTabName(for: type)
                    ?? String(localized: String.LocalizationValue(defaultLabel))
                editingTypeIndex = index
                showRenameAlert = true
            } label: {
                Image(systemName: "pencil")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
        .moveDisabled(true)
        .deleteDisabled(true)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                onClearType(type)
            } label: {
                Label(String(localized: "ios.pinboard.clearType"), systemImage: "trash")
            }
        }
    }

    // MARK: - Pinboard Row

    private func pinboardRow(index: Int) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: settings.pinboardColorHex(at: index)))
                .frame(width: 12, height: 12)

            Text(settings.pinboardName(at: index))
                .font(.body)
                .lineLimit(1)

            Spacer()

            Button {
                editingPinboardName = settings.pinboardName(at: index)
                editingPinboardIndex = index
                showRenamePinboardAlert = true
            } label: {
                Image(systemName: "pencil")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing) {
            if settings.pinboardCount > 1 {
                Button(role: .destructive) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        settings.removePinboard(at: index)
                    }
                } label: {
                    Label(String(localized: "ios.pinboard.clearType"), systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Move

    private func movePinboards(from source: IndexSet, to destination: Int) {
        guard let sourceIndex = source.first else { return }
        let effectiveDest = sourceIndex < destination ? destination - 1 : destination
        guard sourceIndex != effectiveDest else { return }
        settings.movePinboard(from: sourceIndex, to: effectiveDest)
    }
}
