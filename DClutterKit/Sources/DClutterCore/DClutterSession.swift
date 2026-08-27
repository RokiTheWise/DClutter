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
    public let queue: [FileCandidate]
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
}

private enum Decision {
    case keep(URL)
    case stage(URL)
    case skip(URL)
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

    public func keep() {
        guard let url = current?.url else { return }
        states[url] = .kept
        history.append(.keep(url))
        redoStack.removeAll()
        persist()
    }

    public func stage() {
        guard let url = current?.url else { return }
        states[url] = .staged
        history.append(.stage(url))
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

    public var canRedo: Bool { !redoStack.isEmpty }

    public func undo() {
        guard let last = history.popLast() else { return }
        revert(last)
        redoStack.append(last)
        persist()
    }

    /// Re-applies the most recently undone decision. Any fresh decision
    /// clears the stack (keep/stage/skip each reset it) — standard undo/redo
    /// semantics: branching discards the future you undid your way out of.
    public func redo() {
        guard let next = redoStack.popLast() else { return }
        apply(next)
        history.append(next)
        persist()
    }

    /// Returns every still-decidable file to `.pending` and clears both
    /// stacks. `.trashed` files are deliberately left alone: they are gone
    /// from disk, so re-queuing them would show cards for paths that no
    /// longer exist.
    public func reset() {
        states = states.filter { $0.value == .trashed }
        deferred.removeAll()
        history.removeAll()
        redoStack.removeAll()
        persist()
    }

    private func revert(_ decision: Decision) {
        switch decision {
        case .keep(let url), .stage(let url):
            states.removeValue(forKey: url)
        case .skip(let url):
            if let index = deferred.firstIndex(of: url) {
                deferred.remove(at: index)
            }
        }
    }

    private func apply(_ decision: Decision) {
        switch decision {
        case .keep(let url): states[url] = .kept
        case .stage(let url): states[url] = .staged
        case .skip(let url):
            if let existing = deferred.firstIndex(of: url) {
                deferred.remove(at: existing)
            }
            deferred.append(url)
        }
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
        }
        persist()
    }
}
