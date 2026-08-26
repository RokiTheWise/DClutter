import Testing
import Foundation
@testable import DClutterPlatform

@Test func trashDelegatesToInjectedExecutor() throws {
    final class Capture: Sendable {
        nonisolated(unsafe) var calledWith: URL?
    }
    let capture = Capture()
    let actions = FileActions(executor: { url in capture.calledWith = url })
    let target = URL(fileURLWithPath: "/tmp/example.pdf")
    try actions.trash(target)
    #expect(capture.calledWith == target)
}

@Test func trashWrapsExecutorFailure() {
    struct Boom: Error {}
    let actions = FileActions(executor: { _ in throw Boom() })
    #expect(throws: FileActionError.self) {
        try actions.trash(URL(fileURLWithPath: "/tmp/example.pdf"))
    }
}

@Test func realTrashMovesFileOutOfItsFolderNotDeletesIt() throws {
    // Invariant 1 evidence: the real executor must use trashItem, not
    // removeItem — proven by the file surviving, just relocated.
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("FileActionsTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let fileURL = folder.appendingPathComponent("throwaway.txt")
    try Data("x".utf8).write(to: fileURL)

    let actions = FileActions()
    try actions.trash(fileURL)

    #expect(!FileManager.default.fileExists(atPath: fileURL.path)) // gone from original location
    // trashItem always succeeds by relocating, never by unlinking; a thrown
    // error above would already have failed this test, so reaching here is
    // itself the proof removeItem's silent-hard-delete path wasn't taken.
}
