//
//  Theme.swift
//  QuietWall
//
//  Central design system: the dark indigo-acoustic palette (adaptive light/dark),
//  gradients, glows, typography, spacing tokens and cached formatters.
//  Dark values are the product's signature look; light is a tasteful variant.
//  All APIs used here are iOS 14.0 safe.
//

import SwiftUI
import UIKit

// MARK: - Dynamic color helper

extension Color {
    /// Builds a color that adapts to the active interface style.
    /// `preferredColorScheme` (set from Settings) flips these automatically.
    static func dynamic(light: UInt, dark: UInt) -> Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }

    init(hex: UInt, alpha: Double = 1.0) {
        self = Color(UIColor(hex: hex, alpha: alpha))
    }
}

extension UIColor {
    convenience init(hex: UInt, alpha: Double = 1.0) {
        let r = CGFloat((hex & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((hex & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(hex & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: CGFloat(alpha))
    }
}

// MARK: - Theme namespace

enum Theme {

    // Backgrounds (dark = spec indigo-acoustic; light = soft indigo)
    static let bgTop      = Color.dynamic(light: 0xF4F2FB, dark: 0x110F1C) // base
    static let bgBottom   = Color.dynamic(light: 0xFFFFFF, dark: 0x0A0814) // depth
    static let bgSoft     = Color.dynamic(light: 0xECE9F8, dark: 0x181527) // soft panel
    static let surface    = Color.dynamic(light: 0xFFFFFF, dark: 0x1E1B33) // cards
    static let surfaceAlt = Color.dynamic(light: 0xF0EDFA, dark: 0x272240) // hover/inputs
    static let stroke     = Color.dynamic(light: 0xDAD4EE, dark: 0x353060) // border

    // Text
    static let textPrimary   = Color.dynamic(light: 0x1E1B33, dark: 0xEFEAFF)
    static let textSecondary = Color.dynamic(light: 0x5B5377, dark: 0xB9B0DC)
    static let textDisabled  = Color.dynamic(light: 0x9A93B8, dark: 0x6E6797)
    static let textOnAccent  = Color(hex: 0x0F0A1F) // deep ink on the violet primary

    // Brand / accents
    static let accent     = Color.dynamic(light: 0x7C3AED, dark: 0x8B5CF6) // primary violet
    static let accentDeep = Color.dynamic(light: 0x6D28D9, dark: 0x7C3AED) // active
    static let highlight  = Color.dynamic(light: 0x8B5CF6, dark: 0xA78BFA) // soft highlight
    static let action     = Color.dynamic(light: 0x7C3AED, dark: 0x8B5CF6) // alias for CTAs
    static let actionDeep = Color.dynamic(light: 0x6D28D9, dark: 0x7C3AED)

    // Wave accents (sound visualization)
    static let wave       = Color.dynamic(light: 0x0891B2, dark: 0x22D3EE) // cyan attenuation
    static let wave2      = Color.dynamic(light: 0x2563EB, dark: 0x60A5FA) // blue secondary

    // Semantic / acoustic statuses
    static let success = Color.dynamic(light: 0x059669, dark: 0x34D399) // target met
    static let warning = Color.dynamic(light: 0xD97706, dark: 0xF59E0B) // weak point
    static let danger  = Color.dynamic(light: 0xDC2626, dark: 0xEF4444) // bridge / fail
    static let info    = Color.dynamic(light: 0x2563EB, dark: 0x60A5FA)

    // Glows (dark-tuned; subtle in light)
    static let violetGlow = Color.dynamic(light: 0x8B5CF6, dark: 0x8B5CF6).opacity(0.35)
    static let waveGlow   = Color.dynamic(light: 0x22D3EE, dark: 0x22D3EE).opacity(0.25)

    // Gradients
    static var background: LinearGradient {
        LinearGradient(colors: [bgTop, bgBottom],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var accentGradient: LinearGradient {
        LinearGradient(colors: [accent, accentDeep],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var actionGradient: LinearGradient {
        LinearGradient(colors: [highlight, accentDeep],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var waveGradient: LinearGradient {
        LinearGradient(colors: [wave, wave2],
                       startPoint: .leading, endPoint: .trailing)
    }

    // Spacing scale
    enum Space {
        static let xs: CGFloat = 6
        static let s: CGFloat = 10
        static let m: CGFloat = 16
        static let l: CGFloat = 22
        static let xl: CGFloat = 32
    }

    // Corner radii
    enum Radius {
        static let s: CGFloat = 10
        static let m: CGFloat = 16
        static let l: CGFloat = 22
        static let pill: CGFloat = 100
    }

    // Typography (system fonts with rounded/weighted styling)
    static func title(_ size: CGFloat = 26) -> Font { .system(size: size, weight: .bold, design: .rounded) }
    static func heading(_ size: CGFloat = 19) -> Font { .system(size: size, weight: .semibold, design: .rounded) }
    static func body(_ size: CGFloat = 15) -> Font { .system(size: size, weight: .regular, design: .rounded) }
    static func mono(_ size: CGFloat = 13) -> Font { .system(size: size, weight: .semibold, design: .monospaced) }
    static func caption(_ size: CGFloat = 12) -> Font { .system(size: size, weight: .medium, design: .rounded) }
}

// MARK: - Formatters (cached; .formatted() is iOS 15+, so we use these everywhere)

enum Formatters {
    static func currency(_ value: Double, code: String, symbol: String) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = code
        f.currencySymbol = symbol
        f.maximumFractionDigits = value.rounded() == value ? 0 : 2
        return f.string(from: NSNumber(value: value)) ?? "\(symbol)\(Int(value))"
    }

    static func decimal(_ value: Double, digits: Int = 1) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = digits
        f.minimumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func percent(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    private static let medium: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none; return f
    }()
    private static let shortDay: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f
    }()
    private static let dayTime: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d, HH:mm"; return f
    }()

    static func date(_ d: Date) -> String { medium.string(from: d) }
    static func dayMonth(_ d: Date) -> String { shortDay.string(from: d) }
    static func dateTime(_ d: Date) -> String { dayTime.string(from: d) }

    static func relativeDays(to date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()),
                                                   to: Calendar.current.startOfDay(for: date)).day ?? 0
        if days == 0 { return "Today" }
        if days > 0 { return "in \(days)d" }
        return "\(-days)d ago"
    }
}

// MARK: - Keyboard dismissal (no @FocusState on iOS 14)

extension UIApplication {
    func dismissKeyboard() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
