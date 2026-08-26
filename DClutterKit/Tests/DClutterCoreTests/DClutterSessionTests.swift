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
