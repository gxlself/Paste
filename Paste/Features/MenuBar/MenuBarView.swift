//
//  MenuBarView.swift
//  Paste
//
//  Menu bar view (used for popover or supplemental menu content)
//

import SwiftUI

struct MenuBarView: View {
    
    @StateObject private var viewModel = ClipboardViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Title bar.
            HStack {
                Text("menu.title.recentClipboard")
                    .font(.headline)
                Spacer()
                Button("menu.action.openPanel") {
                    openMainPanel()
                }
                .buttonStyle(.link)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            Divider()
            
            // Recent 5 items.
            if viewModel.filteredItems.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("menu.empty.noRecords")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                ForEach(viewModel.filteredItems.prefix(5)) { item in
                    MenuBarItemRow(item: item) {
                        viewModel.pasteItem(item)
                    }
                }
            }
            
            Divider()
            
            // Bottom actions.
            HStack {
                Button("menu.action.settings") {
                    openPreferences()
                }
                .buttonStyle(.link)
                
                Spacer()
                
                Button("menu.action.quit") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.link)
                .foregroundColor(.red)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 280)
    }
    
    private func openMainPanel() {
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.showMainPanel()
        }
    }
    
    private func openPreferences() {
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.openPreferences()
        } else {
            PreferencesWindowController.shared.show()
        }
    }
}

// MARK: - Menu Bar Item Row

struct MenuBarItemRow: View {
    
    let item: ClipboardItemModel
    let onTap: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Type icon.
            Image(systemName: item.itemType.iconName)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            // Content preview.
            Text(item.displayText)
                .font(.system(size: 12))
                .lineLimit(1)
                .foregroundColor(.primary)
            
            Spacer()
            
            // Timestamp.
            Text(item.formattedTime)
                .font(.system(size: 10))
                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isHovered ? Color.primary.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onTap()
        }
    }
}

#Preview {
    MenuBarView()
}
