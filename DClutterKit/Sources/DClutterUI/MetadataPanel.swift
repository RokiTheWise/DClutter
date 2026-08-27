//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import SwiftUI
import DClutterCore

/// dclutter-design.md §1 — the "instrumentation" voice: uppercase SF Mono
/// labels in tertiary grey, SF Pro Text values in primary. Monospaced
/// labels also align on a column for free, no Grid needed.
struct MetadataPanel: View {
    let candidate: FileCandidate

    /// Always the same four rows, in the same order — an absent source
    /// renders as a dash rather than collapsing the row. Design spec §4:
    /// the card must not change height between files, or the queue jitters
    /// on every advance.
    private var rows: [(String, String)] {
        [
            ("SIZE", Self.byteFormatter.string(fromByteCount: candidate.bytes)),
            ("LAST OPENED", candidate.lastOpened.map(Self.dateFormatter.string) ?? "Never"),
            ("FROM", candidate.sourceURL?.host ?? "—"),
            ("ADDED", Self.dateFormatter.string(from: candidate.created)),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.unit * 2) {
            ForEach(rows, id: \.0) { label, value in
                HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.small) {
                    Text(label)
                        .font(.system(size: 11, design: .monospaced))
                        .kerning(0.5)
                        .foregroundStyle(DesignTokens.ColorToken.textTertiary)
                        .frame(width: 90, alignment: .leading)
                    Text(value)
                        .font(.system(size: 13))
                        .foregroundStyle(DesignTokens.ColorToken.textPrimary)
                }
            }
        }
    }

    private static let byteFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM yyyy"
        return f
    }()
}
