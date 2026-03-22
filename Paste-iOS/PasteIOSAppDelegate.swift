//
//  PasteIOSAppDelegate.swift
//  Paste-iOS
//
//  Registers for remote notifications so NSPersistentCloudKitContainer can receive
//  CloudKit push updates (required for reliable sync after App Store / TestFlight).
//

import UIKit

final class PasteIOSAppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        application.registerForRemoteNotifications()
        return true
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // Core Data + CloudKit processes the notification asynchronously.
        DispatchQueue.main.async {
            completionHandler(.newData)
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Common on Simulator or when entitlements / provisioning are wrong; log for diagnostics.
        print("PasteIOSAppDelegate: failed to register for remote notifications: \(error.localizedDescription)")
    }
}
