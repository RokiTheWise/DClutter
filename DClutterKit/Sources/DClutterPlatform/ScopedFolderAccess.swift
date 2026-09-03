//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import Foundation

/// Holds a folder's security scope open for as long as this object lives.
///
/// The plan's handoff note asks for exactly this — "security-scoped
/// bookmarks silently fail if you forget `startAccessingSecurityScopedResource()`;
/// wrap it in a helper so this can't be forgotten at a call site."
///
/// `FileActions` takes scope per operation, which is right for a
/// *destination*: it is touched one file at a time. A *source* folder is
/// the opposite — the scan, every thumbnail, every trash, rename and undo
/// all need it — so its scope is tied to the session instead of to a call.
public final class ScopedFolderAccess {
    public let url: URL
    private let didStart: Bool
    private let stop: @Sendable (URL) -> Void

    /// The two closures exist so the start/stop pairing can be tested. They
    /// default to the real calls, so every production call site is just
    /// `ScopedFolderAccess(url:)`.
    ///
    /// The test suite verifies the start/stop balance through injected mocks,
    /// but the default closures' wiring to the real security-scope API is
    /// only ever exercised by the shipping app. Correctness of those defaults
    /// is checked by hand when the folder switcher runs against a real folder.
    public init(
        url: URL,
        start: @Sendable (URL) -> Bool = { $0.startAccessingSecurityScopedResource() },
        stop: @escaping @Sendable (URL) -> Void = { $0.stopAccessingSecurityScopedResource() }
    ) {
        self.url = url
        self.stop = stop
        self.didStart = start(url)
    }

    /// Whether a scope was actually taken. Note this is environment-dependent:
    /// unsandboxed, the OS grants any readable path, so this is `true` almost
    /// everywhere outside the shipping app. Do not assert on it against a
    /// real URL.
    public var isScoped: Bool { didStart }

    deinit {
        if didStart { stop(url) }
    }
}
