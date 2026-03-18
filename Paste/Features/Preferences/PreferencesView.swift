//
//  PreferencesView.swift
//  Paste
//
//  Preferences view
//

import SwiftUI
import ApplicationServices

struct PreferencesView: View {
    
    @StateObject private var viewModel = PreferencesViewModel()
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Spacer(minLength: 0)
                Picker("", selection: $selectedTab) {
                    Text("preferences.tab.general").tag(0)
                    Text("preferences.tab.shortcuts").tag(1)
                    Text("preferences.tab.rules").tag(2)
                    Text("preferences.tab.sync").tag(3)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 360)
                Spacer(minLength: 0)
            }
            .padding(.top, 12)
            .padding(.horizontal, 16)

            Group {
                switch selectedTab {
                case 0:
                    GeneralSettingsView(viewModel: viewModel)
                case 1:
                    ShortcutSettingsView(viewModel: viewModel)
                case 2:
                    RulesSettingsView(viewModel: viewModel)
                default:
                    SyncSettingsView(viewModel: viewModel)
                }
            }
            // Ensure content stays top-aligned after tab switches.
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 720, height: 640)
        .controlSize(.small)
        .font(.system(size: 14))
        .animation(.snappy(duration: 0.2), value: selectedTab)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    
    @ObservedObject var viewModel: PreferencesViewModel
    @State private var showClearConfirmation = false
    @State private var hasAccessibilityPermission = PermissionChecker.hasAccessibilityPermission
    
    var body: some View {
        PreferencesPage {
            accessibilityStatusCard

            PreferenceCard(title: "preferences.general.appearance") {
                Picker("", selection: $viewModel.appearance) {
                    Text("preferences.general.appearance.system").tag(AppSettings.Appearance.system)
                    Text("preferences.general.appearance.light").tag(AppSettings.Appearance.light)
                    Text("preferences.general.appearance.dark").tag(AppSettings.Appearance.dark)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityLabel(Text("preferences.general.appearance"))
            }

            PreferenceCard(title: "preferences.general.panelPosition") {
                Picker("", selection: $viewModel.panelPosition) {
                    Text("preferences.general.panelPosition.bottom").tag(AppSettings.PanelPosition.bottom)
                    Text("preferences.general.panelPosition.top").tag(AppSettings.PanelPosition.top)
                    Text("preferences.general.panelPosition.left").tag(AppSettings.PanelPosition.left)
                    Text("preferences.general.panelPosition.right").tag(AppSettings.PanelPosition.right)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityLabel(Text("preferences.general.panelPosition"))
            }
            
            PreferenceCard {
                PreferenceToggleRow("preferences.general.launchAtLogin", isOn: $viewModel.launchAtLogin)
            }

            PreferenceCard(title: "preferences.general.integration") {
                PreferenceToggleRow("preferences.general.pastePlainText", isOn: $viewModel.pastePlainTextByDefault)
                PreferenceToggleRow("preferences.general.linkPreview", isOn: $viewModel.linkPreviewEnabled)
            }

            PreferenceCard(title: "preferences.general.others") {
                PreferenceToggleRow("preferences.general.sound", isOn: $viewModel.soundEnabled)
                PreferenceToggleRow("preferences.general.menuBarIcon", isOn: $viewModel.showMenuBarIcon)
            }

            PreferenceCard(title: "preferences.general.storage") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("preferences.general.retentionCapacity")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Slider(
                        value: Binding<Double>(
                            get: { Double(viewModel.retentionPreset.rawValue) },
                            set: { viewModel.retentionPreset = AppSettings.RetentionPreset(rawValue: Int($0)) ?? .month }
                        ),
                        in: 0...Double(AppSettings.RetentionPreset.unlimited.rawValue),
                        step: 1
                    )

                    HStack {
                        Text("preferences.general.retention.day")
                        Spacer()
                        Text("preferences.general.retention.week")
                        Spacer()
                        Text("preferences.general.retention.month")
                        Spacer()
                        Text("preferences.general.retention.year")
                        Spacer()
                        Text("preferences.general.retention.unlimited")
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                    if viewModel.retentionPreset != .unlimited {
                        PreferenceRow("preferences.general.maxItems") {
                            HStack(spacing: 8) {
                                TextField("", value: $viewModel.retentionMaxItems, format: .number)
                                    .frame(width: 92)
                                    .textFieldStyle(.roundedBorder)
                                Stepper("", value: $viewModel.retentionMaxItems, in: Constants.minMaxItems...Constants.maxMaxItems, step: 100)
                                    .labelsHidden()
                            }
                        }
                    }

                    PreferenceToggleRow("preferences.general.recordImages", isOn: $viewModel.recordImages)
                }
            }

            PreferenceCard {
                PreferenceRow("preferences.general.databaseSize") {
                    Text(viewModel.getDatabaseSize())
                        .foregroundStyle(.secondary)
                }
                PreferenceRowButton("preferences.general.clearAllHistory", role: .destructive) {
                    showClearConfirmation = true
                }
            }
        }
        .confirmationDialog("preferences.general.clearConfirm.title", isPresented: $showClearConfirmation, titleVisibility: .visible) {
            Button("preferences.general.clearConfirm.confirm", role: .destructive) {
                viewModel.clearAllHistory()
            }
            Button("preferences.general.clearConfirm.cancel", role: .cancel) {}
        } message: {
            Text("preferences.general.clearConfirm.message")
        }
        .onAppear { hasAccessibilityPermission = PermissionChecker.hasAccessibilityPermission }
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            hasAccessibilityPermission = PermissionChecker.hasAccessibilityPermission
        }
    }

    // MARK: - Accessibility Card

    private var accessibilityStatusCard: some View {
        PreferenceCard(title: "preferences.general.accessibility") {
            VStack(alignment: .leading, spacing: 4) {
                Text("preferences.general.accessibility.assistedPaste.description")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                Image(systemName: hasAccessibilityPermission ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(hasAccessibilityPermission ? Color.green : Color.orange)
                Text(hasAccessibilityPermission
                     ? "preferences.general.accessibility.status.granted"
                     : "preferences.general.accessibility.status.notGranted")
                    .font(.system(size: 11))
                    .foregroundStyle(hasAccessibilityPermission ? .secondary : Color.orange)
                Spacer()
                if !hasAccessibilityPermission {
                    Button("preferences.general.accessibility.openSettings") {
                        PermissionChecker.openAccessibilitySettings()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                    }
                }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                PreferenceToggleRow("preferences.general.accessibility.voiceOverAnnounce", isOn: $viewModel.voiceOverAnnounceEnabled)
                Text("preferences.general.accessibility.voiceOverAnnounce.description")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Shortcut Settings

struct ShortcutSettingsView: View {
    
    @ObservedObject var viewModel: PreferencesViewModel
    
    var body: some View {
        PreferencesPage {
            PreferenceCard(title: "preferences.shortcuts.section.title") {
                HotKeyRecorderView(title: "preferences.shortcuts.activatePaste", binding: $viewModel.hotKeyPaste) { _ in }
                HotKeyRecorderView(title: "preferences.shortcuts.activatePasteStack", binding: $viewModel.hotKeyPasteStack) { _ in }
                
                HotKeyRecorderView(title: "preferences.shortcuts.nextPinboard", binding: $viewModel.hotKeyNextPinboard) { _ in }
                HotKeyRecorderView(title: "preferences.shortcuts.prevPinboard", binding: $viewModel.hotKeyPrevPinboard) { _ in }
                
                PreferenceRowButton("preferences.shortcuts.resetDefault") {
                    viewModel.resetHotKeysToDefault()
                }
            }

            PreferenceCard(title: "preferences.shortcuts.panelShortcuts.title") {
                PreferenceRow(title: "preferences.shortcuts.quickPaste") {
                    HStack(spacing: 8) {
                        modifierPicker(selection: $viewModel.quickPasteModifier)
                        Text("+ 1..9")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }

                PreferenceRow(title: "preferences.shortcuts.plainTextMode") {
                    modifierPicker(selection: $viewModel.plainTextModifier)
                }

                VStack(alignment: .leading, spacing: 6) {
                    shortcutRow("↑ / ↓", description: String(localized: "preferences.shortcuts.row.navigate"))
                    shortcutRow("Enter", description: String(localized: "preferences.shortcuts.row.paste"))
                    shortcutRow("⌘C", description: String(localized: "preferences.shortcuts.row.copy"))
                    shortcutRow("⌘⌫", description: String(localized: "preferences.shortcuts.row.delete"))
                    shortcutRow("Esc", description: String(localized: "preferences.shortcuts.row.esc"))
                }
                .padding(.top, 8)
            }
        }
    }
    
    private func shortcutRow(_ shortcut: String, description: String) -> some View {
        HStack {
            Text(shortcut)
                .font(.system(.body, design: .monospaced))
                .frame(width: 60, alignment: .leading)
            Text(description)
                .foregroundColor(.secondary)
        }
    }
    
    private func modifierPicker(selection: Binding<NSEvent.ModifierFlags>) -> some View {
        let rawBinding = Binding<UInt>(
            get: { selection.wrappedValue.rawValue },
            set: { selection.wrappedValue = NSEvent.ModifierFlags(rawValue: $0) }
        )
        return Picker("", selection: rawBinding) {
            Text("⌘ Command").tag(NSEvent.ModifierFlags.command.rawValue)
            Text("⌥ Option").tag(NSEvent.ModifierFlags.option.rawValue)
            Text("⌃ Control").tag(NSEvent.ModifierFlags.control.rawValue)
            Text("⇧ Shift").tag(NSEvent.ModifierFlags.shift.rawValue)
        }
        .labelsHidden()
        .frame(width: 160)
    }
}

// MARK: - Excluded Apps

struct ExcludedAppsView: View {
    
    @ObservedObject var viewModel: PreferencesViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("preferences.excludedApps.description")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            List {
                ForEach(viewModel.excludedApps) { app in
                    HStack {
                        if let icon = app.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 22, height: 22)
                        }
                        Text(app.name)
                        Spacer()
                        Button(action: { viewModel.removeExcludedApp(app) }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.bordered)
            .frame(height: 140)
            
            HStack {
                Button(action: viewModel.addExcludedApp) {
                    Label("preferences.excludedApps.addApp", systemImage: "plus")
                }
                
                Spacer()
                
                Button("preferences.excludedApps.add1Password") {
                    viewModel.addExcludedApp(bundleId: "com.1password.1password")
                }
                .disabled(viewModel.excludedApps.contains { $0.bundleId == "com.1password.1password" })
            }
        }
    }
}

// MARK: - Rules

struct RulesSettingsView: View {
    @ObservedObject var viewModel: PreferencesViewModel

    var body: some View {
        PreferencesPage {
            PreferenceCard(title: "preferences.rules.excludedApps.title") {
                ExcludedAppsView(viewModel: viewModel)
            }
        }
    }
}

// MARK: - Sync

struct SyncSettingsView: View {
    @ObservedObject var viewModel: PreferencesViewModel

    var body: some View {
        PreferencesPage {
            PreferenceCard(title: "preferences.sync.enableICloud") {
                PreferenceRow(title: "preferences.sync.enableICloud") {
                    Toggle("", isOn: $viewModel.iCloudSyncEnabled)
                        .labelsHidden()
                        .disabled(!viewModel.isICloudCapabilitySupported)
                }
                
                if !viewModel.iCloudStatusMessage.isEmpty {
                    Text(viewModel.iCloudStatusMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                }

                HStack(spacing: 10) {
                    Button("preferences.sync.syncNow") {
                        viewModel.syncNow()
                    }
                    .disabled(!viewModel.iCloudSyncEnabled || viewModel.isSyncing)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if viewModel.isSyncing {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .padding(.vertical, 4)

                if let feedback = viewModel.syncFeedbackMessage {
                    Text(feedback)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
            }
        }
    }
}

// MARK: - Layout components

private struct PreferencesPage<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Preference Card

private struct PreferenceCard<Content: View>: View {
    let title: LocalizedStringKey?
    @ViewBuilder let content: () -> Content

    init(title: LocalizedStringKey? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
            )
        }
    }
}

private struct PreferenceRow<Right: View>: View {
    let title: LocalizedStringKey
    let right: () -> Right

    init(_ title: LocalizedStringKey, @ViewBuilder right: @escaping () -> Right) {
        self.title = title
        self.right = right
    }

    init(title: LocalizedStringKey, @ViewBuilder right: @escaping () -> Right) {
        self.title = title
        self.right = right
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
            right()
        }
        .padding(.vertical, 4)
    }
}

private struct PreferenceToggleRow: View {
    let title: LocalizedStringKey
    @Binding var isOn: Bool

    init(_ title: LocalizedStringKey, isOn: Binding<Bool>) {
        self.title = title
        self._isOn = isOn
    }

    var body: some View {
        PreferenceRow(title: title) {
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
    }
}

private struct PreferenceRowButton: View {
    let title: LocalizedStringKey
    let role: ButtonRole?
    let action: () -> Void

    init(_ title: LocalizedStringKey, role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.title = title
        self.role = role
        self.action = action
    }

    var body: some View {
        Button(title, role: role, action: action)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    PreferencesView()
}
