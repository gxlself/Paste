//
//  GettingStartedView.swift
//  Paste-iOS
//

import SwiftUI

struct GettingStartedView: View {

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                stepCard(
                    number: 1,
                    icon: "keyboard",
                    color: .blue,
                    title: String(localized: "ios.guide.step1.title"),
                    description: String(localized: "ios.guide.step1.desc")
                )

                stepCard(
                    number: 2,
                    icon: "hand.tap",
                    color: .orange,
                    title: String(localized: "ios.guide.step2.title"),
                    description: String(localized: "ios.guide.step2.desc")
                )

                stepCard(
                    number: 3,
                    icon: "rectangle.stack",
                    color: .purple,
                    title: String(localized: "ios.guide.step3.title"),
                    description: String(localized: "ios.guide.step3.desc")
                )

                stepCard(
                    number: 4,
                    icon: "icloud",
                    color: .cyan,
                    title: String(localized: "ios.guide.step4.title"),
                    description: String(localized: "ios.guide.step4.desc")
                )

                stepCard(
                    number: 5,
                    icon: "hand.draw",
                    color: .green,
                    title: String(localized: "ios.guide.step5.title"),
                    description: String(localized: "ios.guide.step5.desc")
                )

                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("preferences.general.accessibility.openSettings")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(.horizontal, 4)
            }
            .padding()
        }
        .navigationTitle(Text("ios.settings.gettingStarted"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func stepCard(
        number: Int,
        icon: String,
        color: Color,
        title: String,
        description: String
    ) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("\(number). \(title)")
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
