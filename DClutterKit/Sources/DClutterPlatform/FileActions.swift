//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import Foundation

public enum FileActionError: Error {
    case trashFailed(URL, underlying: Error)
}

/// The only place in DClutter that may touch a user file destructively —
/// and even here, only via `trashItem`. Never `removeItem`.
public struct FileActions: Sendable {
    /// Returns the URL the file was relocated to, when the executor can
    /// report one — this is what lets tests assert the file actually
    /// survived (invariant 1) rather than merely vanished from its old path.
    private let executor: @Sendable (URL) throws -> URL?

    public init() {
        self.init(executor: Self.systemTrash)
    }

    init(executor: @escaping @Sendable (URL) throws -> URL?) {
        self.executor = executor
    }

    @discardableResult
    public func trash(_ url: URL) throws -> URL? {
        do {
            return try executor(url)
        } catch {
            throw FileActionError.trashFailed(url, underlying: error)
        }
    }

    private static func systemTrash(_ url: URL) throws -> URL? {
        var resultingURL: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &resultingURL)
        return resultingURL as URL?
    }
}
