//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import SwiftUI
import DClutterPlatform

/// The three destination bins (§6).
///
/// Hidden at rest. As a drag rises past a small threshold the bins slide
/// down from the top edge and gain opacity **in proportion to the drag** —
/// §6 asks for a shelf that "should feel attached to the drag, not
/// triggered by it", which is why every value here is a function of
/// `revealed` rather than a fixed animation.
///
/// Exactly one bin is ever highlighted; §6 forbids an ambiguous middle
/// state. With zero destinations configured a single "Choose a folder…"
/// bin appears instead of nothing, so the feature is discoverable without
/// a tutorial.
struct DestinationShelf: View {
    let destinations: [Destination]
    /// 0 at rest, 1 fully revealed.
    let revealed: CGFloat
    /// Index of the bin under the pointer, or nil.
    let highlighted: Int?
    let onChooseFolder: () -> Void

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.medium) {
            if destinations.isEmpty {
                bin(
                    label: "Choose a folder…",
                    systemImage: "folder.badge.plus",
                    isHighlighted: highlighted == 0
                )
                .onTapGesture(perform: onChooseFolder)
            } else {
                ForEach(Array(destinations.enumerated()), id: \.element.id) { index, destination in
                    bin(
                        label: destination.name,
                        systemImage: "folder",
                        isHighlighted: highlighted == index,
                        shortcut: "\(index + 1)"
                    )
                }
                // Adding a folder is part of the same row rather than a
                // separate setting, so filling the three bins is something
                // you do while triaging instead of before it.
                if destinations.count < DestinationStore.maximumDestinations {
                    bin(
                        label: "Add folder…",
                        systemImage: "folder.badge.plus",
                        isHighlighted: highlighted == destinations.count,
                        shortcut: "⌘N"
                    )
                    .onTapGesture(perform: onChooseFolder)
                }
            }
        }
        .padding(DesignTokens.Spacing.large)
        // Attached to the drag: both the slide and the fade track it.
        .offset(y: -40 * (1 - revealed))
        .opacity(Double(revealed))
        .allowsHitTesting(revealed > 0.99)
    }

    private func bin(
        label: String,
        systemImage: String,
        isHighlighted: Bool,
        shortcut: String? = nil
    ) -> some View {
        VStack(spacing: DesignTokens.Spacing.unit) {
            Image(systemName: systemImage)
                .font(.system(size: 18))
            Text(label)
                .font(.system(size: 12))
                .lineLimit(1)
            if let shortcut {
                Text(shortcut)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(DesignTokens.ColorToken.textTertiary)
            }
        }
        .frame(width: 132, height: 76)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.bin)
                .fill(DesignTokens.ColorToken.cardSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.bin)
                .strokeBorder(
                    isHighlighted
                        ? DesignTokens.ColorToken.textPrimary
                        : DesignTokens.ColorToken.hairline,
                    lineWidth: isHighlighted ? 2 : 1
                )
        )
        .foregroundStyle(
            isHighlighted
                ? DesignTokens.ColorToken.textPrimary
                : DesignTokens.ColorToken.textSecondary
        )
    }
}
