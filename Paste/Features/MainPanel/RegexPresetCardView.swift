//
//  RegexPresetCardView.swift
//  Paste
//
//  Card view for regex preset entries in the clipboard panel.
//

import SwiftUI

struct RegexPresetCardView: View {
    let preset: RegexPreset
    let isSelected: Bool
    let onSelect: () -> Void
    let onPaste: (_ plainTextOnly: Bool) -> Void

    @State private var isHovered = false
    @Environment(\.cardSize) private var cardSize
    private let patternPreviewLength = 24

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(preset.name)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .foregroundColor(.primary)
                Text(truncatedPattern)
                    .font(.system(size: 9))
                    .lineLimit(2)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
            }
            .padding(8)
            .frame(height: cardSize.height - 32)
            Divider()
                .background(Color(nsColor: .separatorColor))
            HStack {
                Image(systemName: "curlybraces")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .frame(width: cardSize.width, height: cardSize.height)
        .background(isSelected ? Color.accentColor.opacity(0.3) : Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: isSelected ? 2 : 1)
        )
        .overlay(alignment: .topLeading) {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 1)
                    .padding(6)
            }
        }
        .shadow(color: .black.opacity(isSelected ? 0.3 : 0.1), radius: isSelected ? 8 : 4)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .highPriorityGesture(TapGesture().onEnded {
            onSelect()
            if AppSettings.directPasteEnabled {
                onPaste(AppSettings.pastePlainTextByDefault || NSEvent.modifierFlags.contains(AppSettings.plainTextModifier))
            }
        })
        .contextMenu {
            Button("mainpanel.context.paste") { onPaste(false) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(format: String(localized: "accessibility.mainpanel.presetFormat"), preset.name, truncatedPattern))
        .accessibilityHint(Text("accessibility.mainpanel.card.hint"))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var truncatedPattern: String {
        if preset.pattern.count <= patternPreviewLength { return preset.pattern }
        return String(preset.pattern.prefix(patternPreviewLength)) + "…"
    }
}
