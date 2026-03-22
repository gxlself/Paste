//
//  paste_tool_iOSApp.swift
//  Paste-iOS
//
//
//  Copyright © 2026 Gxlself. All rights reserved.
//

import SwiftUI

@main
struct paste_tool_iOSApp: App {

    @UIApplicationDelegateAdaptor(PasteIOSAppDelegate.self) private var appDelegate

    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .opacity(showSplash ? 0 : 1)

                if showSplash {
                    SplashView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.4), value: showSplash)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    showSplash = false
                }
            }
        }
    }
}

// MARK: - Splash

private struct SplashView: View {
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()

            if let icon = UIImage(named: "AppIcon") {
                Image(uiImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            } else {
                Image(systemName: "clipboard.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.blue)
            }
        }
    }
}
