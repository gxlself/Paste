//
//  SettingsView.swift
//  Paste-iOS
//

import SwiftUI

struct SettingsView: View {

    private static let pasteWebsiteURL = URL(string: "https://paste.gxlself.com")!
    private static let appStoreGCalcProURL = URL(string: "https://apps.apple.com/us/app/g-calc-pro/id6759799669")!
    private static let appStoreStayAboveKillLineURL = URL(string: "https://apps.apple.com/us/app/stay-above-kill-line/id6759259799")!

    @ObservedObject var settings: iOSAppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var showClearConfirmation = false
    @State private var showPastePermissionGuide = false
    @State private var isManualCloudSyncInProgress = false
    /// Brief inline “Success” before the icon (no separate “Sync triggered” line).
    @State private var manualSyncSuccessFlash = false
    /// Save/sync failure; shown as caption under the row.
    @State private var manualSyncError: String?

    var body: some View {
        NavigationStack {
            List {
                extensionsSection
                generalSection
                clipboardSection
                rulesSection
                storageSection
                privacySection
                supportSection
                recommendedAppsSection
                legalSection
            }
            .navigationTitle(Text("menu.action.settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showPastePermissionGuide) {
                PastePermissionGuideView()
            }
            .confirmationDialog(
                Text("preferences.general.clearConfirm.title"),
                isPresented: $showClearConfirmation,
                titleVisibility: .visible
            ) {
                Button(String(localized: "preferences.general.clearConfirm.confirm"), role: .destructive) {
                    settings.clearAllHistory()
                }
                Button(String(localized: "preferences.general.clearConfirm.cancel"), role: .cancel) {}
            } message: {
                Text("preferences.general.clearConfirm.message")
            }
        }
    }

    // MARK: - Extensions

    private var extensionsSection: some View {
        Section {
            NavigationLink {
                keyboardSettingsDetail
            } label: {
                Label {
                    Text("preferences.tab.shortcuts")
                } icon: {
                    SettingsIcon(systemName: "keyboard", color: .blue)
                }
            }

            NavigationLink {
                actionExtensionDetail
            } label: {
                Label {
                    Text("preferences.general.integration")
                } icon: {
                    SettingsIcon(systemName: "square.and.arrow.up", color: .green)
                }
            }
        }
    }

    // MARK: - General (iCloud)

    private var generalSection: some View {
        Section(header: Text("preferences.tab.general")) {
            Toggle(isOn: $settings.iCloudSyncEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("preferences.sync.enableICloud")
                    if settings.iCloudSyncEnabled {
                        Text("preferences.sync.restartToApply")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            if !settings.iCloudAccountStatusMessage.isEmpty {
                Text(settings.iCloudAccountStatusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if settings.iCloudSyncEnabled {
                Button {
                    triggerManualCloudSync()
                } label: {
                    HStack(spacing: 10) {
                        Text("preferences.sync.syncNow")
                            .foregroundStyle(Color(UIColor.label))
                        Spacer(minLength: 8)
                        if manualSyncSuccessFlash {
                            Text("preferences.sync.inlineSuccess")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.green)
                        }
                        if isManualCloudSyncInProgress {
                            ManualSyncSpinningArrowIcon()
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.body.weight(.medium))
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .disabled(isManualCloudSyncInProgress)

                if let manualSyncError {
                    Text(manualSyncError)
                        .font(.caption)
                        .foregroundStyle(Color.red)
                }
            }
        }
        .onAppear { settings.refreshICloudAccountStatus() }
        .onChange(of: settings.iCloudSyncEnabled) { _ in
            settings.refreshICloudAccountStatus()
            if !settings.iCloudSyncEnabled {
                manualSyncError = nil
                manualSyncSuccessFlash = false
            }
        }
    }

    private static let manualSyncMinSpinnerDuration: TimeInterval = 0.55
    private static let manualSyncSuccessVisibleDuration: TimeInterval = 1.2

    private func triggerManualCloudSync() {
        guard settings.iCloudSyncEnabled else { return }
        guard !isManualCloudSyncInProgress else { return }
        manualSyncError = nil
        manualSyncSuccessFlash = false
        let startedAt = Date()
        isManualCloudSyncInProgress = true
        SharedCoreDataStack.shared.requestSyncNow { error in
            let elapsed = Date().timeIntervalSince(startedAt)
            let remaining = max(0, Self.manualSyncMinSpinnerDuration - elapsed)
            DispatchQueue.main.asyncAfter(deadline: .now() + remaining) {
                isManualCloudSyncInProgress = false
                if let error {
                    manualSyncError = String(localized: "preferences.sync.feedback.failed")
                        + ": " + error.localizedDescription
                } else {
                    manualSyncSuccessFlash = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + Self.manualSyncSuccessVisibleDuration) {
                        manualSyncSuccessFlash = false
                    }
                }
            }
        }
    }

    // MARK: - Clipboard collection

    private var clipboardSection: some View {
        Section(header: Text("ios.settings.clipboardCollection")) {
            Toggle(String(localized: "ios.settings.collectWhenActive"), isOn: $settings.collectWhenActive)
            Toggle(String(localized: "ios.settings.collectFromKeyboard"), isOn: $settings.collectFromKeyboard)
            Toggle(String(localized: "preferences.general.recordImages"), isOn: $settings.recordImages)
            Toggle(String(localized: "preferences.general.linkPreview"), isOn: $settings.linkPreviewEnabled)

            Button {
                showPastePermissionGuide = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ios.pastePermission.settingsToggle")
                            .foregroundStyle(Color(UIColor.label))
                        Text("ios.pastePermission.settingsToggle.desc")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "info.circle")
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
    }

    // MARK: - Rules

    private var rulesSection: some View {
        Section(header: Text("preferences.tab.rules")) {
            Toggle(String(localized: "preferences.rules.ignoreSensitive"), isOn: $settings.ignoreSensitiveContent)
            Toggle(String(localized: "preferences.rules.ignoreAutoGenerated"), isOn: $settings.ignoreAutoGeneratedContent)
        }
    }

    // MARK: - Storage

    private var storageSection: some View {
        Section(header: Text("preferences.general.storage")) {
            retentionPicker

            if settings.retentionPreset != .unlimited {
                HStack {
                    Text("preferences.general.maxItems")
                    Spacer()
                    Stepper("\(settings.retentionMaxItems)", value: $settings.retentionMaxItems, in: 50...10000, step: 50)
                        .fixedSize()
                }
            }

            HStack {
                Text("preferences.general.databaseSize")
                Spacer()
                Text(settings.getDatabaseSize())
                    .foregroundStyle(.secondary)
            }

            Button(role: .destructive) {
                showClearConfirmation = true
            } label: {
                Text("preferences.general.clearAllHistory")
            }
        }
    }

    private var retentionPicker: some View {
        HStack {
            Text("preferences.general.retentionCapacity")
            Spacer()
            Picker("", selection: $settings.retentionPreset) {
                Text("preferences.general.retention.day").tag(iOSAppSettings.RetentionPreset.day)
                Text("preferences.general.retention.week").tag(iOSAppSettings.RetentionPreset.week)
                Text("preferences.general.retention.month").tag(iOSAppSettings.RetentionPreset.month)
                Text("preferences.general.retention.year").tag(iOSAppSettings.RetentionPreset.year)
                Text("preferences.general.retention.unlimited").tag(iOSAppSettings.RetentionPreset.unlimited)
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
    }

    // MARK: - Privacy

    private var privacySection: some View {
        Section(header: Text("ios.settings.privacy")) {
            Toggle(String(localized: "ios.settings.showInScreenSharing"), isOn: $settings.showInScreenSharing)
                .footer(Text("ios.settings.showInScreenSharing.desc"))
        }
    }

    // MARK: - Support

    private var supportSection: some View {
        Section {
            NavigationLink {
                GettingStartedView()
            } label: {
                Label {
                    Text("ios.settings.gettingStarted")
                } icon: {
                    Image(systemName: "book")
                }
            }

            NavigationLink {
                HelpCenterView()
            } label: {
                Label {
                    Text("ios.settings.helpCenter")
                } icon: {
                    Image(systemName: "questionmark.circle")
                }
            }

            Button {
                UIApplication.shared.open(Self.pasteWebsiteURL)
            } label: {
                HStack {
                    Label {
                        Text("ios.promo.macPaste.title")
                            .foregroundStyle(Color(UIColor.label))
                    } icon: {
                        Image(systemName: "macbook")
                            .foregroundStyle(Color.accentColor)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.forward.square")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityHint(Text("ios.promo.macPaste.a11yHint"))

            Button {
                contactSupport()
            } label: {
                Label {
                    Text("about.contactSupport")
                        .foregroundStyle(Color(UIColor.label))
                } icon: {
                    Image(systemName: "envelope")
                }
            }
        }
    }

    // MARK: - Recommended apps (App Store)

    private var recommendedAppsSection: some View {
        Section(header: Text("ios.settings.recommendedApps")) {
            appStoreRecommendationRow(
                "ios.settings.recommended.gCalcPro",
                appIconAssetName: "RecommendedGCalcPro",
                url: Self.appStoreGCalcProURL
            )
            appStoreRecommendationRow(
                "ios.settings.recommended.stayAboveKillLine",
                appIconAssetName: "RecommendedStayAboveKillLine",
                url: Self.appStoreStayAboveKillLineURL
            )
        }
    }

    @ViewBuilder
    private func appStoreRecommendationRow(
        _ titleKey: LocalizedStringKey,
        appIconAssetName: String,
        url: URL
    ) -> some View {
        Button {
            UIApplication.shared.open(url)
        } label: {
            HStack(spacing: 12) {
                Image(appIconAssetName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 29, height: 29)
                    .clipShape(RoundedRectangle(cornerRadius: 6.5, style: .continuous))
                    .accessibilityHidden(true)
                Text(titleKey)
                    .foregroundStyle(Color(UIColor.label))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "arrow.up.forward.square")
                    .font(.body)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityHint(Text("ios.settings.recommended.a11yHint"))
    }

    // MARK: - Legal

    private var legalSection: some View {
        Section {
            NavigationLink {
                PolicyView(document: .privacyPolicy)
            } label: {
                Text("about.privacyPolicy")
            }

            NavigationLink {
                PolicyView(document: .termsOfUse)
            } label: {
                Text("about.termsOfUse")
            }
        }
    }

    private func contactSupport() {
        let subject = String(localized: "ios.support.emailSubject")
        let body = String(localized: "ios.support.emailBody")
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "gxlself@gmail.com"
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body),
        ]
        if let url = components.url {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Action extension detail

    private var actionExtensionDetail: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ios.extension.howToUse")
                        .font(.headline)
                    Text("ios.extension.step1")
                    Text("ios.extension.step2")
                    Text("ios.extension.step3")
                }
                .font(.subheadline)
                .padding(.vertical, 4)
            }
        }
        .navigationTitle(Text("preferences.general.integration"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Keyboard settings detail

    private var keyboardSettingsDetail: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ios.keyboard.howToEnable")
                        .font(.headline)
                    Text("ios.keyboard.step1")
                    Text("ios.keyboard.step2")
                    Text("ios.keyboard.step3")
                    Text("ios.keyboard.step4")
                }
                .font(.subheadline)
                .padding(.vertical, 4)
            }

            Section {
                Button(String(localized: "preferences.general.accessibility.openSettings")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
        }
        .navigationTitle(Text("preferences.tab.shortcuts"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Manual sync spinner

/// Drives rotation with `TimelineView` so it stops as soon as `isManualCloudSyncInProgress` becomes false.
/// `Animation.repeatForever` on `@State` is not reliably cancelled when resetting the angle.
private struct ManualSyncSpinningArrowIcon: View {

    private static let secondsPerRevolution: Double = 0.85

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let degrees = (t * 360 / Self.secondsPerRevolution).truncatingRemainder(dividingBy: 360)
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.body.weight(.medium))
                .foregroundStyle(Color.accentColor)
                .rotationEffect(.degrees(degrees))
        }
    }
}

// MARK: - Settings Icon

private struct SettingsIcon: View {
    let systemName: String
    let color: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
            .frame(width: 28, height: 28)
            .background(color, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

// MARK: - Toggle footer

extension Toggle {
    func footer(_ text: Text) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            self
            text
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
