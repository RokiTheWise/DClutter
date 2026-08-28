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

    var showCommitSheet = false
    var commitError: String?
    var isRenaming = false
    var destinations: [Destination] = []
    var moveError: String?
    var renameError: String?

    private let destinationStore = DestinationStore()

    init(session: DClutterSession, fileActions: FileActions = FileActions()) {
        self.session = session
        self.fileActions = fileActions
        self.destinations = destinationStore.load()
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

    func keep() { session.keep(); version += 1 }
    func stage() { session.stage(); version += 1 }
    func skip() { session.skip(); version += 1 }
    func undo() { perform(session.undo()); version += 1 }
    func redo() { perform(session.redo()); version += 1 }

    /// Core reports disk work it cannot do itself; without carrying it out
    /// the queue and the folder would disagree about a file's name.
    private func perform(_ effect: UndoSideEffect?) {
        switch effect {
        case .renameFile(let from, let to):
            _ = try? fileActions.rename(from, to: to.lastPathComponent)
        case .moveFile(let from, let to):
            // The scope belongs to the bookmarked folder the file is sitting
            // in, so find it rather than trimming the path — a rebuilt URL
            // grants no access at all.
            let scoped = destinations.first { from.path.hasPrefix($0.url.path + "/") }?.url
            do {
                try fileActions.moveBack(from, to: to, scopedFolder: scoped)
                moveError = nil
            } catch {
                // The file is still where it was, so put the record back:
                // leaving it reverted would show a card for a file that is
                // no longer in Downloads, and every later action on it fails.
                session.redo()
                moveError = "Couldn't move \(from.lastPathComponent) back — \(error.localizedDescription)"
            }
        case .none:
            break
        }
    }

    /// Discards every undecided decision and restarts the queue.
    /// Already-trashed files stay trashed — see DClutterSession.reset.
    func reset() { session.reset(); version += 1 }

    /// Opens the current file in whatever app owns it, for when the
    /// preview and metadata aren't enough to decide. Read-only: it never
    /// changes the file's state in the queue.
    func openCurrentInDefaultApp() {
        guard let url = session.current?.url else { return }
        NSWorkspace.shared.open(url)
    }
    /// Files the current card into the destination at `index`.
    ///
    /// Invariant 4: the undo entry is registered *before* the file is
    /// touched. The session records the move first; only if the disk
    /// operation then succeeds does the record stand, and if it fails the
    /// record is rolled back so the queue never claims a move that did not
    /// happen.
    func moveCurrent(toDestinationAt index: Int) {
        guard let candidate = session.current,
              destinations.indices.contains(index) else { return }
        let folder = destinations[index].url

        session.move(candidate.url, to: folder.appendingPathComponent(candidate.url.lastPathComponent))
        do {
            let landed = try fileActions.move(candidate.url, intoFolder: folder)
            // Correct the recorded path if the destination suffixed the name
            // to avoid clobbering a file already there, so undo looks in the
            // right place. Amends the existing entry rather than adding one.
            session.amendLastMove(of: candidate.url, to: landed)
            moveError = nil
        } catch {
            session.undo()      // withdraw the record; nothing moved
            moveError = "Couldn't file \(candidate.url.lastPathComponent) — \(error.localizedDescription)"
        }
        version += 1
    }

    /// §6: up to three folders, chosen by the user through an open panel so
    /// the sandbox grants access to them at all.
    func chooseDestinationFolder() {
        // §6 caps this at three. Silently dropping one to make room loses
        // a setup the user chose, so refuse and say which key frees a slot.
        guard destinations.count < DestinationStore.maximumDestinations else {
            moveError = "Three folders is the maximum. Highlight one on the shelf and press ⌫ to free a slot."
            return
        }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Use Folder"
        panel.message = "Pick a folder to file things into."
        guard panel.runModal() == .OK, let url = panel.url else { return }

        destinations.append(Destination(url: url))
        destinationStore.save(destinations)
        moveError = nil
        version += 1
    }

    func removeDestination(at index: Int) {
        guard destinations.indices.contains(index) else { return }
        moveError = nil
        destinations.remove(at: index)
        destinationStore.save(destinations)
        version += 1
    }

    /// Selects the file in Finder. Read-only, like opening it — the queue
    /// is untouched, so this never counts as a decision.
    func revealCurrentInFinder() {
        guard let url = session.current?.url else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func copyCurrentName() {
        guard let url = session.current?.url else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.lastPathComponent, forType: .string)
    }

    /// Renames the current file on disk and re-points the session onto the
    /// new URL. Both halves must happen together: the session is keyed by
    /// URL, so a disk rename without the migration orphans the candidate.
    func renameCurrent(to newName: String) {
        guard let candidate = session.current else { return }
        do {
            let renamed = try fileActions.rename(candidate.url, to: newName)
            session.rename(candidate.url, to: renamed, recordUndo: true)
            renameError = nil
            isRenaming = false
        } catch FileActionError.nameAlreadyTaken(let name) {
            renameError = "\(name) already exists in this folder."
        } catch FileActionError.invalidName {
            renameError = "That isn't a usable filename."
        } catch {
            renameError = error.localizedDescription
        }
        version += 1
    }

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
