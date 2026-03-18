//
//  RegexPresets.swift
//  Paste
//
//  Predefined regex patterns for developer tag / quick paste.
//

import Foundation

struct RegexPreset: Identifiable, Equatable {
    let id: UUID
    let nameKey: String
    let pattern: String

    var name: String { String(localized: String.LocalizationValue(nameKey)) }

    static let all: [RegexPreset] = [
        RegexPreset(id: UUID(uuidString: "E621E1B8-7B2A-4C9D-8F3E-1A2B3C4D5E61")!, nameKey: "regex.preset.email", pattern: #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#),
        RegexPreset(id: UUID(uuidString: "E621E1B8-7B2A-4C9D-8F3E-1A2B3C4D5E62")!, nameKey: "regex.preset.url", pattern: #"https?://[^\s]+"#),
        RegexPreset(id: UUID(uuidString: "E621E1B8-7B2A-4C9D-8F3E-1A2B3C4D5E63")!, nameKey: "regex.preset.phone", pattern: #"(\+?\d{1,3}[-.\s]?)?\(?\d{2,4}\)?[-.\s]?\d{3,4}[-.\s]?\d{3,4}"#),
        RegexPreset(id: UUID(uuidString: "E621E1B8-7B2A-4C9D-8F3E-1A2B3C4D5E64")!, nameKey: "regex.preset.uuid", pattern: #"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"#),
        RegexPreset(id: UUID(uuidString: "E621E1B8-7B2A-4C9D-8F3E-1A2B3C4D5E65")!, nameKey: "regex.preset.ipv4", pattern: #"\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b"#),
        RegexPreset(id: UUID(uuidString: "E621E1B8-7B2A-4C9D-8F3E-1A2B3C4D5E66")!, nameKey: "regex.preset.integer", pattern: #"-?\d+"#),
        RegexPreset(id: UUID(uuidString: "E621E1B8-7B2A-4C9D-8F3E-1A2B3C4D5E67")!, nameKey: "regex.preset.float", pattern: #"-?\d+\.?\d*(?:[eE][+-]?\d+)?"#),
        RegexPreset(id: UUID(uuidString: "E621E1B8-7B2A-4C9D-8F3E-1A2B3C4D5E68")!, nameKey: "regex.preset.chinese", pattern: #"[\u4e00-\u9fff]+"#),
        RegexPreset(id: UUID(uuidString: "E621E1B8-7B2A-4C9D-8F3E-1A2B3C4D5E69")!, nameKey: "regex.preset.date", pattern: #"\d{4}[-/]\d{2}[-/]\d{2}"#),
        RegexPreset(id: UUID(uuidString: "E621E1B8-7B2A-4C9D-8F3E-1A2B3C4D5E6A")!, nameKey: "regex.preset.hexColor", pattern: #"#(?:[0-9a-fA-F]{3}){1,2}"#),
        RegexPreset(id: UUID(uuidString: "E621E1B8-7B2A-4C9D-8F3E-1A2B3C4D5E6B")!, nameKey: "regex.preset.semver", pattern: #"\d+\.\d+\.\d+(?:-[a-zA-Z0-9.-]+)?"#),
        RegexPreset(id: UUID(uuidString: "E621E1B8-7B2A-4C9D-8F3E-1A2B3C4D5E6C")!, nameKey: "regex.preset.jsonString", pattern: #""(?:[^"\\]|\\.)*""#),
        RegexPreset(id: UUID(uuidString: "E621E1B8-7B2A-4C9D-8F3E-1A2B3C4D5E6D")!, nameKey: "regex.preset.whitespace", pattern: #"\s+"#),
        RegexPreset(id: UUID(uuidString: "E621E1B8-7B2A-4C9D-8F3E-1A2B3C4D5E6E")!, nameKey: "regex.preset.htmlTag", pattern: #"<[^>]+>"#),
    ]
}
