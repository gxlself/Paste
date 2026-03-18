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
        guard let task = SecTaskCreateFromSelf(nil) else { return false }
        let entitlement = "com.apple.developer.icloud-services" as CFString
        let value = SecTaskCopyValueForEntitlement(task, entitlement, nil)
        return value != nil
    }
}

