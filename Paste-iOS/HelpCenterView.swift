//
//  HelpCenterView.swift
//  Paste-iOS
//

import SwiftUI

struct HelpCenterView: View {

    private let faqItems: [(key: String, titleKey: String, answerKey: String, icon: String)] = [
        ("history", "ios.help.history.title", "ios.help.history.answer", "clock.arrow.circlepath"),
        ("edit", "ios.help.edit.title", "ios.help.edit.answer", "pencil"),
        ("keyboard", "ios.help.keyboard.title", "ios.help.keyboard.answer", "keyboard"),
        ("pinboard", "ios.help.pinboard.title", "ios.help.pinboard.answer", "rectangle.stack"),
        ("icloud", "ios.help.icloud.title", "ios.help.icloud.answer", "icloud"),
        ("search", "ios.help.search.title", "ios.help.search.answer", "magnifyingglass"),
        ("privacy", "ios.help.privacy.title", "ios.help.privacy.answer", "lock.shield"),
        ("paste", "ios.help.paste.title", "ios.help.paste.answer", "doc.on.clipboard"),
    ]

    var body: some View {
        List {
            ForEach(faqItems, id: \.key) { item in
                DisclosureGroup {
                    Text(String(localized: String.LocalizationValue(item.answerKey)))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                } label: {
                    Label {
                        Text(String(localized: String.LocalizationValue(item.titleKey)))
                            .font(.body)
                    } icon: {
                        Image(systemName: item.icon)
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
        }
        .navigationTitle(Text("ios.settings.helpCenter"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
