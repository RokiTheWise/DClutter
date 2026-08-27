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
    /// Double-click, not single: §6 reserves click-drag-upward for
    /// move-to-destination in M4, and a single-click action would
    /// collide with the start of that gesture.
    var onOpen: (() -> Void)?
    /// Live swipe position, -1...1. Applied here rather than by the parent
    /// so a departing card keeps the offset it was rendered with: driven
    /// from shared state in the parent, the outgoing card would re-read the
    /// reset value, snap back to centre and only then play its exit.
    var swipeOffset: CGFloat = 0
    var onReveal: (() -> Void)?
    var onRename: (() -> Void)?
    var onCopyName: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.large) {
            PreviewPane(candidate: candidate, focused: $previewFocused)

            // Two lines are always reserved, and the chip row below always
            // occupies a row's height even when empty. Design spec §4: the
            // card must not resize between files, or the queue jitters on
            // every advance.
            Text(candidate.url.lastPathComponent)
                .font(.system(size: 22, weight: .regular))
                .kerning(-0.4)
                .foregroundStyle(DesignTokens.ColorToken.textPrimary)
                .lineLimit(2, reservesSpace: true)

            let chips = ChipBuilder.chips(for: candidate, in: context)
            HStack(spacing: DesignTokens.Spacing.small) {
                if chips.isEmpty {
                    Chip(text: " ").hidden()
                } else {
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
        // Design §4 keeps the card centred with generous margin — the
        // emptiness is deliberate, one decision at a time. But 480 was
        // tuned for the 520-wide minimum and looks marooned on a large
        // display, so it may grow a little before the margin takes over.
        .frame(maxWidth: 620)
        .offset(x: swipeOffset * 90)
        .rotationEffect(.degrees(swipeOffset * 2))
        .opacity(1 - min(abs(swipeOffset) * 0.35, 0.35))
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { onOpen?() }
        // Right-click reaches the Finder vocabulary people already know.
        // It is a different button from the left-click-drag §6 reserves for
        // move-to-destination, so the two cannot collide.
        .contextMenu {
            Button("Open") { onOpen?() }
            Button("Reveal in Finder") { onReveal?() }
            Divider()
            Button("Rename…") { onRename?() }
            Button("Copy Name") { onCopyName?() }
        }
        .help("Double-click to open this file")
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
