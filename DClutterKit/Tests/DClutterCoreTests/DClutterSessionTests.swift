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
@Test func commitTrashedIgnoresURLsThatWerentStaged() {
    let a = candidate("a.pdf")
    let session = DClutterSession(candidates: [a], persistenceURL: tempPersistenceURL())
    session.commitTrashed([a.url]) // a is still .pending — nothing to commit
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
