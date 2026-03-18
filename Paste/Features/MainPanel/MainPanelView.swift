//
//  MainPanelView.swift
//  Paste
//
//  Main overlay panel view — slides in from the configured edge.
//

import SwiftUI
import AppKit

// MARK: - Card Size Environment Key

private struct CardSizeKey: EnvironmentKey {
    static let defaultValue = CGSize(width: 140, height: PanelLayout.cardHeightH)
}

extension EnvironmentValues {
    var cardSize: CGSize {
        get { self[CardSizeKey.self] }
        set { self[CardSizeKey.self] = newValue }
    }
}

// MARK: - MainPanelView

struct MainPanelView: View {

    @ObservedObject var viewModel: ClipboardViewModel
    @State private var isVisible = false
    @State private var renameSheetText = ""
    @State private var editSheetText = ""
    @State private var newItemSheetText = ""

    var body: some View {
        let position = AppSettings.panelPosition
        GeometryReader { geo in
            let cs = PanelLayout.cardSize(position: position, screenSize: geo.size)
            ZStack {
                panelContent(position: position)
                    .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
                    .offset(x: panelOffsetX(position: position), y: panelOffsetY(position: position))
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isVisible)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: position)
                    .zIndex(0)
            }
            .environment(\.cardSize, cs)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(NotificationCenter.default.publisher(for: AppNotification.panelWillHide)) { _ in
            isVisible = false
        }
        .onReceive(NotificationCenter.default.publisher(for: AppNotification.panelDidShow)) { _ in
            isVisible = true
        }
        .onChange(of: viewModel.showRenameSheet) { _, show in
            if show { renameSheetText = viewModel.itemForEdit?.displayText ?? "" }
        }
        .onChange(of: viewModel.showEditSheet) { _, show in
            if show { editSheetText = viewModel.itemForEdit?.plainText ?? "" }
        }
        .sheet(isPresented: $viewModel.showRenameSheet) {
            RenameSheetView(text: $renameSheetText, viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showEditSheet) {
            EditSheetView(text: $editSheetText, viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showNewItemSheet) {
            NewItemSheetView(text: $newItemSheetText, viewModel: viewModel)
        }
    }

    @ViewBuilder
    private func panelContent(position: AppSettings.PanelPosition) -> some View {
        let isVertical = position == .left || position == .right

        if isVertical {
            // Left/right panel: fills screen height, cards stacked vertically.
            VStack(spacing: 0) {
                PanelTopBarVerticalView(viewModel: viewModel)
                Divider().background(Color(nsColor: .separatorColor))
                if viewModel.isAboutMode {
                    AboutPanelVerticalView()
                } else {
                    ClipboardGridVerticalView(viewModel: viewModel)
                }
            }
            .frame(width: PanelLayout.panelVerticalWidth)
            .frame(maxHeight: .infinity)
        } else {
            // Top/bottom panel: fills screen width, cards arranged horizontally.
            let bar = VStack(spacing: 0) {
                PanelTopBarView(viewModel: viewModel)
                Divider().background(Color(nsColor: .separatorColor))
                if viewModel.isAboutMode {
                    AboutPanelView()
                } else {
                    ClipboardGridView(viewModel: viewModel)
                }
            }
            .frame(height: PanelLayout.panelBarHeight)
            .frame(maxWidth: .infinity)

            switch position {
            case .bottom:
                bar
            case .top:
                VStack(spacing: 0) {
                    bar
                    Spacer(minLength: 0)
                }
            default:
                bar
            }
        }
    }

    private func panelOffsetX(position: AppSettings.PanelPosition) -> CGFloat {
        switch position {
        case .bottom, .top: return 0
        case .left: return isVisible ? 0 : -PanelLayout.panelVerticalWidth
        case .right: return isVisible ? 0 : PanelLayout.panelVerticalWidth
        }
    }

    private func panelOffsetY(position: AppSettings.PanelPosition) -> CGFloat {
        switch position {
        case .bottom: return isVisible ? 0 : PanelLayout.panelBarHeight
        case .top: return isVisible ? 0 : -PanelLayout.panelBarHeight
        case .left, .right: return 0
        }
    }
}

// MARK: - Sheet Views

private struct RenameSheetView: View {
    @Binding var text: String
    @ObservedObject var viewModel: ClipboardViewModel

    var body: some View {
        VStack(spacing: 12) {
            Text("mainpanel.rename.title")
                .font(.headline)
            TextField("", text: $text)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 260)
            HStack {
                Button("mainpanel.edit.cancel") { viewModel.showRenameSheet = false }
                Button("mainpanel.edit.ok") { viewModel.renameSelectedItem(to: text) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
    }
}

private struct EditSheetView: View {
    @Binding var text: String
    @ObservedObject var viewModel: ClipboardViewModel

    var body: some View {
        VStack(spacing: 12) {
            Text("mainpanel.edit.title")
                .font(.headline)
            TextEditor(text: $text)
                .font(.system(size: 13))
                .frame(minWidth: 300, minHeight: 120)
                .border(Color.secondary.opacity(0.3))
            HStack {
                Button("mainpanel.edit.cancel") { viewModel.showEditSheet = false }
                Button("mainpanel.edit.ok") { viewModel.editSelectedItem(to: text) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
    }
}

private struct NewItemSheetView: View {
    @Binding var text: String
    @ObservedObject var viewModel: ClipboardViewModel

    var body: some View {
        VStack(spacing: 12) {
            Text("mainpanel.newItem.title")
                .font(.headline)
            TextEditor(text: $text)
                .font(.system(size: 13))
                .frame(minWidth: 300, minHeight: 120)
                .border(Color.secondary.opacity(0.3))
            HStack {
                Button("mainpanel.edit.cancel") { viewModel.showNewItemSheet = false }
                Button("mainpanel.edit.ok") { viewModel.createNewTextItem(text: text) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
    }
}

// MARK: - Visual Effect View

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

#Preview {
    MainPanelView(viewModel: ClipboardViewModel())
        .frame(width: 1200)
}
