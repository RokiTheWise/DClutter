//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import Testing
import Foundation
@testable import DClutterCore

private let now = Date(timeIntervalSince1970: 1_700_000_000)

private func candidate(
    name: String = "example.dat",
    bytes: Int64 = 1_024,
    lastOpened: Date? = nil,
    created: Date = now,
    modified: Date? = nil,
    sourceURL: URL? = nil,
    isDirectory: Bool = false
) -> FileCandidate {
    FileCandidate(
        url: URL(fileURLWithPath: "/tmp/downloads/\(name)"),
        bytes: bytes,
        lastOpened: lastOpened,
        created: created,
        modified: modified,
        sourceURL: sourceURL,
        isDirectory: isDirectory
    )
}

// MARK: - Size term

@Test func sizeBelowOneKBFloorsAtZeroPoints() {
    let c = candidate(bytes: 100, created: now)
    let ctx = QueueContext(candidates: [c])
    let score = QueueScorer.score(c, in: ctx, now: now)
    // No staleness (created == now), no other bonuses — size term must be 0.
    #expect(score == 0)
}

@Test func sizeContributesLog2MinusTen() {
    let c = candidate(bytes: 1_048_576, created: now) // 1 MB
    let ctx = QueueContext(candidates: [c])
    let score = QueueScorer.score(c, in: ctx, now: now)
    #expect(abs(score - 10.0) < 0.0001)
}

// MARK: - Staleness term

@Test func stalenessIsZeroWhenReferenceDateIsNow() {
    let c = candidate(bytes: 1_024, lastOpened: now, created: now)
    let ctx = QueueContext(candidates: [c])
    let score = QueueScorer.score(c, in: ctx, now: now)
    #expect(score == 0)
}

@Test func stalenessSaturatesAtHalfLife() {
    let weights = ScoreWeights()
    let reference = now.addingTimeInterval(-weights.halfLife * 86_400)
    let c = candidate(bytes: 1_024, lastOpened: reference)
    let ctx = QueueContext(candidates: [c])
    let score = QueueScorer.score(c, in: ctx, now: now, weights: weights)
    #expect(abs(score - weights.stale) < 0.0001)
}

@Test func stalenessDoesNotExceedCapBeyondHalfLife() {
    let weights = ScoreWeights()
    let reference = now.addingTimeInterval(-weights.halfLife * 86_400 * 3)
    let c = candidate(bytes: 1_024, lastOpened: reference)
    let ctx = QueueContext(candidates: [c])
    let score = QueueScorer.score(c, in: ctx, now: now, weights: weights)
    #expect(abs(score - weights.stale) < 0.0001)
}

@Test func stalenessFallsBackToModifiedWhenLastOpenedMissing() {
    let weights = ScoreWeights()
    let modified = now.addingTimeInterval(-weights.halfLife * 86_400)
    let c = candidate(bytes: 1_024, lastOpened: nil, created: now, modified: modified)
    let ctx = QueueContext(candidates: [c])
    let score = QueueScorer.score(c, in: ctx, now: now, weights: weights)
    #expect(abs(score - weights.stale) < 0.0001)
}

@Test func stalenessFallsBackToCreatedWhenLastOpenedAndModifiedMissing() {
    let weights = ScoreWeights()
    let created = now.addingTimeInterval(-weights.halfLife * 86_400)
    let c = candidate(bytes: 1_024, lastOpened: nil, created: created, modified: nil)
    let ctx = QueueContext(candidates: [c])
    let score = QueueScorer.score(c, in: ctx, now: now, weights: weights)
    #expect(abs(score - weights.stale) < 0.0001)
}

// MARK: - Unopened bonus

@Test func unopenedBonusAppliesWhenNeverOpenedButHasSourceURL() {
    let weights = ScoreWeights()
    let c = candidate(bytes: 1_024, lastOpened: nil, created: now, sourceURL: URL(string: "https://example.com/f")!)
    let ctx = QueueContext(candidates: [c])
    let score = QueueScorer.score(c, in: ctx, now: now, weights: weights)
    #expect(abs(score - weights.unopened) < 0.0001)
}

@Test func unopenedBonusDoesNotApplyWhenOpened() {
    let c = candidate(bytes: 1_024, lastOpened: now, created: now, sourceURL: URL(string: "https://example.com/f")!)
    let ctx = QueueContext(candidates: [c])
    let score = QueueScorer.score(c, in: ctx, now: now)
    #expect(score == 0)
}

@Test func unopenedBonusDoesNotApplyWithoutSourceURL() {
    let c = candidate(bytes: 1_024, lastOpened: nil, created: now, sourceURL: nil)
    let ctx = QueueContext(candidates: [c])
    let score = QueueScorer.score(c, in: ctx, now: now)
    #expect(score == 0)
}

// MARK: - Duplicate bonus

@Test func duplicateBonusAppliesToRedundantCopyOnly() {
    let weights = ScoreWeights()
    let keeper = candidate(name: "Report.pdf", bytes: 1_024, lastOpened: now, created: now)
    let copy = candidate(name: "Report (2).pdf", bytes: 1_024, lastOpened: now, created: now)
    let ctx = QueueContext(candidates: [keeper, copy])
    #expect(QueueScorer.score(keeper, in: ctx, now: now, weights: weights) == 0)
    #expect(abs(QueueScorer.score(copy, in: ctx, now: now, weights: weights) - weights.duplicate) < 0.0001)
}

// MARK: - Extracted archive bonus

@Test func archiveBonusAppliesToZipWithExtractedSibling() {
    let weights = ScoreWeights()
    let zip = candidate(name: "Cards.zip", bytes: 1_024, lastOpened: now, created: now)
    let dir = candidate(name: "Cards", bytes: 0, lastOpened: now, created: now, isDirectory: true)
    let ctx = QueueContext(candidates: [zip, dir])
    #expect(abs(QueueScorer.score(zip, in: ctx, now: now, weights: weights) - weights.archive) < 0.0001)
}

// MARK: - Ambiguous penalty

@Test func ambiguousPenaltyAppliesWhenNoSourceAndGenericName() {
    let weights = ScoreWeights()
    let c = candidate(name: "IMG_1234.jpg", bytes: 1_024, lastOpened: now, created: now, sourceURL: nil)
    let ctx = QueueContext(candidates: [c])
    let score = QueueScorer.score(c, in: ctx, now: now, weights: weights)
    #expect(abs(score - (-weights.ambiguous)) < 0.0001)
}

@Test func ambiguousPenaltyDoesNotApplyWithSourceURL() {
    let c = candidate(name: "IMG_1234.jpg", bytes: 1_024, lastOpened: now, created: now, sourceURL: URL(string: "https://example.com/f")!)
    let ctx = QueueContext(candidates: [c])
    let score = QueueScorer.score(c, in: ctx, now: now)
    #expect(score == 0)
}

@Test func ambiguousPenaltyDoesNotApplyForDescriptiveName() {
    let c = candidate(name: "Quarterly Report.pdf", bytes: 1_024, lastOpened: now, created: now, sourceURL: nil)
    let ctx = QueueContext(candidates: [c])
    let score = QueueScorer.score(c, in: ctx, now: now)
    #expect(score == 0)
}

// MARK: - Additivity: signals never zero each other out

@Test func signalsAreAdditiveNotMultiplicative() {
    // A large, stale, unopened, duplicated file should sum all four terms.
    let weights = ScoreWeights()
    let reference = now.addingTimeInterval(-weights.halfLife * 86_400)
    let keeper = candidate(name: "Big.zip", bytes: 4 * 1_073_741_824, lastOpened: nil, created: now, modified: reference, sourceURL: URL(string: "https://example.com/f")!)
    let copy = candidate(name: "Big (2).zip", bytes: 4 * 1_073_741_824, lastOpened: nil, created: now, modified: reference, sourceURL: URL(string: "https://example.com/f")!)
    let ctx = QueueContext(candidates: [keeper, copy])
    let expectedSizeTerm = max(0, log2(Double(4 * 1_073_741_824)) - 10)
    let expected = expectedSizeTerm + weights.stale + weights.unopened + weights.duplicate
    let score = QueueScorer.score(copy, in: ctx, now: now, weights: weights)
    #expect(abs(score - expected) < 0.0001)
}

// MARK: - Custom weights

@Test func customWeightsAreRespected() {
    var weights = ScoreWeights()
    weights.unopened = 99.0
    let c = candidate(bytes: 1_024, lastOpened: nil, created: now, sourceURL: URL(string: "https://example.com/f")!)
    let ctx = QueueContext(candidates: [c])
    let score = QueueScorer.score(c, in: ctx, now: now, weights: weights)
    #expect(abs(score - 99.0) < 0.0001)
}

// MARK: - Ranking

@Test func rankOrdersCandidatesByDescendingScore() {
    let low = candidate(name: "low.dat", bytes: 1_024, lastOpened: now, created: now)
    let high = candidate(name: "high.dat", bytes: 1_073_741_824, lastOpened: now, created: now)
    let ranked = QueueScorer.rank([low, high], now: now)
    #expect(ranked.map(\.candidate.id) == [high.id, low.id])
    #expect(ranked[0].score > ranked[1].score)
}
