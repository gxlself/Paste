// CustomType.swift
// Paste-Shared
//
// User-defined category that can be manually assigned to clipboard items.
// Compiled into the Paste, Paste-iOS, and Paste-Keyboard targets.

import Foundation

struct CustomType: Codable, Identifiable, Equatable, Hashable {
    let id: String
    var name: String

    init(id: String = UUID().uuidString, name: String) {
        self.id = id
        self.name = name
    }
}
