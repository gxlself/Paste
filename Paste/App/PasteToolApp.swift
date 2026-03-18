//
//  PasteToolApp.swift
//  Paste
//
//  macOS app entry point
//

import SwiftUI

@main
struct PasteToolApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Use the Settings scene to host the Preferences window.
        Settings {
            PreferencesView()
        }
    }
}
