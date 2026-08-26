//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import SwiftUI

/// §2 principle 4: lists every staged file, requires explicit confirm,
/// reports a count — never bytes reclaimed (§0).
struct CommitSheet: View {
    let viewModel: SessionViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.large) {
            Text("Trash \(viewModel.stagedForCommit.count) files?")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(DesignTokens.ColorToken.textPrimary)

            List(viewModel.stagedForCommit) { candidate in
                Text(candidate.url.lastPathComponent)
                    .font(.system(size: 13))
            }
            .frame(minHeight: 200)

            if let error = viewModel.commitError {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(DesignTokens.ColorToken.consequence)
            }

            HStack {
                Spacer()
                Button("Cancel") { viewModel.showCommitSheet = false }
                    .keyboardShortcut(.cancelAction)
                Button("Trash \(viewModel.stagedForCommit.count) Files") {
                    viewModel.confirmCommit()
                }
                .keyboardShortcut(.defaultAction)
                .tint(DesignTokens.ColorToken.consequence)
            }
        }
        .padding(DesignTokens.Spacing.xLarge)
        .background(DesignTokens.ColorToken.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sheet))
        .frame(width: 420)
    }
}
