//
//  ContentView.swift
//  Paste-iOS
//
//
//  Copyright © 2026 Gxlself. All rights reserved.
//

import SwiftUI

struct ContentView: View {

    @StateObject private var viewModel = iOSClipboardViewModel()
    @State private var editingItem: SharedClipboardItem?
    @State private var previewingItem: SharedClipboardItem?
    @State private var renamingCategoryType: ClipboardItemType?
    @State private var showRenameCategoryAlert = false
    @State private var renameCategoryText = ""
    @State private var renamingItem: SharedClipboardItem?
    @State private var showRenameItemAlert = false
    @State private var renameItemText = ""
    @State private var sharingItem: SharedClipboardItem?
    @State private var showNewTextSheet = false
    @State private var showScanner = false
    @State private var showPinboardManager = false
    @State private var showSettings = false
    @State private var selectedPageIndex: Int = 0
    @FocusState private var isSearchFieldFocused: Bool

    private static let filterOrder: [ClipboardItemType?] = [nil, .text, .image, .file]

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            PinboardTabsView(
                selectedFilter: filterBinding,
                selectedCustomTypeId: $viewModel.selectedCustomTypeId,
                settings: viewModel.settings,
                onClearType: { type in viewModel.clearItems(ofType: type) },
                onRenameType: { type in beginRenameCategory(type) },
                onDeleteCustomType: { id in viewModel.removeCustomType(id: id) },
                onRenameCustomType: { id, name in viewModel.settings.renameCustomType(id: id, name: name) }
            )
            Divider()

            ZStack(alignment: .top) {
                TabView(selection: $selectedPageIndex) {
                    ForEach(0..<Self.filterOrder.count, id: \.self) { idx in
                        pageContent(for: idx)
                            .tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                if viewModel.copiedItemID != nil {
                    CopiedToastView()
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 16)
                        .zIndex(10)
                }

                if viewModel.isMultiSelectMode {
                    VStack {
                        Spacer()
                        multiSelectBar
                            .transition(.move(edge: .bottom))
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.isMultiSelectMode)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: viewModel.copiedItemID)
        .onChange(of: selectedPageIndex) { newValue in
            viewModel.selectedFilter = Self.filterOrder[newValue]
        }
        .onChange(of: viewModel.selectedFilter) { newValue in
            if let idx = Self.filterOrder.firstIndex(where: { $0 == newValue }),
               idx != selectedPageIndex {
                selectedPageIndex = idx
            }
        }
        .sheet(item: $editingItem) { item in
            EditItemSheet(
                item: item,
                onSave: { newText in
                    viewModel.updateItemText(item, newText: newText)
                },
                onSaveRich: { plainText, rtfData in
                    viewModel.updateItem(item, plainText: plainText, rtfData: rtfData)
                }
            )
        }
        .sheet(isPresented: $showNewTextSheet) {
            NewTextItemSheet { text in
                viewModel.createTextItem(text: text)
            }
        }
        .fullScreenCover(isPresented: $showScanner) {
            DocumentScannerView { text in
                viewModel.addScannedText(text)
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showPinboardManager) {
            PinboardManagerSheet(
                settings: viewModel.settings,
                onClearType: { type in viewModel.clearItems(ofType: type) }
            )
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(settings: viewModel.settings)
        }
        .sheet(item: $previewingItem) { item in
            PreviewSheet(
                item: item,
                onCopy: { viewModel.copyToClipboard($0) },
                onPinToCategory: { item, idx in
                    viewModel.pinItemToBoard(item, index: idx)
                },
                onShare: { sharingItem = $0; previewingItem = nil },
                onDelete: { viewModel.deleteItem($0) },
                onUpdateImage: { item, data in
                    viewModel.updateImageData(item, newData: data)
                },
                settings: viewModel.settings
            )
        }
        .alert(String(localized: "ios.pinboard.manager.rename"), isPresented: $showRenameCategoryAlert) {
            TextField(String(localized: "ios.pinboard.manager.rename.name"), text: $renameCategoryText)
            Button(String(localized: "mainpanel.edit.cancel"), role: .cancel) {
                renamingCategoryType = nil
            }
            Button(String(localized: "mainpanel.edit.ok")) {
                if let type = renamingCategoryType {
                    viewModel.settings.setFilterTabName(renameCategoryText, for: type)
                } else if showRenameCategoryAlert {
                    viewModel.settings.setFilterTabName(renameCategoryText, for: nil)
                }
                renamingCategoryType = nil
            }
        }
        .alert(String(localized: "ios.card.rename"), isPresented: $showRenameItemAlert) {
            TextField(String(localized: "ios.rename.placeholder"), text: $renameItemText)
            Button(String(localized: "mainpanel.edit.cancel"), role: .cancel) {
                renamingItem = nil
            }
            Button(String(localized: "mainpanel.edit.ok")) {
                if let item = renamingItem {
                    viewModel.renameItem(item, newName: renameItemText)
                }
                renamingItem = nil
            }
        }
        .sheet(item: $sharingItem) { item in
            ActivityView(activityItems: shareContent(for: item))
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .ignoresSafeArea(.container, edges: .bottom)
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }

    // MARK: - Filter binding (syncs tab bar with page)

    private var filterBinding: Binding<ClipboardItemType?> {
        Binding(
            get: { Self.filterOrder[selectedPageIndex] },
            set: { newVal in
                if let idx = Self.filterOrder.firstIndex(where: { $0 == newVal }) {
                    withAnimation { selectedPageIndex = idx }
                }
            }
        )
    }

    // MARK: - Page content for each filter

    private func pageContent(for index: Int) -> some View {
        let filter = Self.filterOrder[index]
        let pageItems = viewModel.items(for: filter)

        return ClipboardGridView(
            items: pageItems,
            copiedItemID: viewModel.copiedItemID,
            isMultiSelectMode: viewModel.isMultiSelectMode,
            selectedItemIDs: viewModel.selectedItemIDs,
            settings: viewModel.settings,
            pinboardIndexForItem: { viewModel.pinboardIndex(for: $0) },
            onTap: { handleTap($0) },
            onDelete: { viewModel.deleteItem($0) },
            onEdit: { editingItem = $0 },
            onTogglePin: { viewModel.togglePin($0) },
            onPreview: { previewingItem = $0 },
            onCopyPlainText: { copyPlainText($0) },
            onRename: { item in
                renamingItem = item
                renameItemText = item.alias ?? ""
                showRenameItemAlert = true
            },
            onShare: { sharingItem = $0 },
            onStartMultiSelect: { withAnimation { viewModel.isMultiSelectMode = true } }
        )
    }

    // MARK: - Category rename

    private func beginRenameCategory(_ type: ClipboardItemType?) {
        renamingCategoryType = type
        let defaultLabels: [ClipboardItemType?: String] = [
            nil: "mainpanel.filter.all",
            .text: "mainpanel.filter.text",
            .image: "mainpanel.filter.image",
            .file: "mainpanel.filter.file"
        ]
        renameCategoryText = viewModel.settings.filterTabName(for: type)
            ?? String(localized: String.LocalizationValue(defaultLabels[type] ?? "mainpanel.filter.all"))
        showRenameCategoryAlert = true
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 16) {
            if viewModel.isSearchActive {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField(String(localized: "mainpanel.search.placeholder"), text: $viewModel.searchText)
                        .textFieldStyle(.plain)
                        .focused($isSearchFieldFocused)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .submitLabel(.search)
                    if !viewModel.searchText.isEmpty {
                        Button {
                            viewModel.searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Button {
                        viewModel.searchText = ""
                        isSearchFieldFocused = false
                        withAnimation { viewModel.isSearchActive = false }
                    } label: {
                        Text("mainpanel.edit.cancel")
                            .font(.subheadline)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
                .onAppear { isSearchFieldFocused = true }
            } else {
                Button {
                    withAnimation { viewModel.isSearchActive = true }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.title3)
                        .foregroundStyle(Color(UIColor.label))
                }

                Spacer()

                if viewModel.isMultiSelectMode {
                    Button(String(localized: "ios.topbar.done")) {
                        viewModel.exitMultiSelect()
                    }
                    .fontWeight(.semibold)
                } else {
                    moreMenu
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - More menu ("...")

    private var moreMenu: some View {
        Menu {
            Button {
                showNewTextSheet = true
            } label: {
                Label(String(localized: "ios.menu.newTextItem"), systemImage: "plus.square")
            }

            Button {
                showScanner = true
            } label: {
                Label(String(localized: "ios.menu.scanDocument"), systemImage: "doc.viewfinder")
            }

            Button {
                withAnimation { viewModel.isMultiSelectMode = true }
            } label: {
                Label(String(localized: "ios.menu.select"), systemImage: "checkmark.circle")
            }

            Divider()

            Button {
                showPinboardManager = true
            } label: {
                Label(String(localized: "ios.menu.pinboards"), systemImage: "rectangle.stack")
            }

            Button {
                showSettings = true
            } label: {
                Label(String(localized: "menu.action.settings"), systemImage: "gearshape")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.title3)
                .foregroundStyle(Color(UIColor.label))
                .frame(width: 32, height: 32)
        }
    }

    // MARK: - Multi-select bar

    private var multiSelectBar: some View {
        HStack(spacing: 20) {
            Button {
                viewModel.mergeSelectedItems()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "doc.on.clipboard")
                    Text("ios.multiselect.mergeCopy")
                        .font(.caption2)
                }
            }
            .disabled(viewModel.selectedItemIDs.isEmpty)

            Button(role: .destructive) {
                viewModel.deleteSelectedItems()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "trash")
                    Text("ios.multiselect.delete")
                        .font(.caption2)
                }
            }
            .disabled(viewModel.selectedItemIDs.isEmpty)

            Spacer()

            Text(String(format: NSLocalizedString("ios.multiselect.countFormat", comment: ""), viewModel.selectedItemIDs.count))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }

    // MARK: - Helpers

    private func handleTap(_ item: SharedClipboardItem) {
        if viewModel.isMultiSelectMode {
            viewModel.toggleSelection(item)
        } else {
            viewModel.copyToClipboard(item)
        }
    }

    private func copyPlainText(_ item: SharedClipboardItem) {
        UIPasteboard.general.string = item.plainText ?? item.displayText
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func shareContent(for item: SharedClipboardItem) -> [Any] {
        switch item.itemType {
        case .text:
            return [item.plainText ?? ""]
        case .image:
            let data = item.imageData ?? SharedThumbnailCache.loadImageData(for: item.id)
            if let data, let img = UIImage(data: data) {
                return [img]
            }
            return [item.displayText]
        case .file:
            return [item.displayText]
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "pasteg" else { return }
        guard let idString = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "id" })?.value,
              let id = UUID(uuidString: idString),
              let item = viewModel.itemByID(id) else { return }

        switch url.host {
        case "preview":
            previewingItem = item
        case "edit":
            editingItem = item
        default:
            break
        }
    }
}

// MARK: - UIActivityViewController wrapper

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
