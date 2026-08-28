//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import Foundation

/// The §3 state machine. `queue` order is fixed at init (the caller passes
/// an already-ranked list from QueueScorer.rank) — skip reorders logically
/// via `deferred`, never mutates `queue` itself, which keeps persistence
/// and reconciliation on relaunch simple.
@MainActor
public final class DClutterSession {
    public private(set) var queue: [FileCandidate]
    public private(set) var states: [URL: FileState] = [:]
    /// Ordered by deferral: skip() moves a URL to the end of this array, so
    /// re-skipping an already-deferred file genuinely rotates it further
    /// back instead of being a no-op (see §Fix note in the task list — this
    /// used to be a Set, which made re-skipping the last pending file hang).
    private var deferred: [URL] = []
    private var history: [Decision] = []
    /// Decisions undone and not yet re-applied. Any fresh decision
    /// clears it — branching discards the undone future.
    private var redoStack: [Decision] = []
    /// Decisions made since the last commit. A commit is the natural
    /// checkpoint — "67 sorted" means nothing once those files are gone,
    /// so it resets and the remaining count carries the running total.
    public private(set) var sortedSinceLastCommit = 0
    let persistenceURL: URL

    public init(candidates: [FileCandidate], persistenceURL: URL) {
        self.queue = candidates
        self.persistenceURL = persistenceURL
        if let snapshot = Self.loadSnapshot(from: persistenceURL) {
            let known = Set(candidates.map(\.url.absoluteString))
            self.states = snapshot.states.reduce(into: [:]) { result, entry in
                guard known.contains(entry.key), let url = URL(string: entry.key) else { return }
                result[url] = entry.value
            }
            self.deferred = snapshot.deferred.compactMap { known.contains($0) ? URL(string: $0) : nil }
        }
    }

    private var effectiveOrder: [FileCandidate] {
        let deferredSet = Set(deferred)
        let undeferred = queue.filter { !deferredSet.contains($0.url) }
        let byURL = Dictionary(uniqueKeysWithValues: queue.map { ($0.url, $0) })
        let deferredInOrder = deferred.compactMap { byURL[$0] }
        return undeferred + deferredInOrder
    }

    public var current: FileCandidate? {
        effectiveOrder.first { (states[$0.url] ?? .pending) == .pending }
    }

    public var remainingCount: Int {
        queue.filter { (states[$0.url] ?? .pending) == .pending }.count
    }

    public var totalCount: Int { queue.count }

    /// Files actually moved to the Trash this session. Distinct from
    /// "decided": staging already removes a file from `remainingCount`, so
    /// without this a commit changes no number on screen and reads as
    /// having done nothing.
    public var trashedCount: Int {
        states.values.filter { $0 == .trashed }.count
    }
}

/// Disk work that Core cannot perform itself but that a caller must carry
/// out for the folder to match the queue.
public enum UndoSideEffect: Equatable, Sendable {
    case renameFile(from: URL, to: URL)
    case moveFile(from: URL, to: URL)
}

private enum Decision {
    case keep(URL)
    case stage(URL)
    case skip(URL)
    case rename(from: URL, to: URL)
    case move(URL, to: URL)

    /// Rewrites this decision's target after a rename, so undo and redo
    /// still reach the file they were recorded against.
    func repointing(_ old: URL, to new: URL) -> Decision {
        switch self {
        case .keep(let url): return url == old ? .keep(new) : self
        case .stage(let url): return url == old ? .stage(new) : self
        case .skip(let url): return url == old ? .skip(new) : self
        case .rename(let from, let to):
            return .rename(from: from == old ? new : from, to: to == old ? new : to)
        case .move(let url, let destination):
            return url == old ? .move(new, to: destination) : self
        }
    }
}

struct SessionSnapshot: Codable {
    let queueOrder: [String]      // url.absoluteString, in effective order at save time
    let states: [String: FileState]
    let deferred: [String]
}

extension DClutterSession {
    private func persist() {
        let snapshot = SessionSnapshot(
            queueOrder: queue.map(\.url.absoluteString),
            states: states.reduce(into: [:]) { $0[$1.key.absoluteString] = $1.value },
            deferred: deferred.map(\.absoluteString)
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: persistenceURL, options: .atomic)
    }

    static func loadSnapshot(from url: URL) -> SessionSnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(SessionSnapshot.self, from: data)
    }
}

extension DClutterSession {
    public var canUndo: Bool { !history.isEmpty }

    /// Files filed into a folder since the last commit — the ones a reset
    /// would bring back.
    public var movesThisSession: Int {
        history.reduce(into: 0) { count, decision in
            if case .move = decision { count += 1 }
        }
    }

    public func keep() {
        guard let url = current?.url else { return }
        states[url] = .kept
        history.append(.keep(url))
        sortedSinceLastCommit += 1
        redoStack.removeAll()
        persist()
    }

    public func stage() {
        guard let url = current?.url else { return }
        states[url] = .staged
        history.append(.stage(url))
        sortedSinceLastCommit += 1
        redoStack.removeAll()
        persist()
    }

    public func skip() {
        guard let url = current?.url else { return }
        let previousCurrent = url
        if let existing = deferred.firstIndex(of: url) {
            deferred.remove(at: existing)
        }
        deferred.append(url)
        // A skip that doesn't actually move the visible candidate (e.g. this
        // is the only pending file left) shouldn't leave a dead undo entry —
        // otherwise ⌘Z appears to do nothing for several presses in a row.
        if current?.url != previousCurrent {
            history.append(.skip(url))
        }
        redoStack.removeAll()
        persist()
    }

    /// Records the move and advances. §3: `.moved` is already executed and
    /// lives in the undo stack, so unlike `.staged` it never reaches the
    /// commit sheet. Invariant 4 requires the undo entry to exist before
    /// the file is touched, so callers must call this *before* moving on
    /// disk, not after.
    public func move(_ url: URL, to destination: URL) {
        guard states[url] == nil || states[url] == .pending else { return }
        states[url] = .moved(to: destination)
        history.append(.move(url, to: destination))
        sortedSinceLastCommit += 1
        redoStack.removeAll()
        persist()
    }

    /// Corrects the destination recorded for a move already registered.
    /// A destination folder may suffix the filename to avoid overwriting
    /// something already there, so where the file actually landed can
    /// differ from what was recorded before it was touched — and undo must
    /// follow the real path. Amends in place: no new history entry.
    public func amendLastMove(of url: URL, to actual: URL) {
        guard case .moved = states[url] else { return }
        states[url] = .moved(to: actual)
        if case .move(let recorded, _) = history.last, recorded == url {
            history[history.count - 1] = .move(url, to: actual)
        }
        persist()
    }

    public var canRedo: Bool { !redoStack.isEmpty }

    @discardableResult
    public func undo() -> UndoSideEffect? {
        guard let last = history.popLast() else { return nil }
        switch last {
        case .skip, .rename: break
        case .move: sortedSinceLastCommit = max(0, sortedSinceLastCommit - 1)
        default: sortedSinceLastCommit = max(0, sortedSinceLastCommit - 1)
        }
        let effect = revert(last)
        redoStack.append(last)
        persist()
        return effect
    }

    /// Re-applies the most recently undone decision. Any fresh decision
    /// clears the stack (keep/stage/skip each reset it) — standard undo/redo
    /// semantics: branching discards the future you undid your way out of.
    @discardableResult
    public func redo() -> UndoSideEffect? {
        guard let next = redoStack.popLast() else { return nil }
        switch next {
        case .skip, .rename: break
        case .move: sortedSinceLastCommit += 1
        default: sortedSinceLastCommit += 1
        }
        let effect = apply(next)
        history.append(next)
        persist()
        return effect
    }

    /// Returns every still-decidable file to `.pending` and clears both
    /// stacks. `.trashed` files are deliberately left alone: they are gone
    /// from disk, so re-queuing them would show cards for paths that no
    /// longer exist.
    /// Undoes everything still undoable and reports the disk work that
    /// needs doing to match.
    ///
    /// A commit ends a session, so `history` — which a commit clears — is
    /// exactly this session's work. Files filed into a folder since then
    /// come back; anything trashed, or filed before the last commit,
    /// belongs to a session that is already closed and is left alone.
    @discardableResult
    public func reset() -> [UndoSideEffect] {
        var effects: [UndoSideEffect] = []
        for decision in history.reversed() {
            guard case .move(let url, let destination) = decision else { continue }
            states.removeValue(forKey: url)
            effects.append(.moveFile(from: destination, to: url))
        }
        // Everything else this session decided simply becomes undecided;
        // trashed and older moved files keep their terminal state.
        states = states.filter { state in
            if case .moved = state.value { return true }
            return state.value == .trashed
        }
        deferred.removeAll()
        history.removeAll()
        redoStack.removeAll()
        sortedSinceLastCommit = 0
        persist()
        return effects
    }

    /// Puts a move back on the record after the file could not be returned,
    /// so the queue never claims a file is in Downloads when it isn't.
    public func restoreMove(of url: URL, to destination: URL) {
        states[url] = .moved(to: destination)
        persist()
    }

    private func revert(_ decision: Decision) -> UndoSideEffect? {
        switch decision {
        case .keep(let url), .stage(let url):
            states.removeValue(forKey: url)
        case .skip(let url):
            if let index = deferred.firstIndex(of: url) {
                deferred.remove(at: index)
            }
        case .rename(let from, let to):
            rename(to, to: from)
            return .renameFile(from: to, to: from)
        case .move(let url, let destination):
            states.removeValue(forKey: url)
            return .moveFile(from: destination, to: url)
        }
        return nil
    }

    private func apply(_ decision: Decision) -> UndoSideEffect? {
        switch decision {
        case .keep(let url): states[url] = .kept
        case .stage(let url): states[url] = .staged
        case .skip(let url):
            if let existing = deferred.firstIndex(of: url) {
                deferred.remove(at: existing)
            }
            deferred.append(url)
        case .rename(let from, let to):
            rename(from, to: to)
            return .renameFile(from: from, to: to)
        case .move(let url, let destination):
            states[url] = .moved(to: destination)
            return .moveFile(from: url, to: destination)
        }
        return nil
    }

    /// Re-points every piece of session state from `old` to `new` after the
    /// file has been renamed on disk. The session is keyed by URL
    /// throughout — queue, states, deferral order and both undo stacks — so
    /// without this the renamed file is orphaned: its decision is lost and
    /// on relaunch reconciliation drops it and re-queues it as unseen.
    ///
    /// The candidate keeps its identity; only its URL changes.
    public func rename(_ old: URL, to new: URL, recordUndo: Bool = false) {
        guard let index = queue.firstIndex(where: { $0.url == old }) else { return }

        let existing = queue[index]
        queue[index] = FileCandidate(
            id: existing.id,
            url: new,
            bytes: existing.bytes,
            lastOpened: existing.lastOpened,
            created: existing.created,
            modified: existing.modified,
            sourceURL: existing.sourceURL,
            contentType: existing.contentType,
            isDirectory: existing.isDirectory
        )

        if let state = states.removeValue(forKey: old) { states[new] = state }
        if let position = deferred.firstIndex(of: old) { deferred[position] = new }
        history = history.map { $0.repointing(old, to: new) }
        redoStack = redoStack.map { $0.repointing(old, to: new) }
        if recordUndo {
            history.append(.rename(from: old, to: new))
            redoStack.removeAll()
        }
        persist()
    }

    /// Un-stages files the user unticked in the commit sheet. They become
    /// `.kept` rather than `.pending`: unticking means "keep this one", not
    /// "ask me again", so the file should not resurface as a card.
    public func unstage(_ urls: Set<URL>) {
        for url in urls where states[url] == .staged {
            states[url] = .kept
        }
        persist()
    }

    public func stagedForCommit() -> [FileCandidate] {
        queue.filter { states[$0.url] == .staged }
    }

    /// Called once trashing succeeds for the given URLs. Transitions them
    /// from .staged to the terminal .trashed state and clears undo history
    /// entirely — a committed file cannot be un-trashed via ⌘Z (that would
    /// need M4's real file-recovery logic), and history may reference
    /// decisions from before the commit boundary that no longer make sense
    /// to reverse in isolation.
    public func commitTrashed(_ urls: Set<URL>) {
        var trashedAny = false
        for url in urls where states[url] == .staged {
            states[url] = .trashed
            trashedAny = true
        }
        if trashedAny {
            history.removeAll()
            redoStack.removeAll()
            sortedSinceLastCommit = 0
        }
        persist()
    }
}
