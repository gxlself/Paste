// CopiedToastView.swift
// Paste-iOS

import SwiftUI

struct CopiedToastView: View {

    private let accentGold = Color(red: 0.83, green: 0.69, blue: 0.22)

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.body)
                .foregroundStyle(accentGold)

            Text("ios.toast.copied")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color(UIColor.label))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: 6)
    }
}
