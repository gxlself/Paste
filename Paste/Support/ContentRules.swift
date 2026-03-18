//
//  ContentRules.swift
//  Paste
//
//  Ignore only blank clipboard content (empty, whitespace-only, newline-only).
//

import Foundation

enum ContentRules {
    /// Ignores content that is empty, whitespace-only, or newline-only. No sensitive/auto-generated rules.
    static func shouldIgnore(content: ClipboardContent) -> Bool {
        guard content.type == .text else { return false }
        guard let text = content.plainText, !text.isEmpty else { return true }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty
    }
}
