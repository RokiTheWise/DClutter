//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import SwiftUI
import AppKit
import DClutterCore

/// Which key decided the previously-shown card, so the outgoing card can
/// translate in that direction per dclutter-design.md §7. `skip` has no
/// left/right meaning, so it just fades.
enum DecisionDirection: Equatable {
    case keep
    case stage
    case skip
}

/// dclutter-design.md §3–4: flat, 20pt-radius card — "the signature move."
/// No drop shadow; depth comes from surface alternation and the hairline.
struct CardView: View {
    let candidate: FileCandidate
    let context: QueueContext
    @Binding var previewFocused: Bool
    var lastDecision: DecisionDirection?

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
        .transition(cardTransition)
    }

    /// §7: outgoing card translates in the decision's direction and fades;
    /// incoming card rises and fades in. Respects reduce-motion by
    /// dropping to a plain crossfade — no directional translation.
    private var cardTransition: AnyTransition {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            return .opacity
        }
        let insertion: AnyTransition = .move(edge: .bottom).combined(with: .opacity)
        switch lastDecision {
        case .keep:
            return .asymmetric(insertion: insertion, removal: .move(edge: .trailing).combined(with: .opacity))
        case .stage:
            return .asymmetric(insertion: insertion, removal: .move(edge: .leading).combined(with: .opacity))
        case .skip, .none:
            return .asymmetric(insertion: insertion, removal: .opacity)
        }
    }
}
