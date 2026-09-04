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

    var exit: CardExit {
        switch self {
        case .keep: .right
        case .stage: .left
        case .skip: .fade
        }
    }
}

/// The edge a card leaves toward. Filing has no key of its own in
/// `DecisionDirection` — it is chosen on the shelf, not by a decision key —
/// so exits are named separately from decisions.
enum CardExit: Equatable {
    case right
    case left
    /// Into a destination folder: the shelf is above the card, so the file
    /// goes the way the user just reached.
    case up
    case fade

    /// Direction of travel. Nil for `.fade`, which has none.
    var unitVector: CGSize? {
        switch self {
        case .right: CGSize(width: 1, height: 0)
        case .left: CGSize(width: -1, height: 0)
        case .up: CGSize(width: 0, height: -1)
        case .fade: nil
        }
    }

    /// Where a card that left this way comes back in from.
    var edge: Edge? {
        switch self {
        case .right: .trailing
        case .left: .leading
        case .up: .top
        case .fade: nil
        }
    }
}

/// How the next card arrives.
///
/// Only entrances are expressed as transitions. A view's *removal*
/// transition is fixed when it is inserted — re-rendering it with a
/// different `.transition()` later changes nothing — and a card is
/// inserted long before the user decides where it should go, so an exit
/// direction can never be a transition. Exits are animated explicitly
/// instead, by `exiting`/`exitFraction` below.
enum CardEntrance: Equatable {
    /// Up from below: a new file arriving to be decided.
    case rise
    /// Back in from the edge it left toward, so an undo reads as a rewind
    /// of what just happened rather than as another decision.
    case from(CardExit)
}

/// dclutter-design.md §3–4: flat, 20pt-radius card — "the signature move."
/// No drop shadow; depth comes from surface alternation and the hairline.
struct CardView: View {
    let candidate: FileCandidate
    let context: QueueContext
    var entrance: CardEntrance
    /// Set only on the card currently being animated off-screen.
    var exiting: CardExit?
    /// 0 at rest, 1 fully gone. Driven by the parent so the exit is a plain
    /// animated offset rather than a transition.
    var exitFraction: CGFloat = 0
    /// Double-click opens the file. This replaced focus-to-preview, which
    /// is what people were reaching for in the first place.
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
            PreviewPane(candidate: candidate)

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
        .offset(x: swipeOffset * 90 + exitTravel.width, y: exitTravel.height)
        .rotationEffect(.degrees(swipeOffset * 2))
        .opacity((1 - min(abs(swipeOffset) * 0.35, 0.35)) * (1 - exitFraction))
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { onOpen?() }
        // Right-click reaches the Finder vocabulary people already know.
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

    /// Far enough that the card is clear of any window before the swap.
    private static let exitDistance: CGFloat = 760

    private var exitTravel: CGSize {
        guard let vector = exiting?.unitVector else { return .zero }
        return CGSize(
            width: vector.width * exitFraction * Self.exitDistance,
            height: vector.height * exitFraction * Self.exitDistance
        )
    }

    /// §7: the incoming card rises and fades in, or returns from the edge
    /// it left toward when a decision is undone. Removal is always a plain
    /// fade — by the time a card is removed it has already been animated
    /// off-screen by `exitTravel`, so there is nothing left to see.
    /// Reduce-motion drops the translation entirely.
    private var cardTransition: AnyTransition {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            return .opacity
        }
        let edge: Edge = switch entrance {
        case .rise: .bottom
        case .from(let exit): exit.edge ?? .bottom
        }
        return .asymmetric(
            insertion: .move(edge: edge).combined(with: .opacity),
            removal: .opacity
        )
    }
}
