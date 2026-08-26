//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import Foundation

/// §4 tuning knobs. The model is additive by design — an earlier
/// multiplicative version let staleness annihilate size — so every signal
/// contributes points independently; none can zero out another.
public struct ScoreWeights: Sendable {
    public var stale: Double
    public var unopened: Double
    public var duplicate: Double
    public var archive: Double
    public var ambiguous: Double
    public var halfLife: Double

    public init(
        stale: Double = 10.0,
        unopened: Double = 2.0,
        duplicate: Double = 8.0,
        archive: Double = 4.0,
        ambiguous: Double = 5.0,
        halfLife: Double = 90.0
    ) {
        self.stale = stale
        self.unopened = unopened
        self.duplicate = duplicate
        self.archive = archive
        self.ambiguous = ambiguous
        self.halfLife = halfLife
    }
}

/// A candidate paired with the score that placed it in the queue.
public struct ScoredCandidate: Sendable {
    public let candidate: FileCandidate
    public let score: Double
}

/// Orders `FileCandidate`s by how actionable they are, per the validated
/// model in §4. Port target, not a design surface — see the plan doc before
/// changing any weight.
public enum QueueScorer {
    public static func score(
        _ c: FileCandidate,
        in ctx: QueueContext,
        now: Date = Date(),
        weights: ScoreWeights = ScoreWeights()
    ) -> Double {
        var points = 0.0

        // Size: floor at 1KB, not 1MB — see §4 for why a 1MB floor ties too many files.
        points += max(0, log2(Double(max(c.bytes, 1024))) - 10)

        let reference = c.lastOpened ?? c.modified ?? c.created
        let days = now.timeIntervalSince(reference) / 86_400
        points += weights.stale * max(0, min(days / weights.halfLife, 1.0))

        if c.lastOpened == nil && c.sourceURL != nil { points += weights.unopened }
        if ctx.isRedundantCopy(c) { points += weights.duplicate }
        if ctx.isExtractedArchive(c) { points += weights.archive }
        if c.sourceURL == nil && c.hasGenericName { points -= weights.ambiguous }

        return points
    }

    /// Scores every candidate against a shared `QueueContext` and returns
    /// them ordered highest score first — the presentation order for triage.
    public static func rank(
        _ candidates: [FileCandidate],
        now: Date = Date(),
        weights: ScoreWeights = ScoreWeights()
    ) -> [ScoredCandidate] {
        let ctx = QueueContext(candidates: candidates)
        return candidates
            .map { ScoredCandidate(candidate: $0, score: score($0, in: ctx, now: now, weights: weights)) }
            .sorted { $0.score > $1.score }
    }
}
