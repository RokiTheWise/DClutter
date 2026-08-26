//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import Foundation
import UniformTypeIdentifiers
#if canImport(Darwin)
import Darwin
#endif

/// Reads `FileCandidate`s straight off disk via direct enumeration (§5
/// Route B) — no AppKit. Source URL comes from the
/// `com.apple.metadata:kMDItemWhereFroms` extended attribute browsers set
/// on download.
///
/// `lastOpened` comes from Spotlight (`NSMetadataItem`'s
/// `NSMetadataItemLastUsedDateKey`, the pure-Foundation equivalent of
/// `MDItemCopyAttribute(kMDItemLastUsedDate)`), not `.contentAccessDateKey`.
/// Verified empirically against 10 known files: `.contentAccessDateKey` was
/// non-nil and recent for files the user confirmed they hadn't opened in
/// months — including two unrelated files sharing an identical timestamp,
/// the signature of a background process (backup/indexing) bumping atime
/// rather than a genuine open. Spotlight's date matched the user's own
/// account exactly on all 10.
public struct DirectoryMetadataProvider: FileMetadataProvider {
    private let lastUsedLookup: @Sendable (URL) -> Date?

    public init() {
        self.init(lastUsedLookup: Self.spotlightLastUsed)
    }

    init(lastUsedLookup: @escaping @Sendable (URL) -> Date?) {
        self.lastUsedLookup = lastUsedLookup
    }

    private static let resourceKeys: Set<URLResourceKey> = [
        .fileSizeKey,
        .creationDateKey,
        .contentModificationDateKey,
        .contentTypeKey,
        .isDirectoryKey,
    ]

    public func candidates(in folder: URL) async throws -> [FileCandidate] {
        let urls = try FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: Array(Self.resourceKeys),
            options: [.skipsHiddenFiles]
        )

        return try urls.map { url in
            let values = try url.resourceValues(forKeys: Self.resourceKeys)
            return FileCandidate(
                url: url,
                bytes: Int64(values.fileSize ?? 0),
                lastOpened: lastUsedLookup(url),
                created: values.creationDate ?? Date(),
                modified: values.contentModificationDate,
                sourceURL: Self.readSourceURL(at: url),
                contentType: values.contentType,
                isDirectory: values.isDirectory ?? false
            )
        }
    }

    private static func spotlightLastUsed(_ url: URL) -> Date? {
        guard let item = NSMetadataItem(url: url) else { return nil }
        return item.value(forAttribute: NSMetadataItemLastUsedDateKey) as? Date
    }

    /// Parses the binary-plist `kMDItemWhereFroms` xattr: an array of
    /// strings whose first element is the download URL.
    private static func readSourceURL(at url: URL) -> URL? {
        let path = url.path
        let name = "com.apple.metadata:kMDItemWhereFroms"

        let size = getxattr(path, name, nil, 0, 0, 0)
        guard size > 0 else { return nil }

        var buffer = [UInt8](repeating: 0, count: size)
        let read = getxattr(path, name, &buffer, size, 0, 0)
        guard read > 0 else { return nil }

        let data = Data(buffer)
        guard
            let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
            let whereFroms = plist as? [String],
            let first = whereFroms.first
        else { return nil }

        return URL(string: first)
    }
}
