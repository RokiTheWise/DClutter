//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import Testing
import Foundation
@testable import DClutterCore

private func candidate(_ name: String, bytes: Int64, isDirectory: Bool = false, created: Date = Date()) -> FileCandidate {
    FileCandidate(
        url: URL(fileURLWithPath: "/tmp/downloads/\(name)"),
        bytes: bytes,
        lastOpened: nil,
        created: created,
        isDirectory: isDirectory
    )
}

@Test func singleFileIsNotARedundantCopy() {
    let a = candidate("Report.pdf", bytes: 10_000)
    let ctx = QueueContext(candidates: [a])
    #expect(!ctx.isRedundantCopy(a))
}

@Test func copySuffixedDuplicateOfSameSizeIsRedundant() {
    let keeper = candidate("Report.pdf", bytes: 10_000)
    let copy = candidate("Report (2).pdf", bytes: 10_000)
    let ctx = QueueContext(candidates: [keeper, copy])
    #expect(!ctx.isRedundantCopy(keeper))
    #expect(ctx.isRedundantCopy(copy))
}

@Test func copyWordSuffixedDuplicateIsRedundant() {
    let keeper = candidate("Report.pdf", bytes: 10_000)
    let copy = candidate("Report copy 3.pdf", bytes: 10_000)
    let ctx = QueueContext(candidates: [keeper, copy])
    #expect(!ctx.isRedundantCopy(keeper))
    #expect(ctx.isRedundantCopy(copy))
}

@Test func sameNameDifferentSizeAreNotDuplicates() {
    let a = candidate("Report.pdf", bytes: 10_000)
    let b = candidate("Report.pdf", bytes: 55_000)
    let ctx = QueueContext(candidates: [a, b])
    #expect(!ctx.isRedundantCopy(a))
    #expect(!ctx.isRedundantCopy(b))
}

@Test func sizesStraddlingAKBRoundingBoundaryAreStillClustered() {
    // 1023*1024 + 511 rounds DOWN to 1023 KB; 1023*1024 + 513 rounds UP to
    // 1024 KB under (bytes + 512) / 1024 — only 2 bytes apart yet split into
    // separate clusters. Bucketing must use floor division, not rounding.
    let a = candidate("Report.pdf", bytes: 1_023 * 1_024 + 511)
    let b = candidate("Report (2).pdf", bytes: 1_023 * 1_024 + 513)
    let ctx = QueueContext(candidates: [a, b])
    #expect(!ctx.isRedundantCopy(a))
    #expect(ctx.isRedundantCopy(b))
}

@Test func differentNamesAreNeverDuplicatesRegardlessOfSize() {
    let a = candidate("Report.pdf", bytes: 10_000)
    let b = candidate("Invoice.pdf", bytes: 10_000)
    let ctx = QueueContext(candidates: [a, b])
    #expect(!ctx.isRedundantCopy(a))
    #expect(!ctx.isRedundantCopy(b))
}

@Test func whenAllSuffixedKeeperFallsBackToOldest() {
    let older = candidate("Profile (2).pdf", bytes: 10_000, created: Date(timeIntervalSince1970: 1_000))
    let newer = candidate("Profile (3).pdf", bytes: 10_000, created: Date(timeIntervalSince1970: 2_000))
    let ctx = QueueContext(candidates: [older, newer])
    #expect(!ctx.isRedundantCopy(older))
    #expect(ctx.isRedundantCopy(newer))
}

@Test func extractedArchiveBesideMatchingDirectoryIsRedundant() {
    let zip = candidate("Cards.zip", bytes: 10_000)
    let dir = candidate("Cards", bytes: 0, isDirectory: true)
    let ctx = QueueContext(candidates: [zip, dir])
    #expect(ctx.isExtractedArchive(zip))
}

@Test func extractedArchiveMatchIsCaseInsensitive() {
    let zip = candidate("cards.ZIP", bytes: 10_000)
    let dir = candidate("Cards", bytes: 0, isDirectory: true)
    let ctx = QueueContext(candidates: [zip, dir])
    #expect(ctx.isExtractedArchive(zip))
}

@Test func zipWithoutSiblingDirectoryIsNotAnExtractedArchive() {
    let zip = candidate("Cards.zip", bytes: 10_000)
    let ctx = QueueContext(candidates: [zip])
    #expect(!ctx.isExtractedArchive(zip))
}

@Test func directoryItselfIsNeverAnExtractedArchive() {
    let dir = candidate("Cards", bytes: 0, isDirectory: true)
    let zip = candidate("Cards.zip", bytes: 10_000)
    let ctx = QueueContext(candidates: [dir, zip])
    #expect(!ctx.isExtractedArchive(dir))
}
