//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import Foundation

public enum FileActionError: Error {
    case trashFailed(URL, underlying: Error)
    case renameFailed(URL, underlying: Error)
    case nameAlreadyTaken(String)
    case invalidName(String)
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

    /// Renames a file in place. `newName` is treated as a bare filename:
    /// any path components are stripped, so a name like "../elsewhere.pdf"
    /// cannot relocate the file out of the folder it lives in — the app is
    /// only ever entitled to ~/Downloads.
    @discardableResult
    public func rename(_ url: URL, to newName: String) throws -> URL {
        let bare = (newName as NSString).lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !bare.isEmpty, bare != ".", bare != ".." else {
            throw FileActionError.invalidName(newName)
        }

        // Preserve the extension unless the user supplied one. Dropping it
        // leaves the bytes intact but macOS can no longer identify the file,
        // which looks exactly like corruption to the person who renamed it.
        let originalExtension = url.pathExtension
        let finalName: String
        if (bare as NSString).pathExtension.isEmpty && !originalExtension.isEmpty {
            finalName = bare + "." + originalExtension
        } else {
            finalName = bare
        }

        let destination = url.deletingLastPathComponent().appendingPathComponent(finalName)
        guard destination.standardizedFileURL != url.standardizedFileURL else { return url }
        guard !FileManager.default.fileExists(atPath: destination.path) else {
            throw FileActionError.nameAlreadyTaken(bare)
        }

        do {
            try FileManager.default.moveItem(at: url, to: destination)
        } catch {
            throw FileActionError.renameFailed(url, underlying: error)
        }
        return destination
    }

    private static func systemTrash(_ url: URL) throws -> URL? {
        var resultingURL: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &resultingURL)
        return resultingURL as URL?
    }
}
