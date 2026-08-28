//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import SwiftUI

/// Visual spec: dclutter-design.md. Semantic system colors only — no fixed
/// hex values, so light/dark/increased-contrast all adapt for free.
enum DesignTokens {
    enum ColorToken {
        /// Design §3 says depth comes from "surface alternation and
        /// hairlines" — but `windowBackgroundColor` and
        /// `controlBackgroundColor` resolve to the *same* value in both
        /// appearances (#FFFFFF light, #1E1E1E dark), so there was no
        /// alternation at all and the hairline was doing all the work.
        ///
        /// These separate the two by a few percent, derived from the system
        /// colours rather than hardcoded, so increased-contrast and any
        /// future palette change still carry through.
        static let surface = Color(nsColor: NSColor(name: nil) { appearance in
            // Light: step the page down, so a white card sits on it the way
            // macOS documents do. Dark: leave the page and lift the card.
            appearance.isDark
                ? .windowBackgroundColor
                : NSColor.windowBackgroundColor.blended(withFraction: 0.055, of: .black)
                    ?? .windowBackgroundColor
        })

        static let cardSurface = Color(nsColor: NSColor(name: nil) { appearance in
            appearance.isDark
                ? NSColor.controlBackgroundColor.blended(withFraction: 0.055, of: .white)
                    ?? .controlBackgroundColor
                : .controlBackgroundColor
        })
        static let hairline = Color(nsColor: .separatorColor)
        static let textPrimary = Color(nsColor: .labelColor)
        static let textSecondary = Color(nsColor: .secondaryLabelColor)
        static let textTertiary = Color(nsColor: .tertiaryLabelColor)

        /// Warm amber-red — reads as "consequential," not alarm-red.
        /// Trash-only; never used for chips or informational UI.
        static let consequence = Color(
            light: Color(red: 0.79, green: 0.31, blue: 0.16),
            dark: Color(red: 0.93, green: 0.48, blue: 0.31)
        )
    }

    enum Radius {
        static let chip: CGFloat = 6
        static let preview: CGFloat = 10
        static let card: CGFloat = 20
        static let bin: CGFloat = 14
        static let sheet: CGFloat = 12
    }

    enum Spacing {
        static let unit: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xLarge: CGFloat = 24
        static let xxLarge: CGFloat = 32
        static let cardMargin: CGFloat = 48
    }
}

private extension NSAppearance {
    var isDark: Bool { bestMatch(from: [.aqua, .darkAqua]) == .darkAqua }
}

private extension Color {
    init(light: Color, dark: Color) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(dark) : NSColor(light)
        })
    }
}
