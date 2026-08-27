//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import SwiftUI
import DClutterCore

/// §2 principle 4: lists every staged file, requires explicit confirm,
/// reports a count — never bytes reclaimed (§0).
///
/// The list is a checklist rather than a receipt: by the time a session
/// ends, the user has usually forgotten what they staged twenty cards ago,
/// and the last moment before deletion is exactly when a second thought
/// deserves somewhere to go. Unticking keeps the file (see
/// `DClutterSession.unstage`), it does not re-queue it.
struct CommitSheet: View {
    let viewModel: SessionViewModel

    private var staged: [FileCandidate] { viewModel.stagedForCommit }
    private var trashCount: Int { viewModel.filesToTrash.count }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.large) {
            Text(trashCount == 1 ? "Trash 1 file?" : "Trash \(trashCount) files?")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(DesignTokens.ColorToken.textPrimary)

            if staged.count != trashCount {
                Text("\(staged.count - trashCount) unticked — those stay where they are.")
                    .font(.system(size: 12))
                    .foregroundStyle(DesignTokens.ColorToken.textSecondary)
            }

            List(staged) { candidate in
                Toggle(isOn: Binding(
                    get: { !viewModel.excludedFromCommit.contains(candidate.url) },
                    set: { _ in viewModel.toggleCommitInclusion(candidate.url) }
                )) {
                    HStack(spacing: DesignTokens.Spacing.small) {
                        Text(candidate.url.lastPathComponent)
                            .font(.system(size: 13))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Text(Self.byteFormatter.string(fromByteCount: candidate.bytes))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(DesignTokens.ColorToken.textTertiary)
                    }
                }
                .toggleStyle(.checkbox)
            }
            .frame(minHeight: 220)

            if let error = viewModel.commitError {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(DesignTokens.ColorToken.consequence)
            }

            HStack {
                Button(viewModel.excludedFromCommit.isEmpty ? "Untick All" : "Tick All") {
                    if viewModel.excludedFromCommit.isEmpty {
                        viewModel.excludedFromCommit = Set(staged.map(\.url))
                    } else {
                        viewModel.excludedFromCommit.removeAll()
                    }
                }
                .buttonStyle(.link)

                Spacer()

                Button("Cancel") { viewModel.showCommitSheet = false }
                    .keyboardShortcut(.cancelAction)
                // Return confirms. This is a destructive default, which the
                // rest of the app deliberately avoids — it is acceptable
                // here only because reaching this sheet is itself explicit
                // (⌘⏎), every file is listed, and each one can be unticked.
                Button(trashCount == 1 ? "Trash 1 File" : "Trash \(trashCount) Files") {
                    viewModel.confirmCommit()
                }
                .keyboardShortcut(.defaultAction)
                .tint(DesignTokens.ColorToken.consequence)
                .disabled(trashCount == 0)
            }
        }
        .padding(DesignTokens.Spacing.xLarge)
        .background(DesignTokens.ColorToken.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sheet))
        .frame(width: 460)
    }

    private static let byteFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f
    }()
}
