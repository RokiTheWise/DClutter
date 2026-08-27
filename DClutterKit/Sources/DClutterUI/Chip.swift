//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import SwiftUI
import DClutterCore

/// dclutter-design.md §5 — grey, no icons, no accent color. Information,
/// not warnings.
struct Chip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .kerning(0.1)
            .padding(.horizontal, DesignTokens.Spacing.small)
            .padding(.vertical, 3)
            .background(DesignTokens.ColorToken.textPrimary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.chip))
            .foregroundStyle(DesignTokens.ColorToken.textSecondary)
    }
}

enum ChipBuilder {
    /// Capped at 3, per the design spec — wrapping to a second row is a
    /// layout concern for the caller, not this builder.
    static func chips(for candidate: FileCandidate, in context: QueueContext) -> [String] {
        var result: [String] = []
        let dupCount = context.duplicateCount(for: candidate)
        if dupCount > 1 { result.append("\(dupCount) copies") }
        if candidate.lastOpened == nil && candidate.sourceURL != nil {
            result.append("never opened")
        }
        if context.isExtractedArchive(candidate) { result.append("already extracted") }
        return Array(result.prefix(3))
    }
}
