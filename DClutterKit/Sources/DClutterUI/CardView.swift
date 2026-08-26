//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import SwiftUI
import DClutterCore

/// dclutter-design.md §3–4: flat, 20pt-radius card — "the signature move."
/// No drop shadow; depth comes from surface alternation and the hairline.
struct CardView: View {
    let candidate: FileCandidate
    let context: QueueContext
    @Binding var previewFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.large) {
            PreviewPane(candidate: candidate, focused: $previewFocused)

            Text(candidate.url.lastPathComponent)
                .font(.system(size: 22, weight: .regular))
                .kerning(-0.4)
                .foregroundStyle(DesignTokens.ColorToken.textPrimary)
                .lineLimit(2)

            let chips = ChipBuilder.chips(for: candidate, in: context)
            if !chips.isEmpty {
                HStack(spacing: DesignTokens.Spacing.small) {
                    ForEach(chips, id: \.self) { Chip(text: $0) }
                }
            }

            MetadataPanel(candidate: candidate)
        }
        .padding(DesignTokens.Spacing.xLarge)
        .background(DesignTokens.ColorToken.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.card)
                .strokeBorder(DesignTokens.ColorToken.hairline)
        )
        .frame(maxWidth: 480)
        .id(candidate.id) // forces a fresh identity so .transition fires on advance
        .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .opacity
        ))
    }
}
