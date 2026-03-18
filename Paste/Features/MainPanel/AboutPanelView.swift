//
//  AboutPanelView.swift
//  Paste
//
//  Fixed "About" panel showing the developer's public account and donation QR codes.
//  These cards are not clipboard items — they cannot be deleted or modified.
//

import SwiftUI
import AppKit

// MARK: - Data

private struct AboutCard: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let imageName: String
    let accentColor: Color
    let icon: String
}

private let aboutCards: [AboutCard] = [
    AboutCard(
        title: "微信公众号",
        subtitle: "扫码关注，获取最新资讯",
        imageName: "about_wechat_account",
        accentColor: Color(red: 0.07, green: 0.73, blue: 0.31),
        icon: "antenna.radiowaves.left.and.right"
    ),
    AboutCard(
        title: "微信赞赏",
        subtitle: "扫码支持开发者",
        imageName: "about_wechat_pay",
        accentColor: Color(red: 0.07, green: 0.73, blue: 0.31),
        icon: "heart.fill"
    ),
    AboutCard(
        title: "支付宝赞赏",
        subtitle: "扫码支持开发者",
        imageName: "about_alipay",
        accentColor: Color(red: 0.07, green: 0.45, blue: 0.95),
        icon: "creditcard.fill"
    ),
]

// MARK: - AboutPanelView (horizontal — bottom/top)

struct AboutPanelView: View {
    @Environment(\.cardSize) private var cardSize

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: PanelLayout.cardSpacing) {
                ForEach(aboutCards) { card in
                    AboutCardView(card: card, size: cardSize)
                }
            }
            .padding(.horizontal, PanelLayout.panelPadding)
            .padding(.vertical, PanelLayout.vertPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - AboutPanelVerticalView (vertical — left/right)

struct AboutPanelVerticalView: View {
    @Environment(\.cardSize) private var cardSize

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: PanelLayout.cardSpacing) {
                ForEach(aboutCards) { card in
                    AboutCardView(card: card, size: cardSize)
                }
            }
            .padding(.horizontal, PanelLayout.panelPadding)
            .padding(.vertical, PanelLayout.vertPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - AboutCardView

private struct AboutCardView: View {
    let card: AboutCard
    let size: CGSize

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 0) {
            // QR code image
            if let nsImage = NSImage(named: card.imageName) {
                Image(nsImage: nsImage)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: size.width - 24, height: size.height - 56)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            Divider()
                .padding(.top, 4)

            // Footer
            HStack(spacing: 6) {
                Image(systemName: card.icon)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(card.accentColor)
                VStack(alignment: .leading, spacing: 1) {
                    Text(card.title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(card.subtitle)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .frame(width: size.width, height: size.height)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isHovered ? card.accentColor.opacity(0.6) : Color.clear,
                    lineWidth: 1.5
                )
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovered)
        .onHover { isHovered = $0 }
    }
}
