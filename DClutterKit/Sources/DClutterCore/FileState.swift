//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import Foundation

/// §3 session state machine. `.staged` is "marked for trash, not yet
/// committed"; `.trashed` is the terminal post-commit state — kept distinct
/// so undo can never resurrect a file that's already gone (see
/// DClutterSession.commitTrashed in Task 4).
public enum FileState: Codable, Equatable, Sendable {
    case pending
    case kept
    case staged
    case trashed
    case moved(to: URL)
}
