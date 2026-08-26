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

    private var rows: [(String, String)] {
        var result = [("SIZE", Self.byteFormatter.string(fromByteCount: candidate.bytes))]
        result.append(("LAST OPENED", candidate.lastOpened.map(Self.dateFormatter.string) ?? "Never"))
        if let host = candidate.sourceURL?.host {
            result.append(("FROM", host))
        }
        result.append(("ADDED", Self.dateFormatter.string(from: candidate.created)))
        return result
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
