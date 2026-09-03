//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import Testing
import Foundation
@testable import DClutterPlatform

/// Deinit ordering is deterministic in Swift, so a counter incremented from
/// the stop closure is a sound way to observe release. Locked because the
/// closure is `@Sendable`.
private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func increment() { lock.lock(); count += 1; lock.unlock() }
    var current: Int { lock.lock(); defer { lock.unlock() }; return count }
}

@Suite("Scoped folder access")
struct ScopedFolderAccessTests {
    /// The failure this type exists to prevent: stopping a scope that was
    /// never started. That is unbalanced and, in a sandboxed app, decrements
    /// a retain count it never incremented.
    @Test("A folder that granted no scope is never released")
    func neverStartedIsNeverStopped() {
        let stops = Counter()
        do {
            let access = ScopedFolderAccess(
                url: URL(fileURLWithPath: "/tmp"),
                start: { _ in false },
                stop: { _ in stops.increment() }
            )
            #expect(access.isScoped == false)
        }
        #expect(stops.current == 0)
    }

    @Test("A folder that granted scope is released exactly once")
    func startedIsStoppedOnce() {
        let stops = Counter()
        do {
            let access = ScopedFolderAccess(
                url: URL(fileURLWithPath: "/tmp"),
                start: { _ in true },
                stop: { _ in stops.increment() }
            )
            #expect(access.isScoped == true)
            #expect(stops.current == 0)   // still held while alive
        }
        #expect(stops.current == 1)
    }

    @Test("The folder it releases is the one it was given")
    func releasesTheSameURL() {
        let target = URL(fileURLWithPath: "/tmp/some-folder")
        let released = Counter()
        do {
            let access = ScopedFolderAccess(
                url: target,
                start: { _ in true },
                stop: { url in if url == target { released.increment() } }
            )
            #expect(access.url == target)
        }
        #expect(released.current == 1)
    }
}
