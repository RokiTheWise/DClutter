import Testing
import Foundation
@testable import DClutterPlatform

@Test func trashDelegatesToInjectedExecutor() throws {
    final class Capture: Sendable {
        nonisolated(unsafe) var calledWith: URL?
    }
    let capture = Capture()
    let actions = FileActions(executor: { url in capture.calledWith = url; return nil })
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
    // removeItem — proven by the file surviving, just relocated. Asserting
    // only that it's gone from the old path is NOT sufficient: removeItem
    // would pass that same assertion. The file must actually exist at the
    // resulting (Trash) location.
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("FileActionsTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let fileURL = folder.appendingPathComponent("throwaway.txt")
    try Data("x".utf8).write(to: fileURL)

    let actions = FileActions()
    let resultingURL = try actions.trash(fileURL)

    #expect(!FileManager.default.fileExists(atPath: fileURL.path)) // gone from original location
    let resulting = try #require(resultingURL)
    defer { try? FileManager.default.removeItem(at: resulting) }
    #expect(FileManager.default.fileExists(atPath: resulting.path)) // and survives, relocated
    #expect(try Data(contentsOf: resulting) == Data("x".utf8)) // same content, not a different file
}
