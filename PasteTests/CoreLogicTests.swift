//
//  CoreLogicTests.swift
//  PasteTests
//
//  Unit tests for pure, UI-free logic.
//

import Testing
import AppKit
@testable import Paste

struct ContentRulesTests {
    private func text(_ value: String?) -> ClipboardContent {
        ClipboardContent(type: .text, plainText: value, rtfData: nil, imageData: nil,
                         filePaths: nil, sourceApp: nil, contentHash: "h")
    }

    @Test func ignoresEmptyAndWhitespaceText() {
        #expect(ContentRules.shouldIgnore(content: text(nil)))
        #expect(ContentRules.shouldIgnore(content: text("")))
        #expect(ContentRules.shouldIgnore(content: text("  \n\t ")))
    }

    @Test func keepsRealText() {
        #expect(!ContentRules.shouldIgnore(content: text("hello")))
        #expect(!ContentRules.shouldIgnore(content: text("  x  ")))
    }

    @Test func neverIgnoresNonTextContent() {
        let image = ClipboardContent(type: .image, plainText: nil, rtfData: nil, imageData: Data([1]),
                                     filePaths: nil, sourceApp: nil, contentHash: "i")
        #expect(!ContentRules.shouldIgnore(content: image))
    }
}

struct ColorCodeHelperTests {
    private func rgb(_ color: NSColor?) -> [Int]? {
        guard let c = color?.usingColorSpace(.sRGB) else { return nil }
        return [c.redComponent, c.greenComponent, c.blueComponent].map { Int(($0 * 255).rounded()) }
    }

    @Test func parsesHex() {
        #expect(rgb(ColorCodeHelper.color(from: "#FF8000")) == [255, 128, 0])
        #expect(rgb(ColorCodeHelper.color(from: "  #00f  ")) == [0, 0, 255])
    }

    @Test func parsesRGBFunction() {
        #expect(rgb(ColorCodeHelper.color(from: "rgb(10, 20, 30)")) == [10, 20, 30])
    }

    @Test func rejectsNonColorsAndMultiline() {
        #expect(ColorCodeHelper.color(from: "hello") == nil)
        #expect(ColorCodeHelper.color(from: "#FF8000\nextra") == nil)
        #expect(ColorCodeHelper.color(from: "") == nil)
        #expect(ColorCodeHelper.color(from: "#GGGGGG") == nil)
    }

    @Test func contrastPicksReadableText() {
        #expect(ColorCodeHelper.contrastingTextColor(for: .black) == .white)
        #expect(ColorCodeHelper.contrastingTextColor(for: .white) == .black)
    }
}

@MainActor
struct MenuBarIconTests {
    @Test func iconIsTemplateAndSized() {
        let normal = AppLogoCache.menuBarIcon(side: 18, paused: false)
        let paused = AppLogoCache.menuBarIcon(side: 18, paused: true)
        #expect(normal.isTemplate && paused.isTemplate)
        #expect(normal.size == NSSize(width: 18, height: 18))
    }
}

struct UpdateVersionTests {
    @Test func comparesDottedVersionsNumerically() {
        #expect(UpdateChecker.isNewer("v1.11.0", than: "1.10.2"))
        #expect(UpdateChecker.isNewer("1.10.10", than: "1.10.9"))
        #expect(UpdateChecker.isNewer("2.0", than: "1.99.99"))
    }

    @Test func equalOrOlderIsNotNewer() {
        #expect(!UpdateChecker.isNewer("1.10.2", than: "1.10.2"))
        #expect(!UpdateChecker.isNewer("v1.10", than: "1.10.0"))
        #expect(!UpdateChecker.isNewer("1.9.0", than: "1.10.0"))
    }
}
