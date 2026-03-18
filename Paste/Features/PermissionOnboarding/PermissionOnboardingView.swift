//
//  PermissionOnboardingView.swift
//  Paste
//
//  Permission onboarding view: explains required permissions and guides the user to System Settings.
//  Design: minimal, step-by-step, accessibility-friendly.
//

import SwiftUI

struct PermissionOnboardingView: View {
    var onRecheck: () -> Bool
    var onVerified: () -> Void

    private let cardCornerRadius: CGFloat = 12
    private let cardPadding: CGFloat = 16
    private let minButtonHeight: CGFloat = 44

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    introSection
                    accessibilityStepCard
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            footer
        }
        .frame(width: 440)
        .frame(minHeight: 420)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text(String(localized: "permission.onboarding.title"))
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
            Text(String(localized: "permission.onboarding.subtitle"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 28)
        .padding(.bottom, 20)
        .padding(.horizontal, 24)
    }

    private var introSection: some View {
        Text(String(localized: "permission.onboarding.intro"))
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private var accessibilityStepCard: some View {
        stepCard(
            symbolName: "accessibility",
            title: String(localized: "permission.onboarding.accessibility.title"),
            description: String(localized: "permission.onboarding.accessibility.description"),
            openSettings: PermissionChecker.openAccessibilitySettings
        )
    }

    private func stepCard(symbolName: String, title: String, description: String, openSettings: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: symbolName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            Button {
                openSettings()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "gear")
                    Text(String(localized: "permission.onboarding.openSettings"))
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: minButtonHeight)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(cardPadding)
        .background(
            RoundedRectangle(cornerRadius: cardCornerRadius)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: cardCornerRadius)
                        .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
                )
        )
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Button {
                if onRecheck() {
                    onVerified()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                    Text(String(localized: "permission.onboarding.recheck"))
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: minButtonHeight)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Text(String(localized: "permission.onboarding.footerHint"))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(24)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

#Preview {
    PermissionOnboardingView(onRecheck: { false }, onVerified: {})
}
