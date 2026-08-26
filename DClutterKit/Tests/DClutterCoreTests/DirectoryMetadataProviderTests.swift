//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import Testing
import Foundation
#if canImport(Darwin)
import Darwin
#endif
@testable import DClutterCore

private func makeTempFolder() throws -> URL {
    let folder = FileManager.default.temporaryDirectory
        .appendingPathComponent("DClutterTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    return folder
}

/// Sets the `kMDItemWhereFroms` extended attribute the way a browser does:
/// a binary plist array of strings, download URL first.
private func setWhereFroms(_ urls: [String], on fileURL: URL) throws {
    let data = try PropertyListSerialization.data(fromPropertyList: urls, format: .binary, options: 0)
    let result = data.withUnsafeBytes { bytes in
        setxattr(fileURL.path, "com.apple.metadata:kMDItemWhereFroms", bytes.baseAddress, data.count, 0, 0)
    }
    #expect(result == 0, "setxattr failed with errno \(errno)")
}

@Test func providerReturnsACandidateForEachFileInFolder() async throws {
    let folder = try makeTempFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    try Data("hello".utf8).write(to: folder.appendingPathComponent("a.txt"))
    try Data("hello world".utf8).write(to: folder.appendingPathComponent("b.txt"))

    let provider = DirectoryMetadataProvider()
    let candidates = try await provider.candidates(in: folder)

    #expect(candidates.count == 2)
    #expect(Set(candidates.map(\.url.lastPathComponent)) == ["a.txt", "b.txt"])
}

@Test func providerReportsCorrectFileSize() async throws {
    let folder = try makeTempFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let payload = Data("exactly eleven".utf8) // 14 bytes, name is a lie, checked below
    try payload.write(to: folder.appendingPathComponent("sized.txt"))

    let provider = DirectoryMetadataProvider()
    let candidates = try await provider.candidates(in: folder)

    #expect(candidates.first?.bytes == Int64(payload.count))
}

@Test func providerFlagsSubdirectoriesAsDirectories() async throws {
    let folder = try makeTempFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    try FileManager.default.createDirectory(at: folder.appendingPathComponent("Extracted"), withIntermediateDirectories: true)

    let provider = DirectoryMetadataProvider()
    let candidates = try await provider.candidates(in: folder)

    #expect(candidates.first?.isDirectory == true)
}

@Test func providerReadsSourceURLFromWhereFromsXattr() async throws {
    let folder = try makeTempFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let fileURL = folder.appendingPathComponent("downloaded.pdf")
    try Data("x".utf8).write(to: fileURL)
    try setWhereFroms(["https://example.com/downloaded.pdf", "https://example.com/page"], on: fileURL)

    let provider = DirectoryMetadataProvider()
    let candidates = try await provider.candidates(in: folder)

    #expect(candidates.first?.sourceURL == URL(string: "https://example.com/downloaded.pdf"))
}

@Test func providerReturnsNilSourceURLWhenXattrAbsent() async throws {
    let folder = try makeTempFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    try Data("x".utf8).write(to: folder.appendingPathComponent("plain.txt"))

    let provider = DirectoryMetadataProvider()
    let candidates = try await provider.candidates(in: folder)

    #expect(candidates.first?.sourceURL == nil)
}

@Test func providerInfersContentTypeFromExtension() async throws {
    let folder = try makeTempFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    try Data("%PDF-1.4".utf8).write(to: folder.appendingPathComponent("report.pdf"))

    let provider = DirectoryMetadataProvider()
    let candidates = try await provider.candidates(in: folder)

    #expect(candidates.first?.contentType?.identifier == "com.adobe.pdf")
}

@Test func providerThrowsForNonexistentFolder() async throws {
    let missing = FileManager.default.temporaryDirectory.appendingPathComponent("does-not-exist-\(UUID().uuidString)")
    let provider = DirectoryMetadataProvider()

    await #expect(throws: (any Error).self) {
        _ = try await provider.candidates(in: missing)
    }
}

@Test func providerReadsLastOpenedFromInjectedLookup() async throws {
    let folder = try makeTempFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let fileURL = folder.appendingPathComponent("opened.pdf")
    try Data("x".utf8).write(to: fileURL)
    let expected = Date(timeIntervalSince1970: 1_700_000_000)

    let provider = DirectoryMetadataProvider(lastUsedLookup: { url in
        url.lastPathComponent == "opened.pdf" ? expected : nil
    })
    let candidates = try await provider.candidates(in: folder)

    #expect(candidates.first?.lastOpened == expected)
}

@Test func providerReturnsNilLastOpenedWhenLookupReturnsNil() async throws {
    let folder = try makeTempFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    try Data("x".utf8).write(to: folder.appendingPathComponent("never-opened.pdf"))

    let provider = DirectoryMetadataProvider(lastUsedLookup: { _ in nil })
    let candidates = try await provider.candidates(in: folder)

    #expect(candidates.first?.lastOpened == nil)
}

@Test func providerIgnoresStaleContentAccessDateInFavorOfLookup() async throws {
    // .contentAccessDateKey is unreliable (verified empirically: background
    // processes bump it for files the user never opened). The provider must
    // not use it for lastOpened even though the filesystem still reports one.
    let folder = try makeTempFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let fileURL = folder.appendingPathComponent("touched-by-backup.pdf")
    try Data("x".utf8).write(to: fileURL)
    _ = try Data(contentsOf: fileURL) // reading bumps atime on some filesystems

    let provider = DirectoryMetadataProvider(lastUsedLookup: { _ in nil })
    let candidates = try await provider.candidates(in: folder)

    #expect(candidates.first?.lastOpened == nil)
}

@Test func providerRecordsCreationAndModificationDates() async throws {
    let folder = try makeTempFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let before = Date().addingTimeInterval(-5)
    try Data("x".utf8).write(to: folder.appendingPathComponent("timed.txt"))
    let after = Date().addingTimeInterval(5)

    let provider = DirectoryMetadataProvider()
    let candidates = try await provider.candidates(in: folder)
    let candidate = try #require(candidates.first)

    #expect(candidate.created >= before && candidate.created <= after)
    #expect(candidate.modified != nil)
}
