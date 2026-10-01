//
//  AppLog.swift
//  Paste
//
//  Unified logging. Messages land in Console.app (subsystem = bundle id) in release builds too,
//  unlike `print`, which is discarded.
//

import os

enum AppLog {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Paste",
        category: "app"
    )

    static func info(_ message: String) { logger.info("\(message, privacy: .public)") }
    static func warning(_ message: String) { logger.warning("\(message, privacy: .public)") }
    static func error(_ message: String) { logger.error("\(message, privacy: .public)") }
}
