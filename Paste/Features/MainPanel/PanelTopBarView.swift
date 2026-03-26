//
//  PanelTopBarView.swift
//  Paste
//
//  Top bar views for the clipboard panel — horizontal layout (top/bottom) and vertical layout (left/right).
//

import SwiftUI
import AppKit

// MARK: - PanelTopBarView (horizontal, for top/bottom panels)

struct PanelTopBarView: View {
    @ObservedObject var viewModel: ClipboardViewModel
    @FocusState private var searchFieldFocused: Bool

    var body: some View {
        HStack(spacing: 16) {
            if viewModel.panelMode == .pasteStack {
                HStack(spacing: 6) {
                    Text("mainpanel.pasteStack.title")
                        .font(.system(size: 11, weight: .semibold))
                    Button {
                        viewModel.exitPasteStack()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("accessibility.mainpanel.pasteStackExit"))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            if let idx = viewModel.activePinboardIndex {
                HStack(spacing: 6) {
                    Text(String(format: String(localized: "mainpanel.pinboard.titleFormat"), idx + 1))
                        .font(.system(size: 11, weight: .semibold))
                    Button {
                        viewModel.exitPinboard()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("accessibility.mainpanel.pinboardExit"))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            // Paste-target app indicator.
            if !viewModel.pasteTargetAppName.isEmpty {
                HStack(spacing: 4) {
                    if let icon = viewModel.pasteTargetAppIcon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 14, height: 14)
                    }
                    Text(String(format: String(localized: "mainpanel.pasteTarget.format"), viewModel.pasteTargetAppName))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .accessibilityLabel(String(format: String(localized: "accessibility.mainpanel.pasteTarget"), viewModel.pasteTargetAppName))
            }

            // Search field.
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))

                TextField("mainpanel.search.placeholder", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($searchFieldFocused)
                    .onChange(of: searchFieldFocused) { _, new in viewModel.focusSearch = new }
                    .onChange(of: viewModel.focusSearch) { _, new in if searchFieldFocused != new { searchFieldFocused = new } }
                    .accessibilityLabel(Text("accessibility.mainpanel.search"))
                    .accessibilityHint(Text("accessibility.mainpanel.search.hint"))

                if !viewModel.searchText.isEmpty {
                    Button(action: { viewModel.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("accessibility.mainpanel.clearAll"))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .frame(width: 200)

            Spacer()

            // Type filter buttons.
            HStack(spacing: 8) {
                FilterButton(title: "mainpanel.filter.all", titleKeyForAccessibility: "mainpanel.filter.all", icon: "square.grid.2x2", isSelected: viewModel.selectedType == nil && !viewModel.isRegexPresetMode && viewModel.activePinboardIndex == nil, customTitle: AppSettings.filterTabName(for: nil)) {
                    viewModel.selectedType = nil
                    viewModel.isRegexPresetMode = false
                    viewModel.exitPinboard()
                }
                FilterButton(title: "mainpanel.filter.text", titleKeyForAccessibility: "mainpanel.filter.text", icon: "doc.text", isSelected: viewModel.selectedType == .text, customTitle: AppSettings.filterTabName(for: .text)) {
                    viewModel.selectedType = .text
                    viewModel.exitPinboard()
                }
                FilterButton(title: "mainpanel.filter.image", titleKeyForAccessibility: "mainpanel.filter.image", icon: "photo", isSelected: viewModel.selectedType == .image, customTitle: AppSettings.filterTabName(for: .image)) {
                    viewModel.selectedType = .image
                    viewModel.exitPinboard()
                }
                FilterButton(title: "mainpanel.filter.file", titleKeyForAccessibility: "mainpanel.filter.file", icon: "folder", isSelected: viewModel.selectedType == .file, customTitle: AppSettings.filterTabName(for: .file)) {
                    viewModel.selectedType = .file
                    viewModel.exitPinboard()
                }
                FilterButton(title: "mainpanel.filter.regex", titleKeyForAccessibility: "mainpanel.filter.regex", icon: "curlybraces", isSelected: viewModel.isRegexPresetMode) {
                    viewModel.isRegexPresetMode = true
                    viewModel.exitPinboard()
                }

                ForEach(0..<AppSettings.pinboardCount, id: \.self) { index in
                    FilterButton(
                        title: LocalizedStringKey(AppSettings.pinboardName(at: index)),
                        titleKeyForAccessibility: AppSettings.pinboardName(at: index),
                        icon: "pin",
                        isSelected: viewModel.activePinboardIndex == index
                    ) {
                        viewModel.selectedType = nil
                        viewModel.isRegexPresetMode = false
                        viewModel.showPinboard(index: index)
                    }
                }

                if AppSettings.pinboardCount < AppSettings.pinboardCountMax {
                    Button {
                        viewModel.createNewPinboard()
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Add pinboard")
                }

                // Fixed "About" tab — always last, never removable.
                AboutFilterButton(isSelected: viewModel.isAboutMode) {
                    viewModel.isAboutMode = true
                }
            }

            Spacer()

            // Item count (hidden in About mode).
            if !viewModel.isAboutMode {
                Text(String(format: String(localized: "mainpanel.itemCountFormat"), viewModel.effectiveDisplayItems.count))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            // Clear button (hidden in About mode).
            if !viewModel.isAboutMode {
                Button(action: { viewModel.clearAll() }) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help(String(localized: "mainpanel.clearAll.help"))
                .accessibilityLabel(Text("accessibility.mainpanel.clearAll"))
                .accessibilityHint(Text("accessibility.mainpanel.clearAll.hint"))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
}

// MARK: - PanelTopBarVerticalView (for left/right panels, 2-row compact layout)

struct PanelTopBarVerticalView: View {
    @ObservedObject var viewModel: ClipboardViewModel
    @FocusState private var searchFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Row 1: search field + status indicators.
            HStack(spacing: 8) {
                // Mode badge (pasteStack / pinboard).
                if viewModel.panelMode == .pasteStack {
                    HStack(spacing: 4) {
                        Text("mainpanel.pasteStack.title")
                            .font(.system(size: 10, weight: .semibold))
                        Button {
                            viewModel.exitPasteStack()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("accessibility.mainpanel.pasteStackExit"))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                }

                if let idx = viewModel.activePinboardIndex {
                    HStack(spacing: 4) {
                        Text(String(format: String(localized: "mainpanel.pinboard.titleFormat"), idx + 1))
                            .font(.system(size: 10, weight: .semibold))
                        Button {
                            viewModel.exitPinboard()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("accessibility.mainpanel.pinboardExit"))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                }

                // Search field.
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 11))
                    TextField("mainpanel.search.placeholder", text: $viewModel.searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .focused($searchFieldFocused)
                        .onChange(of: searchFieldFocused) { _, new in viewModel.focusSearch = new }
                        .onChange(of: viewModel.focusSearch) { _, new in if searchFieldFocused != new { searchFieldFocused = new } }
                        .accessibilityLabel(Text("accessibility.mainpanel.search"))
                    if !viewModel.searchText.isEmpty {
                        Button(action: { viewModel.searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .padding(.horizontal, PanelLayout.panelPadding)
            .padding(.top, 8)
            .padding(.bottom, 4)

            // Row 2: filter buttons + count + clear (scrollable to fit custom types).
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    FilterButton(title: "mainpanel.filter.all", titleKeyForAccessibility: "mainpanel.filter.all", icon: "square.grid.2x2", isSelected: viewModel.selectedType == nil && !viewModel.isRegexPresetMode && viewModel.activePinboardIndex == nil, customTitle: AppSettings.filterTabName(for: nil)) {
                        viewModel.selectedType = nil
                        viewModel.isRegexPresetMode = false
                        viewModel.exitPinboard()
                    }
                    FilterButton(title: "mainpanel.filter.text", titleKeyForAccessibility: "mainpanel.filter.text", icon: "doc.text", isSelected: viewModel.selectedType == .text, customTitle: AppSettings.filterTabName(for: .text)) {
                        viewModel.selectedType = .text
                        viewModel.exitPinboard()
                    }
                    FilterButton(title: "mainpanel.filter.image", titleKeyForAccessibility: "mainpanel.filter.image", icon: "photo", isSelected: viewModel.selectedType == .image, customTitle: AppSettings.filterTabName(for: .image)) {
                        viewModel.selectedType = .image
                        viewModel.exitPinboard()
                    }
                    FilterButton(title: "mainpanel.filter.file", titleKeyForAccessibility: "mainpanel.filter.file", icon: "folder", isSelected: viewModel.selectedType == .file, customTitle: AppSettings.filterTabName(for: .file)) {
                        viewModel.selectedType = .file
                        viewModel.exitPinboard()
                    }
                    FilterButton(title: "mainpanel.filter.regex", titleKeyForAccessibility: "mainpanel.filter.regex", icon: "curlybraces", isSelected: viewModel.isRegexPresetMode) {
                        viewModel.isRegexPresetMode = true
                        viewModel.exitPinboard()
                    }

                    ForEach(0..<AppSettings.pinboardCount, id: \.self) { index in
                        FilterButton(
                            title: LocalizedStringKey(AppSettings.pinboardName(at: index)),
                            titleKeyForAccessibility: AppSettings.pinboardName(at: index),
                            icon: "pin",
                            isSelected: viewModel.activePinboardIndex == index
                        ) {
                            viewModel.selectedType = nil
                            viewModel.isRegexPresetMode = false
                            viewModel.showPinboard(index: index)
                        }
                    }

                    if AppSettings.pinboardCount < AppSettings.pinboardCountMax {
                        Button {
                            viewModel.createNewPinboard()
                        } label: {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    // Fixed "About" tab — always last, never removable.
                    AboutFilterButton(isSelected: viewModel.isAboutMode) {
                        viewModel.isAboutMode = true
                    }

                    Spacer()

                    if !viewModel.isAboutMode {
                        Text(String(format: String(localized: "mainpanel.itemCountFormat"), viewModel.effectiveDisplayItems.count))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }

                    if !viewModel.isAboutMode {
                        Button(action: { viewModel.clearAll() }) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help(String(localized: "mainpanel.clearAll.help"))
                        .accessibilityLabel(Text("accessibility.mainpanel.clearAll"))
                    }
                }
            }
            .padding(.horizontal, PanelLayout.panelPadding)
            .padding(.bottom, 8)
        }
        .frame(height: PanelLayout.topBarHeightV)
    }
}

// MARK: - CustomTypeFilterButton

struct CustomTypeFilterButton: View {
    let customType: CustomType
    let isSelected: Bool
    let onSelect: () -> Void
    let onRename: (String) -> Void
    let onDelete: () -> Void

    @State private var showRenameAlert = false
    @State private var renameText = ""

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 4) {
                Image(systemName: "tag")
                    .font(.system(size: 10))
                Text(customType.name)
                    .font(.system(size: 11))
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 9))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSelected ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
            .foregroundColor(isSelected ? .white : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                renameText = customType.name
                showRenameAlert = true
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            Divider()
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .alert("Rename Type", isPresented: $showRenameAlert) {
            TextField("Name", text: $renameText)
            Button("Rename") { onRename(renameText) }
            Button("Cancel", role: .cancel) { }
        }
    }
}

// MARK: - CustomTypeInputRow

struct CustomTypeInputRow: View {
    @Binding var text: String
    let onConfirm: () -> Void
    let onCancel: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 4) {
            TextField("Type name…", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .frame(width: 90)
                .focused($focused)
                .onSubmit { onConfirm() }
                .onExitCommand { onCancel() }
            Button(action: onConfirm) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onAppear { focused = true }
    }
}

// MARK: - AboutFilterButton

/// Fixed "About" tab — always the last filter, cannot be deleted or renamed.
struct AboutFilterButton: View {
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 10))
                    .foregroundColor(isSelected ? .white : Color(nsColor: .systemPink))
                Text("关于")
                    .font(.system(size: 11))
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 9))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSelected ? Color(nsColor: .systemPink) : Color(nsColor: .controlBackgroundColor))
            .foregroundColor(isSelected ? .white : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .help("关于 · About the developer")
    }
}

// MARK: - FilterButton

struct FilterButton: View {
    let title: LocalizedStringKey
    let titleKeyForAccessibility: String
    let icon: String
    let isSelected: Bool
    var customTitle: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                if let custom = customTitle {
                    Text(custom)
                        .font(.system(size: 11))
                } else {
                    Text(title)
                        .font(.system(size: 11))
                }
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 9))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSelected ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
            .foregroundColor(isSelected ? .white : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: String.LocalizationValue(titleKeyForAccessibility)) + ", " + (isSelected ? String(localized: "accessibility.mainpanel.filter.selected") : String(localized: "accessibility.mainpanel.filter.unselected")))
    }
}
