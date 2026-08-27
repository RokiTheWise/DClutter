//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import Foundation
import AppKit
import Observation
import DClutterCore
import DClutterPlatform

/// The one place Core and Platform meet. DClutterSession never calls
/// FileActions itself — this view model does, and only from
/// `confirmCommit()`, which is only ever invoked after the commit sheet's
/// explicit confirmation (invariant 3).
@MainActor
@Observable
final class SessionViewModel {
    private let session: DClutterSession
    private let fileActions: FileActions

    /// Bumped by every mutator, read by every computed property below.
    /// See the task note above — without this, SwiftUI never re-renders.
    private var version = 0

    var previewFocused = false
    var showCommitSheet = false
    var commitError: String?

    init(session: DClutterSession, fileActions: FileActions = FileActions()) {
        self.session = session
        self.fileActions = fileActions
    }

    var current: FileCandidate? { _ = version; return session.current }
    var remainingCount: Int { _ = version; return session.remainingCount }
    var totalCount: Int { _ = version; return session.totalCount }
    var canUndo: Bool { _ = version; return session.canUndo }
    var canRedo: Bool { _ = version; return session.canRedo }
    var stagedForCommit: [FileCandidate] { _ = version; return session.stagedForCommit() }
    var trashedCount: Int { _ = version; return session.trashedCount }
    var sortedSinceLastCommit: Int { _ = version; return session.sortedSinceLastCommit }

    /// Files the user has unticked in the commit sheet. Kept here rather
    /// than in the sheet's own @State so it survives the sheet closing and
    /// reopening, and so confirmCommit is the single place that decides
    /// what actually gets trashed.
    var excludedFromCommit: Set<URL> = []

    var filesToTrash: [FileCandidate] {
        stagedForCommit.filter { !excludedFromCommit.contains($0.url) }
    }

    func toggleCommitInclusion(_ url: URL) {
        if excludedFromCommit.contains(url) {
            excludedFromCommit.remove(url)
        } else {
            excludedFromCommit.insert(url)
        }
    }

    func keep() { previewFocused = false; session.keep(); version += 1 }
    func stage() { previewFocused = false; session.stage(); version += 1 }
    func skip() { previewFocused = false; session.skip(); version += 1 }
    func undo() { previewFocused = false; session.undo(); version += 1 }
    func redo() { previewFocused = false; session.redo(); version += 1 }

    /// Discards every undecided decision and restarts the queue.
    /// Already-trashed files stay trashed — see DClutterSession.reset.
    func reset() { previewFocused = false; session.reset(); version += 1 }

    /// Opens the current file in whatever app owns it, for when the
    /// preview and metadata aren't enough to decide. Read-only: it never
    /// changes the file's state in the queue.
    func openCurrentInDefaultApp() {
        guard let url = session.current?.url else { return }
        NSWorkspace.shared.open(url)
    }
    func toggleFocus() { previewFocused.toggle() }

    /// Trashes every staged file, transitions the successful ones to
    /// .trashed (never .pending again — see FileState/commitTrashed), and
    /// keeps the sheet open on any failure so the error is actually visible
    /// instead of being dismissed along with it.
    func confirmCommit() {
        // Anything the user unticked is kept, not trashed, and drops out
        // of the staged list before we touch a single file.
        let excluded = excludedFromCommit
        if !excluded.isEmpty { session.unstage(excluded) }
        excludedFromCommit.removeAll()

        var trashed: Set<URL> = []
        var anyFailed = false
        for candidate in session.stagedForCommit() {
            do {
                try fileActions.trash(candidate.url)
                trashed.insert(candidate.url)
            } catch {
                anyFailed = true
                commitError = "Couldn't trash \(candidate.url.lastPathComponent): \(error.localizedDescription)"
            }
        }
        session.commitTrashed(trashed)
        version += 1
        if !anyFailed {
            commitError = nil
            showCommitSheet = false
        }
    }
}
