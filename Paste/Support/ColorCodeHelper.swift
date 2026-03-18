//
//  ColorCodeHelper.swift
//  Paste
//
//  Parses single-line CSS color strings and returns NSColor for card styling.
//

import AppKit
import Foundation

enum ColorCodeHelper {

    /// Returns NSColor only when the entire content is exactly a color code (no other text, no extra lines).
    static func color(from string: String) -> NSColor? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("\n") else { return nil }
        if trimmed.hasPrefix("#") {
            return parseHex(trimmed)
        }
        if trimmed.lowercased().hasPrefix("rgb") {
            return parseRgbRgba(trimmed)
        }
        if trimmed.lowercased().hasPrefix("hsl") {
            return parseHslHsla(trimmed)
        }
        return nil
    }

    /// Contrasting color (white or black) for use on the given background.
    static func contrastingTextColor(for backgroundColor: NSColor) -> NSColor {
        let luminance = luminanceOf(backgroundColor)
        return luminance > 0.5 ? .black : .white
    }

    private static func luminanceOf(_ c: NSColor) -> Double {
        let rgb = c.usingColorSpace(.sRGB) ?? c
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        rgb.getRed(&r, green: &g, blue: &b, alpha: &a)
        return 0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b)
    }

    private static func parseHex(_ s: String) -> NSColor? {
        var hex = s.dropFirst()
        if hex.hasPrefix("0x") { hex = hex.dropFirst(2) }
        let chars = [Character](hex)
        switch chars.count {
        case 3:
            guard let r = byteFromHex2(chars[0], chars[0]),
                  let g = byteFromHex2(chars[1], chars[1]),
                  let b = byteFromHex2(chars[2], chars[2]) else { return nil }
            return NSColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
        case 4:
            guard let r = byteFromHex2(chars[0], chars[0]),
                  let g = byteFromHex2(chars[1], chars[1]),
                  let b = byteFromHex2(chars[2], chars[2]),
                  let a = byteFromHex2(chars[3], chars[3]) else { return nil }
            return NSColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
        case 6:
            guard let r = byteFromHex2(chars[0], chars[1]),
                  let g = byteFromHex2(chars[2], chars[3]),
                  let b = byteFromHex2(chars[4], chars[5]) else { return nil }
            return NSColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
        case 8:
            guard let r = byteFromHex2(chars[0], chars[1]),
                  let g = byteFromHex2(chars[2], chars[3]),
                  let b = byteFromHex2(chars[4], chars[5]),
                  let a = byteFromHex2(chars[6], chars[7]) else { return nil }
            return NSColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
        default:
            return nil
        }
    }

    private static func byteFromHex2(_ c1: Character, _ c2: Character) -> UInt8? {
        let h = hexDigit(c1), l = hexDigit(c2)
        guard let h = h, let l = l else { return nil }
        return h << 4 | l
    }

    private static func hexDigit(_ c: Character) -> UInt8? {
        switch c {
        case "0"..."9": return UInt8(c.asciiValue! - 48)
        case "a"..."f": return UInt8(c.asciiValue! - 97 + 10)
        case "A"..."F": return UInt8(c.asciiValue! - 65 + 10)
        default: return nil
        }
    }

    private static func parseRgbRgba(_ s: String) -> NSColor? {
        let lower = s.lowercased()
        let inner: String
        if lower.hasPrefix("rgba(") {
            inner = String(s.dropFirst(5).dropLast())
        } else if lower.hasPrefix("rgb(") {
            inner = String(s.dropFirst(4).dropLast())
        } else {
            return nil
        }
        let parts = inner.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 3 || parts.count == 4 else { return nil }
        func parseComponent(_ str: String) -> CGFloat? {
            let t = str.trimmingCharacters(in: .whitespaces)
            if t.hasSuffix("%") {
                guard let v = Double(t.dropLast()) else { return nil }
                return CGFloat(v / 100)
            }
            guard let v = Double(t) else { return nil }
            if v > 1 && v <= 255 { return CGFloat(v / 255) }
            return CGFloat(max(0, min(1, v)))
        }
        guard let r = parseComponent(parts[0]),
              let g = parseComponent(parts[1]),
              let b = parseComponent(parts[2]) else { return nil }
        let a: CGFloat = parts.count == 4 ? (parseComponent(parts[3]) ?? 1) : 1
        return NSColor(red: r, green: g, blue: b, alpha: a)
    }

    private static func parseHslHsla(_ s: String) -> NSColor? {
        let lower = s.lowercased()
        let inner: String
        if lower.hasPrefix("hsla(") {
            inner = String(s.dropFirst(5).dropLast())
        } else if lower.hasPrefix("hsl(") {
            inner = String(s.dropFirst(4).dropLast())
        } else {
            return nil
        }
        let parts = inner.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 3 || parts.count == 4 else { return nil }
        guard let h = Double(parts[0].replacingOccurrences(of: "deg", with: "")),
              let sVal = Double(parts[1].replacingOccurrences(of: "%", with: "")),
              let lVal = Double(parts[2].replacingOccurrences(of: "%", with: "")) else { return nil }
        let s = CGFloat(max(0, min(100, sVal)) / 100)
        let l = CGFloat(max(0, min(100, lVal)) / 100)
        let a: CGFloat = parts.count == 4 ? (CGFloat(Double(parts[3].replacingOccurrences(of: "%", with: "")) ?? 1)) : 1
        return nsColorFromHSL(h: h, s: s, l: l, a: a)
    }

    private static func nsColorFromHSL(h: Double, s: CGFloat, l: CGFloat, a: CGFloat) -> NSColor {
        let hue = (h.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / 360
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        if s == 0 {
            r = l; g = l; b = l
        } else {
            let q = l < 0.5 ? l * (1 + s) : l + s - l * s
            let p = 2 * l - q
            r = hueToRgb(p: p, q: q, t: hue + 1/3)
            g = hueToRgb(p: p, q: q, t: hue)
            b = hueToRgb(p: p, q: q, t: hue - 1/3)
        }
        return NSColor(red: r, green: g, blue: b, alpha: a)
    }

    private static func hueToRgb(p: CGFloat, q: CGFloat, t: CGFloat) -> CGFloat {
        var t = t
        if t < 0 { t += 1 }
        if t > 1 { t -= 1 }
        if t < 1/6 { return p + (q - p) * 6 * t }
        if t < 1/2 { return q }
        if t < 2/3 { return p + (q - p) * (2/3 - t) * 6 }
        return p
    }
}
