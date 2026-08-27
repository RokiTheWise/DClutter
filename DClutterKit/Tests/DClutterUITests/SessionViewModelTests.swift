//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import Testing
import Foundation
import DClutterCore
@testable import DClutterPlatform
@testable import DClutterUI

/// `confirmCommit()` is the function that actually trashes user files and
/// orchestrates partial failure — nothing else in the codebase exercises
/// it, so these tests are the sole automated coverage of that boundary.
private func candidate(_ name: String) -> FileCandidate {
    FileCandidate(url: URL(fileURLWithPath: "/tmp/downloads/\(name)"), bytes: 1_024, lastOpened: nil, created: Date())
}

private func tempPersistenceURL() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("session-\(UUID().uuidString).json")
}

private struct TestTrashError: Error {}

@MainActor
@Test func confirmCommitAllSucceedClosesSheetAndTrashesEverything() {
    let a = candidate("a.pdf"); let b = candidate("b.pdf")
    let session = DClutterSession(candidates: [a, b], persistenceURL: tempPersistenceURL())
    session.stage() // stages a, current -> b
    session.stage() // stages b
    let actions = FileActions(executor: { _ in nil })
    let viewModel = SessionViewModel(session: session, fileActions: actions)
    viewModel.showCommitSheet = true

    viewModel.confirmCommit()

    #expect(viewModel.showCommitSheet == false)
    #expect(viewModel.commitError == nil)
    #expect(session.states[a.url] == .trashed)
    #expect(session.states[b.url] == .trashed)
    #expect(viewModel.stagedForCommit.isEmpty)
}

@MainActor
@Test func confirmCommitAllFailKeepsSheetOpenAndLeavesFilesStaged() {
    let a = candidate("a.pdf"); let b = candidate("b.pdf")
    let session = DClutterSession(candidates: [a, b], persistenceURL: tempPersistenceURL())
    session.stage()
    session.stage()
    let actions = FileActions(executor: { _ in throw TestTrashError() })
    let viewModel = SessionViewModel(session: session, fileActions: actions)
    viewModel.showCommitSheet = true

    viewModel.confirmCommit()

    #expect(viewModel.showCommitSheet == true) // stays open so the error is visible
    #expect(viewModel.commitError != nil)
    #expect(session.states[a.url] == .staged)
    #expect(session.states[b.url] == .staged)
    #expect(Set(viewModel.stagedForCommit.map(\.id)) == Set([a.id, b.id]))
}

@MainActor
@Test func confirmCommitPartialFailureOnlyTransitionsTheSuccesses() {
    let a = candidate("a.pdf"); let b = candidate("b.pdf"); let c = candidate("c.pdf")
    let session = DClutterSession(candidates: [a, b, c], persistenceURL: tempPersistenceURL())
    session.stage() // stages a
    session.stage() // stages b
    session.stage() // stages c
    let failingURL = b.url
    let actions = FileActions(executor: { url in
        if url == failingURL { throw TestTrashError() }
        return nil
    })
    let viewModel = SessionViewModel(session: session, fileActions: actions)
    viewModel.showCommitSheet = true

    viewModel.confirmCommit()

    #expect(viewModel.showCommitSheet == true) // b's failure keeps the sheet open
    #expect(viewModel.commitError != nil)
    #expect(session.states[a.url] == .trashed)
    #expect(session.states[b.url] == .staged) // the failure stays staged, not silently dropped
    #expect(session.states[c.url] == .trashed)
    #expect(viewModel.stagedForCommit.map(\.id) == [b.id])
}
