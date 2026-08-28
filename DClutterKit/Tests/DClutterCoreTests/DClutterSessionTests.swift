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

// MARK: - Trashed count and unstaging

@MainActor
@Test func trashedCountReflectsCommittedFilesOnly() {
    let a = candidate("a.pdf"); let b = candidate("b.pdf")
    let session = DClutterSession(candidates: [a, b], persistenceURL: tempPersistenceURL())
    session.stage()
    #expect(session.trashedCount == 0)   // staged is not yet trashed

    session.commitTrashed([a.url])
    #expect(session.trashedCount == 1)
}

@MainActor
@Test func unstageReturnsAFileToKeptSoItLeavesTheCommitList() {
    // Unticking a file in the commit sheet means "actually, keep this" —
    // it must drop out of stagedForCommit without being trashed, and
    // without coming back around as an undecided card.
    let a = candidate("a.pdf"); let b = candidate("b.pdf")
    let session = DClutterSession(candidates: [a, b], persistenceURL: tempPersistenceURL())
    session.stage()   // stages a
    session.stage()   // stages b
    #expect(session.stagedForCommit().count == 2)

    session.unstage([a.url])

    #expect(session.stagedForCommit().map(\.id) == [b.id])
    #expect(session.states[a.url] == .kept)
    #expect(session.remainingCount == 0)   // not resurfaced as pending
}

@MainActor
@Test func unstageIgnoresFilesThatArentStaged() {
    let a = candidate("a.pdf")
    let session = DClutterSession(candidates: [a], persistenceURL: tempPersistenceURL())
    session.keep()
    session.unstage([a.url])
    #expect(session.states[a.url] == .kept)   // untouched, not clobbered
}

// MARK: - Sorted-since-commit counter

@MainActor
@Test func sortedCountRisesWithDecisionsAndResetsOnCommit() {
    let a = candidate("a.pdf"); let b = candidate("b.pdf"); let c = candidate("c.pdf")
    let session = DClutterSession(candidates: [a, b, c], persistenceURL: tempPersistenceURL())
    session.keep()
    session.stage()
    #expect(session.sortedSinceLastCommit == 2)

    session.commitTrashed([b.url])
    #expect(session.sortedSinceLastCommit == 0)   // commit is the checkpoint
    #expect(session.remainingCount == 1)          // only c is still undecided
}

@MainActor
@Test func sortedCountFollowsUndoAndRedo() {
    let a = candidate("a.pdf"); let b = candidate("b.pdf")
    let session = DClutterSession(candidates: [a, b], persistenceURL: tempPersistenceURL())
    session.keep()
    #expect(session.sortedSinceLastCommit == 1)

    session.undo()
    #expect(session.sortedSinceLastCommit == 0)

    session.redo()
    #expect(session.sortedSinceLastCommit == 1)
}

@MainActor
@Test func skippingIsNotSorting() {
    // A skip defers a decision rather than making one, so it must not
    // inflate the "sorted" figure.
    let a = candidate("a.pdf"); let b = candidate("b.pdf")
    let session = DClutterSession(candidates: [a, b], persistenceURL: tempPersistenceURL())
    session.skip()
    #expect(session.sortedSinceLastCommit == 0)
}

@MainActor
@Test func resetClearsTheSortedCount() {
    let a = candidate("a.pdf"); let b = candidate("b.pdf")
    let session = DClutterSession(candidates: [a, b], persistenceURL: tempPersistenceURL())
    session.keep()
    session.reset()
    #expect(session.sortedSinceLastCommit == 0)
}

// MARK: - Rename

@MainActor
@Test func renameMovesQueueStateOntoTheNewURL() {
    // Everything in the session is keyed by URL, so a rename has to carry
    // the candidate's state, deferral and history across or the file is
    // orphaned and re-queued as if never seen.
    let a = candidate("a.pdf"); let b = candidate("b.pdf")
    let session = DClutterSession(candidates: [a, b], persistenceURL: tempPersistenceURL())
    let renamed = a.url.deletingLastPathComponent().appendingPathComponent("grades-2024.pdf")

    session.rename(a.url, to: renamed)

    #expect(session.current?.url == renamed)
    #expect(session.current?.id == a.id)      // same candidate, new name
    #expect(session.totalCount == 2)
}

@MainActor
@Test func renamePreservesAnExistingDecision() {
    let a = candidate("a.pdf"); let b = candidate("b.pdf")
    let session = DClutterSession(candidates: [a, b], persistenceURL: tempPersistenceURL())
    session.stage()   // stages a
    let renamed = a.url.deletingLastPathComponent().appendingPathComponent("renamed.pdf")

    session.rename(a.url, to: renamed)

    #expect(session.stagedForCommit().map(\.url) == [renamed])
    #expect(session.states[renamed] == .staged)
    #expect(session.states[a.url] == nil)     // no orphan left behind
}

@MainActor
@Test func renameFollowsAFileThroughUndo() {
    let a = candidate("a.pdf"); let b = candidate("b.pdf")
    let session = DClutterSession(candidates: [a, b], persistenceURL: tempPersistenceURL())
    session.keep()
    let renamed = a.url.deletingLastPathComponent().appendingPathComponent("renamed.pdf")
    session.rename(a.url, to: renamed)

    session.undo()

    #expect(session.current?.url == renamed)  // undo restores the renamed file
    #expect(session.remainingCount == 2)
}

@MainActor
@Test func renamingAnUnknownURLDoesNothing() {
    let a = candidate("a.pdf")
    let session = DClutterSession(candidates: [a], persistenceURL: tempPersistenceURL())
    let stranger = URL(fileURLWithPath: "/tmp/downloads/not-in-queue.pdf")

    session.rename(stranger, to: URL(fileURLWithPath: "/tmp/downloads/x.pdf"))

    #expect(session.totalCount == 1)
    #expect(session.current?.url == a.url)
}

@MainActor
@Test func undoingARenameAsksTheCallerToRenameTheFileBack() {
    // Core cannot touch the filesystem, so undo reports the disk work its
    // caller must do — otherwise the queue and the folder disagree.
    let a = candidate("a.pdf"); let b = candidate("b.pdf")
    let session = DClutterSession(candidates: [a, b], persistenceURL: tempPersistenceURL())
    let renamed = a.url.deletingLastPathComponent().appendingPathComponent("new.pdf")
    session.rename(a.url, to: renamed, recordUndo: true)
    #expect(session.canUndo)

    let effect = session.undo()

    #expect(effect == .renameFile(from: renamed, to: a.url))
    #expect(session.current?.url == a.url)   // queue is back on the old name
}

@MainActor
@Test func redoingARenameAsksTheCallerToRenameForwardAgain() {
    let a = candidate("a.pdf")
    let session = DClutterSession(candidates: [a], persistenceURL: tempPersistenceURL())
    let renamed = a.url.deletingLastPathComponent().appendingPathComponent("new.pdf")
    session.rename(a.url, to: renamed, recordUndo: true)
    _ = session.undo()

    let effect = session.redo()

    #expect(effect == .renameFile(from: a.url, to: renamed))
    #expect(session.current?.url == renamed)
}

@MainActor
@Test func undoingADecisionReportsNoDiskWork() {
    let a = candidate("a.pdf")
    let session = DClutterSession(candidates: [a], persistenceURL: tempPersistenceURL())
    session.keep()
    #expect(session.undo() == nil)
}

// MARK: - Move to destination

@MainActor
@Test func moveMarksTheFileMovedAndLeavesTheQueue() {
    let a = candidate("a.pdf"); let b = candidate("b.pdf")
    let session = DClutterSession(candidates: [a, b], persistenceURL: tempPersistenceURL())
    let destination = URL(fileURLWithPath: "/tmp/Receipts/a.pdf")

    session.move(a.url, to: destination)

    #expect(session.states[a.url] == .moved(to: destination))
    #expect(session.current?.id == b.id)     // advanced past it
    #expect(session.remainingCount == 1)
}

@MainActor
@Test func undoingAMoveAsksTheCallerToMoveTheFileBack() {
    // Core cannot touch the filesystem, so undo reports the disk work.
    // Invariant 4: the undo entry exists before anything is executed.
    let a = candidate("a.pdf")
    let session = DClutterSession(candidates: [a], persistenceURL: tempPersistenceURL())
    let destination = URL(fileURLWithPath: "/tmp/Receipts/a.pdf")
    session.move(a.url, to: destination)

    let effect = session.undo()

    #expect(effect == .moveFile(from: destination, to: a.url))
    #expect(session.states[a.url] == nil)    // back to pending
    #expect(session.current?.id == a.id)
}

@MainActor
@Test func redoingAMoveAsksTheCallerToMoveItForwardAgain() {
    let a = candidate("a.pdf")
    let session = DClutterSession(candidates: [a], persistenceURL: tempPersistenceURL())
    let destination = URL(fileURLWithPath: "/tmp/Receipts/a.pdf")
    session.move(a.url, to: destination)
    _ = session.undo()

    let effect = session.redo()

    #expect(effect == .moveFile(from: a.url, to: destination))
    #expect(session.states[a.url] == .moved(to: destination))
}

@MainActor
@Test func aMovedFileIsNotOfferedForTrashing() {
    let a = candidate("a.pdf")
    let session = DClutterSession(candidates: [a], persistenceURL: tempPersistenceURL())
    session.move(a.url, to: URL(fileURLWithPath: "/tmp/Receipts/a.pdf"))
    #expect(session.stagedForCommit().isEmpty)
}


@MainActor
@Test func amendingAMoveCorrectsWhereUndoWillLookWithoutAddingHistory() {
    // The destination may suffix the name to avoid clobbering, so the path
    // recorded before the move can differ from where the file actually
    // landed. Undo has to follow the real one.
    let a = candidate("a.pdf")
    let session = DClutterSession(candidates: [a], persistenceURL: tempPersistenceURL())
    let intended = URL(fileURLWithPath: "/tmp/Receipts/a.pdf")
    let actual = URL(fileURLWithPath: "/tmp/Receipts/a 2.pdf")

    session.move(a.url, to: intended)
    session.amendLastMove(of: a.url, to: actual)

    #expect(session.states[a.url] == .moved(to: actual))
    session.undo()
    #expect(session.canUndo == false)          // one entry, not two
    #expect(session.current?.id == a.id)
}

// MARK: - Start over reverses this session's moves

@MainActor
@Test func resetReportsTheMovesItNeedsTheCallerToReverse() {
    let a = candidate("a.pdf"); let b = candidate("b.pdf")
    let session = DClutterSession(candidates: [a, b], persistenceURL: tempPersistenceURL())
    let filed = URL(fileURLWithPath: "/tmp/Receipts/a.pdf")
    session.move(a.url, to: filed)
    session.keep()

    let effects = session.reset()

    #expect(effects == [.moveFile(from: filed, to: a.url)])
    #expect(session.states[a.url] == nil)      // back in the queue
    #expect(session.remainingCount == 2)
}

@MainActor
@Test func resetLeavesMovesFromBeforeTheLastCommitAlone() {
    // Committing to the Trash ends a session. Anything filed before that
    // belongs to the closed one and is not this reset's business.
    let a = candidate("a.pdf"); let b = candidate("b.pdf"); let c = candidate("c.pdf")
    let session = DClutterSession(candidates: [a, b, c], persistenceURL: tempPersistenceURL())
    let filed = URL(fileURLWithPath: "/tmp/Receipts/a.pdf")
    session.move(a.url, to: filed)
    session.stage()                    // stages b
    session.commitTrashed([b.url])     // closes the session

    let effects = session.reset()

    #expect(effects.isEmpty)
    #expect(session.states[a.url] == .moved(to: filed))   // stays filed
    #expect(session.states[b.url] == .trashed)            // stays trashed
}

@MainActor
@Test func resetRestoresAMoveTheCallerCouldNotReverse() {
    // If the file cannot come back, the record must go back with it, or
    // the queue shows a card for a file that is not in Downloads.
    let a = candidate("a.pdf")
    let session = DClutterSession(candidates: [a], persistenceURL: tempPersistenceURL())
    let filed = URL(fileURLWithPath: "/tmp/Receipts/a.pdf")
    session.move(a.url, to: filed)
    _ = session.reset()

    session.restoreMove(of: a.url, to: filed)

    #expect(session.states[a.url] == .moved(to: filed))
    #expect(session.remainingCount == 0)
}
