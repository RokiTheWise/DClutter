//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import Foundation

public enum FileActionError: Error {
    case trashFailed(URL, underlying: Error)
    case renameFailed(URL, underlying: Error)
    case nameAlreadyTaken(String)
    case invalidName(String)
    case moveFailed(URL, underlying: Error)
    case destinationUnavailable(URL)
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

    /// Moves a file into a destination folder, holding the folder's
    /// security scope for exactly the duration of the move.
    ///
    /// §7 warns that security-scoped bookmarks "silently fail if you forget
    /// startAccessingSecurityScopedResource()", and asks for a helper so
    /// this cannot be forgotten at a call site. Every write to a destination
    /// goes through here; the `defer` releases the scope on every path,
    /// including the throwing ones.
    @discardableResult
    public func move(_ url: URL, intoFolder folder: URL) throws -> URL {
        let scoped = folder.startAccessingSecurityScopedResource()
        defer { if scoped { folder.stopAccessingSecurityScopedResource() } }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw FileActionError.destinationUnavailable(folder)
        }

        let destination = uniqueDestination(for: url.lastPathComponent, in: folder)
        do {
            try FileManager.default.moveItem(at: url, to: destination)
        } catch {
            throw FileActionError.moveFailed(url, underlying: error)
        }
        return destination
    }

    /// Moves a file back to an exact path, for undo. The destination folder
    /// is the one being left, so its scope is the one that must be held.
    public func moveBack(_ url: URL, to original: URL) throws {
        let folder = url.deletingLastPathComponent()
        let scoped = folder.startAccessingSecurityScopedResource()
        defer { if scoped { folder.stopAccessingSecurityScopedResource() } }
        do {
            try FileManager.default.moveItem(at: url, to: original)
        } catch {
            throw FileActionError.moveFailed(url, underlying: error)
        }
    }

    /// Never overwrite a file that is already there — suffix instead, the
    /// way Finder does.
    private func uniqueDestination(for name: String, in folder: URL) -> URL {
        let candidate = folder.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: candidate.path) else { return candidate }

        let stem = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var counter = 2
        while true {
            let suffixed = ext.isEmpty ? "\(stem) \(counter)" : "\(stem) \(counter).\(ext)"
            let next = folder.appendingPathComponent(suffixed)
            if !FileManager.default.fileExists(atPath: next.path) { return next }
            counter += 1
        }
    }

    private static func systemTrash(_ url: URL) throws -> URL? {
        var resultingURL: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &resultingURL)
        return resultingURL as URL?
    }
}
