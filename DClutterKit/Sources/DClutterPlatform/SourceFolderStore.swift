//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import Foundation

/// Remembers which folders the user has triaged, as app-scoped
/// security-scoped bookmarks (§7).
///
/// Deliberately the same shape as `DestinationStore`: a plain path would
/// not survive relaunch, because the sandbox only grants `~/Downloads`
/// directly and every other folder has to be re-entered through a bookmark
/// minted from the user's own `NSOpenPanel` choice.
///
/// `~/Downloads` is not stored here. It needs no bookmark, it is always
/// offered, and keeping it out means the recents list is exactly "folders
/// you chose".
public struct SourceFolderStore {
    /// Small on purpose. This is a shortcut back to somewhere you were, not
    /// a file browser.
    public static let maximumRecents = 5

    private let defaultsKey = "dev.djenriquez.DClutter.sourceFolders"
    // Not Sendable: UserDefaults isn't, and this is only ever touched from
    // the main actor by the view that owns the folder field.
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private struct Stored: Codable {
        let bookmark: Data
        let path: String
    }

    /// Most recent first. An entry whose bookmark no longer resolves is
    /// dropped rather than offered as a folder that cannot be opened.
    public func recents() -> [URL] {
        stored().compactMap { entry in
            var isStale = false
            return try? URL(
                resolvingBookmarkData: entry.bookmark,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
        }
    }

    /// Records `url` as the most recently used folder. Silently does
    /// nothing if a bookmark cannot be minted — the folder still works for
    /// this session, it just will not be offered next launch.
    public func remember(_ url: URL) {
        guard let bookmark = try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return }

        let order = Self.merged(stored().map(\.path), adding: url.path)
        // uniquingKeysWith, not uniqueKeysWithValues: the latter traps on a
        // duplicate, and a defaults blob is not something we control.
        var byPath = Dictionary(stored().map { ($0.path, $0) }, uniquingKeysWith: { first, _ in first })
        byPath[url.path] = Stored(bookmark: bookmark, path: url.path)

        let updated = order.compactMap { byPath[$0] }
        guard let data = try? JSONEncoder().encode(updated) else { return }
        defaults.set(data, forKey: defaultsKey)
    }

    /// Newest first, no duplicates, capped. Split out from `remember` so
    /// the ordering rules are testable without minting real bookmarks.
    static func merged(_ existing: [String], adding path: String) -> [String] {
        var result = existing.filter { $0 != path }
        result.insert(path, at: 0)
        return Array(result.prefix(maximumRecents))
    }

    private func stored() -> [Stored] {
        guard let data = defaults.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([Stored].self, from: data)
        else { return [] }
        return decoded
    }
}
