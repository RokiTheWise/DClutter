//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.
//  See <http://www.apache.org/licenses/LICENSE-2.0> for details.

import Foundation

/// The only seam between DClutter and the host operating system.
///
/// A port reimplements this and nothing else. Keep it narrow.
public protocol FileMetadataProvider: Sendable {
    func candidates(in folder: URL) async throws -> [FileCandidate]
}
