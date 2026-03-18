//
//  PastePermissionGuideView.swift
//  Paste-iOS
//

import SwiftUI

struct PastePermissionGuideView: View {

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    stepsSection
                    openSettingsButton
                }
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle(Text("ios.pastePermission.title"))
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
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.orange)
            }

            Text("ios.pastePermission.header")
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)

            Text("ios.pastePermission.explanation")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Steps

    private var stepsSection: some View {
        VStack(spacing: 0) {
            guideStep(number: 1, text: String(localized: "ios.pastePermission.step1"), icon: "gearshape", isLast: false)
            guideStep(number: 2, text: String(localized: "ios.pastePermission.step2"), icon: "arrow.down.app", isLast: false)
            guideStep(number: 3, text: String(localized: "ios.pastePermission.step3"), icon: "doc.on.clipboard", isLast: false)
            guideStep(number: 4, text: String(localized: "ios.pastePermission.step4"), icon: "checkmark.circle", isLast: true)
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func guideStep(number: Int, text: String, icon: String, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 32, height: 32)
                    Text("\(number)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                if !isLast {
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.3))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 32)

            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 24)
                Text(text)
                    .font(.body)
                Spacer()
            }
            .padding(.vertical, 12)
        }
    }

    // MARK: - Open Settings

    private var openSettingsButton: some View {
        Button {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack {
                Image(systemName: "arrow.up.forward.app")
                Text("ios.pastePermission.openSettings")
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.accentColor)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}
