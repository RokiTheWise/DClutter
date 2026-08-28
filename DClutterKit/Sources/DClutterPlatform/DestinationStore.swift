//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import Foundation

/// A folder the user has chosen to file things into.
public struct Destination: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let url: URL
    /// Short label shown on the bin, defaulting to the folder's own name.
    public var name: String

    public init(id: UUID = UUID(), url: URL, name: String? = nil) {
        self.id = id
        self.url = url
        self.name = name ?? url.lastPathComponent
    }
}

/// Persists the user's destination folders as app-scoped security-scoped
/// bookmarks (§7). A plain path would not survive relaunch: the sandbox
/// only grants access to `~/Downloads`, so every other folder has to be
/// re-entered through a bookmark the user's own `NSOpenPanel` choice minted.
///
/// §6 caps this at three deliberately — "with three bins the user aims by
/// muscle memory and never reads a label; with six they read, and reading
/// breaks the loop."
public struct DestinationStore {
    public static let maximumDestinations = 3

    private let defaultsKey = "dev.djenriquez.DClutter.destinations"
    // Not Sendable: UserDefaults isn't, and this is only ever touched
    // from the main actor by the view model that owns the shelf.
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private struct Stored: Codable {
        let id: UUID
        let bookmark: Data
        let name: String
    }

    public func load() -> [Destination] {
        guard let data = defaults.data(forKey: defaultsKey),
              let stored = try? JSONDecoder().decode([Stored].self, from: data)
        else { return [] }

        return stored.compactMap { entry in
            var isStale = false
            guard let url = try? URL(
                resolvingBookmarkData: entry.bookmark,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) else { return nil }
            return Destination(id: entry.id, url: url, name: entry.name)
        }
    }

    /// Mints fresh bookmarks and replaces the stored set. Anything beyond
    /// the cap is dropped rather than silently kept.
    public func save(_ destinations: [Destination]) {
        let stored: [Stored] = destinations.prefix(Self.maximumDestinations).compactMap { destination in
            guard let bookmark = try? destination.url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            ) else { return nil }
            return Stored(id: destination.id, bookmark: bookmark, name: destination.name)
        }
        guard let data = try? JSONEncoder().encode(stored) else { return }
        defaults.set(data, forKey: defaultsKey)
    }
}
