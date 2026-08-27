import Testing
import Foundation
@testable import DClutterCore

private func candidate(_ name: String) -> FileCandidate {
    FileCandidate(url: URL(fileURLWithPath: "/tmp/downloads/\(name)"), bytes: 1_024, lastOpened: nil, created: Date())
}

private func tempPersistenceURL() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("session-\(UUID().uuidString).json")
}

@MainActor
@Test func currentIsFirstCandidateInQueueOrder() {
    let a = candidate("a.pdf")
    let b = candidate("b.pdf")
    let session = DClutterSession(candidates: [a, b], persistenceURL: tempPersistenceURL())
    #expect(session.current?.id == a.id)
    #expect(session.totalCount == 2)
    #expect(session.remainingCount == 2)
}

@MainActor
@Test func emptyQueueHasNoCurrent() {
    let session = DClutterSession(candidates: [], persistenceURL: tempPersistenceURL())
    #expect(session.current == nil)
}

@MainActor
@Test func keepAdvancesToNextCandidate() {
    let a = candidate("a.pdf"); let b = candidate("b.pdf")
    let session = DClutterSession(candidates: [a, b], persistenceURL: tempPersistenceURL())
    session.keep()
    #expect(session.current?.id == b.id)
    #expect(session.remainingCount == 1)
}

@MainActor
@Test func stageMarksCandidateAndAdvances() {
    let a = candidate("a.pdf"); let b = candidate("b.pdf")
    let session = DClutterSession(candidates: [a, b], persistenceURL: tempPersistenceURL())
    session.stage()
    #expect(session.current?.id == b.id)
    #expect(session.stagedForCommit().map(\.id) == [a.id])
}

@MainActor
@Test func skipDefersToEndOfQueueWithoutChangingState() {
    let a = candidate("a.pdf"); let b = candidate("b.pdf")
    let session = DClutterSession(candidates: [a, b], persistenceURL: tempPersistenceURL())
    session.skip()
    #expect(session.current?.id == b.id) // a deferred, b now first non-deferred
    session.keep() // decides b
    #expect(session.current?.id == a.id) // a resurfaces once nothing else is pending
}

@MainActor
@Test func undoRevertsKeep() {
    let a = candidate("a.pdf"); let b = candidate("b.pdf")
    let session = DClutterSession(candidates: [a, b], persistenceURL: tempPersistenceURL())
    session.keep()
    #expect(session.canUndo)
    session.undo()
    #expect(session.current?.id == a.id)
    #expect(session.remainingCount == 2)
    #expect(!session.canUndo)
}

@MainActor
@Test func undoRevertsSkip() {
    let a = candidate("a.pdf"); let b = candidate("b.pdf")
    let session = DClutterSession(candidates: [a, b], persistenceURL: tempPersistenceURL())
    session.skip()
    session.undo()
    #expect(session.current?.id == a.id) // no longer deferred
}

@MainActor
@Test func undoWithNoHistoryIsANoOp() {
    let a = candidate("a.pdf")
    let session = DClutterSession(candidates: [a], persistenceURL: tempPersistenceURL())
    session.undo()
    #expect(session.current?.id == a.id)
}

@MainActor
@Test func multiLevelUndoWalksBackThroughHistory() {
    let a = candidate("a.pdf"); let b = candidate("b.pdf")
    let session = DClutterSession(candidates: [a, b], persistenceURL: tempPersistenceURL())
    session.keep()
    session.stage()
    session.undo()
    session.undo()
    #expect(session.current?.id == a.id)
    #expect(session.remainingCount == 2)
}

@MainActor
@Test func commitTrashedTransitionsStateAndClearsUndoHistory() {
    // A committed file must never come back via undo — it no longer exists
    // on disk at that path, so reverting it to .pending would show a card
    // for a file that isn't there.
    let a = candidate("a.pdf"); let b = candidate("b.pdf")
    let session = DClutterSession(candidates: [a, b], persistenceURL: tempPersistenceURL())
    session.stage() // stages a
    session.keep()  // decides b; history now [stage(a), keep(b)]
    #expect(session.canUndo)

    session.commitTrashed([a.url])

    #expect(session.stagedForCommit().isEmpty) // a is .trashed, not .staged
    #expect(!session.canUndo)                  // history cleared by the commit boundary
    session.undo()                              // no-op: nothing to undo
    #expect(session.current == nil)             // a stays .trashed, b stays .kept
}

@MainActor
@Test func reSkippingAnAlreadyDeferredFileRotatesItRatherThanHanging() {
    // Regression for the tail-of-session hang: once every remaining pending
    // file has been skipped, pressing skip again on the (now front-of-
    // deferred) candidate must rotate it to the back, not no-op.
    let a = candidate("a.pdf"); let b = candidate("b.pdf"); let c = candidate("c.pdf")
    let session = DClutterSession(candidates: [a, b, c], persistenceURL: tempPersistenceURL())
    session.skip() // defers a; current -> b
    session.skip() // defers b; current -> c
    session.skip() // defers c; nothing undeferred left, current -> a (first deferred)
    #expect(session.current?.id == a.id)

    session.skip() // re-skip a: rotates it to the back of the deferred list
    #expect(session.current?.id == b.id)
}

@MainActor
@Test func skippingTheOnlyRemainingPendingFileDoesNotGrowCanUndo() {
    // Since the file resurfaces immediately as `current` regardless of
    // where it sits in `deferred`, this skip is invisible to the user and
    // must not record a dead undo entry.
    let a = candidate("a.pdf"); let b = candidate("b.pdf")
    let session = DClutterSession(candidates: [a, b], persistenceURL: tempPersistenceURL())
    session.keep() // decides a; only b remains pending
    #expect(session.canUndo)
    session.undo()
    session.keep() // decides a again via a fresh history entry
    #expect(session.current?.id == b.id)

    session.skip() // b is the only pending file left; skip is a no-op on position
    #expect(session.current?.id == b.id)
    #expect(session.canUndo) // still true from the keep() above, not from skip()

    session.undo() // reverts the keep(), not a dead skip entry
    #expect(session.current?.id == a.id)
    #expect(!session.canUndo)
}

@MainActor
@Test func multiFileSkipOrderIsPreservedFirstSkippedResurfacesFirst() {
    let a = candidate("a.pdf"); let b = candidate("b.pdf"); let c = candidate("c.pdf")
    let session = DClutterSession(candidates: [a, b, c], persistenceURL: tempPersistenceURL())
    session.skip() // defers a; current -> b
    session.skip() // defers b; current -> c
    session.keep() // decides c

    #expect(session.current?.id == a.id) // a was deferred first, resurfaces first
    session.keep() // decides a
    #expect(session.current?.id == b.id)
}

@MainActor
@Test func commitTrashedIgnoresURLsThatWerentStaged() {
    let a = candidate("a.pdf")
    let session = DClutterSession(candidates: [a], persistenceURL: tempPersistenceURL())
    session.commitTrashed([a.url]) // a is still .pending — nothing to commit
    #expect(session.current?.id == a.id)
}

@MainActor
@Test func commitTrashedWithNothingActuallyTrashedPreservesUndoHistory() {
    // Reachable via ⌘⏎ with zero staged files, or a commit where every
    // trash attempt failed — neither should silently wipe the undo stack.
    let a = candidate("a.pdf"); let b = candidate("b.pdf")
    let session = DClutterSession(candidates: [a, b], persistenceURL: tempPersistenceURL())
    session.keep() // decides a; history now [keep(a)]
    #expect(session.canUndo)

    session.commitTrashed([]) // nothing staged, nothing trashed

    #expect(session.canUndo) // history must survive
    session.undo()
    #expect(session.current?.id == a.id)
}

@MainActor
@Test func decisionsArePersistedToDisk() throws {
    let a = candidate("a.pdf"); let b = candidate("b.pdf")
    let url = tempPersistenceURL()
    defer { try? FileManager.default.removeItem(at: url) }
    let session = DClutterSession(candidates: [a, b], persistenceURL: url)
    session.keep()
    #expect(FileManager.default.fileExists(atPath: url.path))
    let data = try Data(contentsOf: url)
    let snapshot = try JSONDecoder().decode(SessionSnapshot.self, from: data)
    #expect(snapshot.states[a.url.absoluteString] == .kept)
}

@MainActor
@Test func relaunchReconcilesPersistedStateForCandidatesStillPresent() {
    let a = candidate("a.pdf"); let b = candidate("b.pdf")
    let url = tempPersistenceURL()
    defer { try? FileManager.default.removeItem(at: url) }
    let first = DClutterSession(candidates: [a, b], persistenceURL: url)
    first.keep() // decides a

    let second = DClutterSession(candidates: [a, b], persistenceURL: url)
    #expect(second.current?.id == b.id) // a's .kept state survived relaunch
    #expect(second.remainingCount == 1)
}

@MainActor
@Test func relaunchAppendsNewCandidatesNotInPersistedSnapshot() {
    let a = candidate("a.pdf")
    let url = tempPersistenceURL()
    defer { try? FileManager.default.removeItem(at: url) }
    let first = DClutterSession(candidates: [a], persistenceURL: url)
    first.keep()

    let b = candidate("b.pdf") // newly downloaded since last launch
    let second = DClutterSession(candidates: [a, b], persistenceURL: url)
    #expect(second.current?.id == b.id)
    #expect(second.totalCount == 2)
}

@MainActor
@Test func relaunchDropsPersistedURLsNoLongerPresent() {
    let a = candidate("a.pdf"); let b = candidate("b.pdf")
    let url = tempPersistenceURL()
    defer { try? FileManager.default.removeItem(at: url) }
    let first = DClutterSession(candidates: [a, b], persistenceURL: url)
    first.skip() // defers a

    // b was manually deleted from Downloads outside the app before relaunch.
    let second = DClutterSession(candidates: [a], persistenceURL: url)
    #expect(second.totalCount == 1)
    #expect(second.current?.id == a.id) // deferred state also reconciled
}

// MARK: - Redo

@MainActor
@Test func redoReappliesAnUndoneKeep() {
    let a = candidate("a.pdf"); let b = candidate("b.pdf")
    let session = DClutterSession(candidates: [a, b], persistenceURL: tempPersistenceURL())
    session.keep()
    session.undo()
    #expect(session.current?.id == a.id)
    #expect(session.canRedo)

    session.redo()
    #expect(session.current?.id == b.id)   // a is decided again
    #expect(!session.canRedo)
}

@MainActor
@Test func redoReappliesAnUndoneStageIncludingItsCommitState() {
    let a = candidate("a.pdf"); let b = candidate("b.pdf")
    let session = DClutterSession(candidates: [a, b], persistenceURL: tempPersistenceURL())
    session.stage()
    session.undo()
    #expect(session.stagedForCommit().isEmpty)

    session.redo()
    #expect(session.stagedForCommit().map(\.id) == [a.id])
}

@MainActor
@Test func redoReappliesAnUndoneSkip() {
    let a = candidate("a.pdf"); let b = candidate("b.pdf")
    let session = DClutterSession(candidates: [a, b], persistenceURL: tempPersistenceURL())
    session.skip()
    session.undo()
    #expect(session.current?.id == a.id)

    session.redo()
    #expect(session.current?.id == b.id)   // a deferred again
}

@MainActor
@Test func makingANewDecisionClearsTheRedoStack() {
    // Standard undo/redo semantics: branching discards the redone future.
    let a = candidate("a.pdf"); let b = candidate("b.pdf")
    let session = DClutterSession(candidates: [a, b], persistenceURL: tempPersistenceURL())
    session.keep()
    session.undo()
    #expect(session.canRedo)

    session.stage()          // a new decision on the same candidate
    #expect(!session.canRedo)
}

@MainActor
@Test func redoWithNothingUndoneIsANoOp() {
    let a = candidate("a.pdf")
    let session = DClutterSession(candidates: [a], persistenceURL: tempPersistenceURL())
    session.redo()
    #expect(session.current?.id == a.id)
    #expect(!session.canRedo)
}

@MainActor
@Test func commitClearsRedoAlongsideUndo() {
    // A committed file must not be reachable by redo any more than by undo.
    let a = candidate("a.pdf"); let b = candidate("b.pdf")
    let session = DClutterSession(candidates: [a, b], persistenceURL: tempPersistenceURL())
    session.stage()
    session.undo()
    #expect(session.canRedo)

    session.stage()                       // re-stage a
    session.commitTrashed([a.url])
    #expect(!session.canRedo)
    #expect(!session.canUndo)
}

// MARK: - Reset

@MainActor
@Test func resetReturnsEveryUndecidedFileToPending() {
    let a = candidate("a.pdf"); let b = candidate("b.pdf"); let c = candidate("c.pdf")
    let session = DClutterSession(candidates: [a, b, c], persistenceURL: tempPersistenceURL())
    session.keep()
    session.stage()
    session.skip()

    session.reset()

    #expect(session.current?.id == a.id)
    #expect(session.remainingCount == 3)
    #expect(session.stagedForCommit().isEmpty)
    #expect(!session.canUndo)
    #expect(!session.canRedo)
}

@MainActor
@Test func resetNeverRevivesAlreadyTrashedFiles() {
    // The files are gone from disk — bringing them back into the queue
    // would show cards for paths that no longer exist.
    let a = candidate("a.pdf"); let b = candidate("b.pdf")
    let session = DClutterSession(candidates: [a, b], persistenceURL: tempPersistenceURL())
    session.stage()
    session.commitTrashed([a.url])

    session.reset()

    #expect(session.current?.id == b.id)
    #expect(session.remainingCount == 1)
    #expect(session.states[a.url] == .trashed)
}

@MainActor
@Test func resetIsPersistedSoItSurvivesRelaunch() {
    let a = candidate("a.pdf"); let b = candidate("b.pdf")
    let url = tempPersistenceURL()
    defer { try? FileManager.default.removeItem(at: url) }
    let first = DClutterSession(candidates: [a, b], persistenceURL: url)
    first.keep()
    first.reset()

    let second = DClutterSession(candidates: [a, b], persistenceURL: url)
    #expect(second.current?.id == a.id)
    #expect(second.remainingCount == 2)
}
