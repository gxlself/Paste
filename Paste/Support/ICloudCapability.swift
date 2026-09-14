//
//  ICloudCapability.swift
//  Paste
//
//  Detect whether current signing has iCloud entitlements.
//

import Foundation
import Security

enum ICloudCapability {
    static func isSupportedBySigning() -> Bool {
        entitlement("com.apple.developer.icloud-services") != nil
    }

    /// Which CloudKit database this build talks to.
    ///
    /// CloudKit keeps Development and Production completely separate: a development-signed build
    /// and a TestFlight/App Store build of the same app never see each other's records. The
    /// environment follows the APS entitlement, which automatic signing rewrites to match the
    /// provisioning profile — so a Release build signed with a development profile silently ends
    /// up on Development.
    enum Environment: String {
        case development
        case production
        case unknown
    }

    static var environment: Environment {
        guard let value = entitlement("com.apple.developer.aps-environment") as? String else {
            return .unknown
        }
        return Environment(rawValue: value) ?? .unknown
    }

    private static func entitlement(_ key: String) -> CFTypeRef? {
        guard let task = SecTaskCreateFromSelf(nil) else { return nil }
        return SecTaskCopyValueForEntitlement(task, key as CFString, nil)
    }
}

