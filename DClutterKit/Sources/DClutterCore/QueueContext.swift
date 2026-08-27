//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import Foundation

/// Precomputed cross-candidate facts the scorer needs: which files are
/// redundant copies of another, and which archives have already been
/// extracted beside themselves. See §4 of the plan for the matching rules.
public struct QueueContext: Sendable {
    private let redundantCopyIDs: Set<UUID>
    private let extractedArchiveIDs: Set<UUID>
    private let clusterSizeByID: [UUID: Int]

    public init(candidates: [FileCandidate]) {
        let (redundant, clusterSize) = Self.findDuplicateInfo(in: candidates)
        redundantCopyIDs = redundant
        clusterSizeByID = clusterSize
        extractedArchiveIDs = Self.findExtractedArchives(in: candidates)
    }

    public func isRedundantCopy(_ candidate: FileCandidate) -> Bool {
        redundantCopyIDs.contains(candidate.id)
    }

    public func isExtractedArchive(_ candidate: FileCandidate) -> Bool {
        extractedArchiveIDs.contains(candidate.id)
    }

    public func duplicateCount(for candidate: FileCandidate) -> Int {
        clusterSizeByID[candidate.id] ?? 1
    }

    // MARK: - Duplicate detection (filename + size, no hashing)

    private struct NormalizedName {
        let normalized: String
        let hadCopySuffix: Bool
    }

    /// Strips copy suffixes: `foo (2).pdf` -> `foo.pdf`, `foo copy 3.pdf` -> `foo.pdf`.
    private static func normalize(stem: String) -> NormalizedName {
        var result = stem
        var hadSuffix = false

        if let range = result.range(of: #"\s\(\d+\)$"#, options: .regularExpression) {
            result.removeSubrange(range)
            hadSuffix = true
        }
        if let range = result.range(of: #"\s+copy(\s+\d+)?$"#, options: [.regularExpression, .caseInsensitive]) {
            result.removeSubrange(range)
            hadSuffix = true
        }

        return NormalizedName(normalized: result, hadCopySuffix: hadSuffix)
    }

    private static func findDuplicateInfo(in candidates: [FileCandidate]) -> (redundant: Set<UUID>, clusterSize: [UUID: Int]) {
        struct ClusterKey: Hashable {
            let normalizedName: String
            let bucketedKB: Int64
        }

        var clusters: [ClusterKey: [(candidate: FileCandidate, hadCopySuffix: Bool)]] = [:]

        for c in candidates where !c.isDirectory {
            let stem = c.url.deletingPathExtension().lastPathComponent
            let ext = c.url.pathExtension
            let normalizedStem = normalize(stem: stem)
            let normalizedName = ext.isEmpty
                ? normalizedStem.normalized.lowercased()
                : "\(normalizedStem.normalized.lowercased()).\(ext.lowercased())"
            // Floor, not round: rounding can put two members of the same
            // duplicate pair on opposite sides of a .5 KB boundary and
            // split them into separate clusters. See QueueContextTests.
            let bucketedKB = c.bytes / 1024
            let key = ClusterKey(normalizedName: normalizedName, bucketedKB: bucketedKB)
            clusters[key, default: []].append((c, normalizedStem.hadCopySuffix))
        }

        var redundant: Set<UUID> = []
        var clusterSize: [UUID: Int] = [:]
        for members in clusters.values where members.count > 1 {
            let unsuffixed = members.filter { !$0.hadCopySuffix }
            let keeper: FileCandidate
            if unsuffixed.count == 1 {
                keeper = unsuffixed[0].candidate
            } else if unsuffixed.count > 1 {
                keeper = unsuffixed.min { $0.candidate.created < $1.candidate.created }!.candidate
            } else {
                keeper = members.min { $0.candidate.created < $1.candidate.created }!.candidate
            }
            let clusterCount = members.count
            for member in members {
                clusterSize[member.candidate.id] = clusterCount
                if member.candidate.id != keeper.id {
                    redundant.insert(member.candidate.id)
                }
            }
        }
        return (redundant: redundant, clusterSize: clusterSize)
    }

    // MARK: - Extracted archive detection

    private static func findExtractedArchives(in candidates: [FileCandidate]) -> Set<UUID> {
        let directoryNames = Set(
            candidates.filter(\.isDirectory).map { $0.url.lastPathComponent.lowercased() }
        )

        var extracted: Set<UUID> = []
        for c in candidates where !c.isDirectory && c.url.pathExtension.lowercased() == "zip" {
            let stem = c.url.deletingPathExtension().lastPathComponent.lowercased()
            if directoryNames.contains(stem) {
                extracted.insert(c.id)
            }
        }
        return extracted
    }
}
