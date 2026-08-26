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
    private let executor: @Sendable (URL) throws -> Void

    public init() {
        self.init(executor: Self.systemTrash)
    }

    init(executor: @escaping @Sendable (URL) throws -> Void) {
        self.executor = executor
    }

    public func trash(_ url: URL) throws {
        do {
            try executor(url)
        } catch {
            throw FileActionError.trashFailed(url, underlying: error)
        }
    }

    private static func systemTrash(_ url: URL) throws {
        var resultingURL: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &resultingURL)
    }
}
