// CatppuccinMocha.swift
// Drift — Catppuccin Mocha color tokens adapted for glass/vibrancy.
// UI code references these tokens exclusively.

import SwiftUI

// MARK: - Color Tokens

extension Color {
    // Text — high contrast for readability
    static let cmTextPrimary   = Color(hex: "#eff1f5")  // near-white
    static let cmTextSecondary = Color(hex: "#bac2de")
    static let cmTextTertiary  = Color(hex: "#7f849c")

    // Accent & Semantic
    static let cmAccent  = Color(hex: "#89b4fa")
    static let cmGreen   = Color(hex: "#a6e3a1")
    static let cmWarning = Color(hex: "#f9e2af")
    static let cmError   = Color(hex: "#f38ba8")
    static let cmMauve   = Color(hex: "#cba6f7")

    // Surfaces — opaque layers for clear visual hierarchy
    static let cmBase          = Color(hex: "#11111b")  // deepest — sidebar, window chrome
    static let cmBackground    = Color(hex: "#1e1e2e")  // main content area
    static let cmSurface       = Color(hex: "#313244")  // cards, elevated content
    static let cmSurfaceRaised = Color(hex: "#45475a")  // interactive hover states
    static let cmBorder        = Color(hex: "#45475a")  // visible borders

    // Interactive
    static let cmHover    = Color.white.opacity(0.06)
    static let cmSelected = Color.white.opacity(0.10)
}

// MARK: - Hex initializer

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red:   Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Typography

enum CMFont {
    static let sectionHeader = Font.system(size: 11, weight: .semibold)
    static let itemTitle     = Font.system(size: 12, weight: .medium)
    static let itemSubtitle  = Font.system(size: 11, weight: .regular)
    static let body          = Font.system(size: 13, weight: .regular)
    static let heading       = Font.system(size: 15, weight: .semibold)
    static let mono          = Font.system(size: 11, weight: .medium, design: .monospaced)
    static let monoBody      = Font.system(size: 12, weight: .regular, design: .monospaced)
    static let timerLarge    = Font.system(size: 28, weight: .light, design: .monospaced)
}

/// Standard tracking for section headers — use `.tracking(CMTracking.header)` at call sites.
enum CMTracking {
    static let header: CGFloat = 0.7
}

// MARK: - Spacing

enum CMSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
}

// MARK: - Animation

extension Animation {
    static let cmDefault = Animation.easeOut(duration: 0.2)
}
