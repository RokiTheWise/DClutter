//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

//  Runs the cases in `fixtures/` at the repository root. The Windows app runs
//  the same files; see `fixtures/README.md` for the format. A weight or
//  matching rule that changes on one platform and not the other fails here.

import Testing
import Foundation
@testable import DClutterCore

private let secondsPerDay = 86_400.0

// MARK: - Fixture decoding

private struct WeightOverrides: Decodable {
    var stale: Double?
    var unopened: Double?
    var duplicate: Double?
    var archive: Double?
    var ambiguous: Double?
    var halfLife: Double?

    func applied() -> ScoreWeights {
        var w = ScoreWeights()
        if let stale { w.stale = stale }
        if let unopened { w.unopened = unopened }
        if let duplicate { w.duplicate = duplicate }
        if let archive { w.archive = archive }
        if let ambiguous { w.ambiguous = ambiguous }
        if let halfLife { w.halfLife = halfLife }
        return w
    }
}

private struct CandidateSpec: Decodable {
    let id: String
    let name: String
    let bytes: Int64
    let isDirectory: Bool
    let createdDaysAgo: Double
    let modifiedDaysAgo: Double?
    let lastOpenedDaysAgo: Double?
    let sourceURL: String?

    // Written out because synthesised `Decodable` ignores property defaults
    // for absent keys, and most fixture candidates omit most of these.
    private enum CodingKeys: String, CodingKey {
        case id, name, bytes, isDirectory, createdDaysAgo, modifiedDaysAgo, lastOpenedDaysAgo, sourceURL
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        bytes = try c.decode(Int64.self, forKey: .bytes)
        isDirectory = try c.decodeIfPresent(Bool.self, forKey: .isDirectory) ?? false
        createdDaysAgo = try c.decodeIfPresent(Double.self, forKey: .createdDaysAgo) ?? 0
        modifiedDaysAgo = try c.decodeIfPresent(Double.self, forKey: .modifiedDaysAgo)
        lastOpenedDaysAgo = try c.decodeIfPresent(Double.self, forKey: .lastOpenedDaysAgo)
        sourceURL = try c.decodeIfPresent(String.self, forKey: .sourceURL)
    }
}

private struct Expectation: Decodable {
    let id: String
    let score: Double?
    let redundantCopy: Bool?
    let extractedArchive: Bool?
    let duplicateCount: Int?
}

private struct Case: Decodable {
    let name: String
    var weights: WeightOverrides?
    let candidates: [CandidateSpec]
    let expect: [Expectation]
    let expectRank: [String]?
}

private struct QueueFixture: Decodable {
    let schemaVersion: Int
    let now: Double
    let tolerance: Double
    let cases: [Case]
}

private struct GenericNamesFixture: Decodable {
    let schemaVersion: Int
    let generic: [String]
    let descriptive: [String]
}

// MARK: - Loading

/// The fixtures sit at the repository root so both repos hold them at the
/// same path. Resolved from `#filePath` rather than a bundle resource for
/// that reason — the package is a subdirectory, the fixtures are not.
private func fixturesDirectory() -> URL {
    URL(fileURLWithPath: #filePath)          // …/DClutterKit/Tests/DClutterCoreTests/SharedFixturesTests.swift
        .deletingLastPathComponent()         // …/DClutterCoreTests
        .deletingLastPathComponent()         // …/Tests
        .deletingLastPathComponent()         // …/DClutterKit
        .deletingLastPathComponent()         // repository root
        .appendingPathComponent("fixtures")
}

private func load<T: Decodable>(_ file: String, as type: T.Type) throws -> T {
    let url = fixturesDirectory().appendingPathComponent(file)
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(T.self, from: data)
}

private func candidate(from spec: CandidateSpec, now: Double) -> FileCandidate {
    let daysAgo = { (days: Double) in Date(timeIntervalSince1970: now - days * secondsPerDay) }
    return FileCandidate(
        url: URL(fileURLWithPath: "/downloads").appendingPathComponent(spec.name),
        bytes: spec.bytes,
        lastOpened: spec.lastOpenedDaysAgo.map(daysAgo),
        created: daysAgo(spec.createdDaysAgo),
        modified: spec.modifiedDaysAgo.map(daysAgo),
        sourceURL: spec.sourceURL.flatMap(URL.init(string:)),
        isDirectory: spec.isDirectory
    )
}

// MARK: - Tests

@Test func sharedQueueFixtureCasesMatch() throws {
    let fixture = try load("queue.json", as: QueueFixture.self)
    #expect(fixture.schemaVersion == 1, "unsupported queue.json schema")

    let now = Date(timeIntervalSince1970: fixture.now)
    var failures: [String] = []

    for testCase in fixture.cases {
        let weights = (testCase.weights ?? WeightOverrides()).applied()
        let candidates = testCase.candidates.map { candidate(from: $0, now: fixture.now) }
        // Fixture ids are strings; FileCandidate.id is a UUID. Keep both maps.
        let byFixtureID = Dictionary(
            uniqueKeysWithValues: zip(testCase.candidates.map(\.id), candidates)
        )
        let fixtureIDByUUID = Dictionary(
            uniqueKeysWithValues: zip(candidates.map(\.id), testCase.candidates.map(\.id))
        )
        let ctx = QueueContext(candidates: candidates)

        for expected in testCase.expect {
            guard let c = byFixtureID[expected.id] else {
                failures.append("\(testCase.name): no candidate \(expected.id)")
                continue
            }

            if let want = expected.score {
                let got = QueueScorer.score(c, in: ctx, now: now, weights: weights)
                if abs(got - want) > fixture.tolerance {
                    failures.append("\(testCase.name): \(expected.id) score \(got), expected \(want)")
                }
            }
            if let want = expected.redundantCopy {
                let got = ctx.isRedundantCopy(c)
                if got != want {
                    failures.append("\(testCase.name): \(expected.id) redundantCopy \(got), expected \(want)")
                }
            }
            if let want = expected.extractedArchive {
                let got = ctx.isExtractedArchive(c)
                if got != want {
                    failures.append("\(testCase.name): \(expected.id) extractedArchive \(got), expected \(want)")
                }
            }
            if let want = expected.duplicateCount {
                let got = ctx.duplicateCount(for: c)
                if got != want {
                    failures.append("\(testCase.name): \(expected.id) duplicateCount \(got), expected \(want)")
                }
            }
        }

        if let want = testCase.expectRank {
            let got = QueueScorer.rank(candidates, now: now, weights: weights)
                .map { fixtureIDByUUID[$0.candidate.id] ?? "?" }
            if got != want {
                failures.append("\(testCase.name): rank \(got), expected \(want)")
            }
        }
    }

    #expect(failures.isEmpty, "\(failures.count) failing expectation(s):\n\(failures.joined(separator: "\n"))")
}

@Test func sharedGenericNameFixtureCasesMatch() throws {
    let fixture = try load("generic-names.json", as: GenericNamesFixture.self)
    #expect(fixture.schemaVersion == 1, "unsupported generic-names.json schema")

    func named(_ name: String) -> FileCandidate {
        FileCandidate(
            url: URL(fileURLWithPath: "/downloads").appendingPathComponent(name),
            bytes: 1_024,
            lastOpened: nil,
            created: Date(timeIntervalSince1970: 0)
        )
    }

    var failures: [String] = []
    for name in fixture.generic where !named(name).hasGenericName {
        failures.append("expected \"\(name)\" to be generic")
    }
    for name in fixture.descriptive where named(name).hasGenericName {
        failures.append("expected \"\(name)\" to be descriptive")
    }

    #expect(failures.isEmpty, "\(failures.joined(separator: "\n"))")
}
