//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import SwiftUI

/// The DClutter mark: a fanned stack of cards with a document on the front
/// one — the app's own gesture, drawn.
///
/// Redrawn in SwiftUI rather than shipped as a bitmap so it stays sharp at
/// any size and follows the window's foreground colour, which a flat PNG in
/// the ribbon would not. The app icon uses the full-colour original.
struct BrandMark: View {
    var size: CGFloat = 18

    private let cards: [(rotation: Double, offset: CGFloat, opacity: Double)] = [
        (-15, -0.10, 0.35),
        (-7, -0.02, 0.55),
        (8, 0.07, 1.00),
    ]

    var body: some View {
        ZStack {
            ForEach(Array(cards.enumerated()), id: \.offset) { _, card in
                RoundedRectangle(cornerRadius: size * 0.13, style: .continuous)
                    .strokeBorder(lineWidth: max(size * 0.055, 1))
                    .frame(width: size * 0.60, height: size * 0.78)
                    .rotationEffect(.degrees(card.rotation))
                    .offset(x: size * card.offset)
                    .opacity(card.opacity)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("DClutter")
    }
}
