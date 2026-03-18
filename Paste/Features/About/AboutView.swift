//
//  AboutView.swift
//  Paste
//
//  About (menu / preferences) view
//

import AppKit
import SwiftUI
import StoreKit

struct AboutView: View {
    
    private let developerName = "Gxlself"
    private let supportEmail = "gxlself@gmail.com"
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 22)
            
            Image(nsImage: appIcon)
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .frame(width: 104, height: 104)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: Color.black.opacity(0.16), radius: 9, x: 0, y: 4)
            
            Spacer(minLength: 16)
            
            Text(appName)
                .font(.system(size: 38, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Spacer(minLength: 8)
            
            Text(versionText)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.primary.opacity(0.90))
            
            Spacer(minLength: 28)
            
            Text(String(format: String(localized: "about.developedByFormat", defaultValue: "由%@开发"), developerName))
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.secondary)
            
            Spacer(minLength: 16)
            
            actionButtons
            
            Spacer(minLength: 12)
            
            policyLinks
            
            Spacer(minLength: 16)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var actionButtons: some View {
        VStack(spacing: 10) {
            // Rate app button.
            actionButton(
                title: String(localized: "about.rateApp", defaultValue: "在 App Store 中评价"),
                icon: "star.fill"
            ) {
                rateApp()
            }
            
            // Contact support button.
            actionButton(
                title: String(localized: "about.contactSupport", defaultValue: "联系支持"),
                icon: "envelope.fill"
            ) {
                contactSupport()
            }
        }
    }
    
    private var policyLinks: some View {
        HStack(spacing: 8) {
            policyButton(title: String(localized: "about.privacyPolicy", defaultValue: "隐私政策")) {
                PolicyPresenter.shared.showPrivacyPolicy()
            }
            
            Text("–")
                .foregroundColor(.primary)
                .fontWeight(.semibold)
            
            policyButton(title: String(localized: "about.termsOfUse", defaultValue: "使用条款")) {
                PolicyPresenter.shared.showTermsOfUse()
            }
        }
        .font(.system(size: 15, weight: .semibold))
    }
    
    @ViewBuilder
    private func actionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.accentColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.accentColor.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func policyButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .foregroundColor(.primary)
        }
        .buttonStyle(.plain)
    }
    
    private var appIcon: NSImage {
        AppLogoCache.logoImage()
    }
    
    private var appName: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
        ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)
        ?? String(localized: "about.appName", defaultValue: "Paste")
    }
    
    private var versionText: String {
        let short = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.0.1"
        let build = (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String)
        if let build, !build.isEmpty, build != short {
            return "版本  \(short) (\(build))"
        }
        return "版本  \(short)"
    }
    
    // MARK: - Actions
    
    private func rateApp() {
        // Use SKStoreReviewController on macOS.
        // Note: the app must be live on the App Store for this to work.
        SKStoreReviewController.requestReview()
        
        // To show in a specific window context, try:
        // macOS's SKStoreReviewController usually picks the appropriate location automatically.
    }
    
    private func contactSupport() {
        let subject = String(localized: "about.supportEmail.subject", defaultValue: "Paste 支持请求")
        let body = String(localized: "about.supportEmail.body", defaultValue: "请描述您的问题或建议：\n\n")
        
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        
        if let url = components.url {
            NSWorkspace.shared.open(url)
        }
    }
    
    private var appStoreId: String {
        // Retrieve the App Store ID from Info.plist or Bundle.
        // Return an empty string or placeholder if the app is not yet listed.
        return Bundle.main.object(forInfoDictionaryKey: "AppStoreID") as? String ?? ""
    }
}

