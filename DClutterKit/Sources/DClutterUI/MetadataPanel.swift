//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import SwiftUI
import DClutterCore

/// dclutter-design.md §1 — the "instrumentation" voice: uppercase SF Mono
/// labels in secondary grey and SF Pro Text values in primary. A two-column
/// readout keeps related fields grouped without a tall stack of sparse rows.
struct MetadataPanel: View {
    let candidate: FileCandidate

    /// Always the same four fields; missing values never collapse a cell.
    private var rows: [(String, String)] {
        [
            ("SIZE", Self.byteFormatter.string(fromByteCount: candidate.bytes)),
            ("LAST OPENED", candidate.lastOpened.map(Self.dateFormatter.string) ?? "Never"),
            ("FROM", candidate.sourceURL?.host ?? "—"),
            ("ADDED", Self.dateFormatter.string(from: candidate.created)),
        ]
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], alignment: .leading, spacing: 14) {
            ForEach(rows, id: \.0) { label, value in
                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .font(.system(size: 10, design: .monospaced))
                        .kerning(0.7)
                        .foregroundStyle(DesignTokens.ColorToken.textSecondary)
                    Text(value)
                        .font(.system(size: 13))
                        .foregroundStyle(DesignTokens.ColorToken.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(value)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
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
