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
    private var deferred: Set<URL> = []
    private var history: [Decision] = []
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
            self.deferred = Set(snapshot.deferred.compactMap { known.contains($0) ? URL(string: $0) : nil })
        }
    }

    private var effectiveOrder: [FileCandidate] {
        queue.filter { !deferred.contains($0.url) } + queue.filter { deferred.contains($0.url) }
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
        persist()
    }

    public func stage() {
        guard let url = current?.url else { return }
        states[url] = .staged
        history.append(.stage(url))
        persist()
    }

    public func skip() {
        guard let url = current?.url else { return }
        deferred.insert(url)
        history.append(.skip(url))
        persist()
    }

    public func undo() {
        guard let last = history.popLast() else { return }
        switch last {
        case .keep(let url), .stage(let url):
            states.removeValue(forKey: url)
        case .skip(let url):
            deferred.remove(url)
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
        for url in urls where states[url] == .staged {
            states[url] = .trashed
        }
        history.removeAll()
        persist()
    }
}
