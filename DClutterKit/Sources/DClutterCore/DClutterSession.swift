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
    let persistenceURL: URL

    public init(candidates: [FileCandidate], persistenceURL: URL) {
        self.queue = candidates
        self.persistenceURL = persistenceURL
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
