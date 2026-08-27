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

@Test func renameMovesTheFileAndReturnsItsNewURL() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("RenameTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let original = folder.appendingPathComponent("before.txt")
    try Data("payload".utf8).write(to: original)

    let actions = FileActions()
    let renamed = try actions.rename(original, to: "after.txt")

    #expect(renamed.lastPathComponent == "after.txt")
    #expect(!FileManager.default.fileExists(atPath: original.path))
    #expect(try Data(contentsOf: renamed) == Data("payload".utf8))  // same file, moved
}

@Test func renameRefusesToOverwriteAnExistingFile() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("RenameTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let original = folder.appendingPathComponent("before.txt")
    let occupied = folder.appendingPathComponent("taken.txt")
    try Data("mine".utf8).write(to: original)
    try Data("someone else's".utf8).write(to: occupied)

    let actions = FileActions()
    #expect(throws: FileActionError.self) {
        _ = try actions.rename(original, to: "taken.txt")
    }
    // The bystander must be untouched — a rename may never clobber.
    #expect(try Data(contentsOf: occupied) == Data("someone else's".utf8))
}

@Test func renameKeepsTheFileInItsOwnFolder() throws {
    // A name containing path separators must not be able to relocate the
    // file out of ~/Downloads.
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("RenameTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let original = folder.appendingPathComponent("before.txt")
    try Data("x".utf8).write(to: original)

    let actions = FileActions()
    let renamed = try actions.rename(original, to: "../escaped.txt")

    #expect(renamed.deletingLastPathComponent().standardizedFileURL == folder.standardizedFileURL)
}

@Test func renameKeepsTheOriginalExtensionWhenTheNewNameOmitsIt() throws {
    // Dropping the extension leaves the bytes intact but makes the file
    // unopenable — macOS can no longer identify it and hands it to a text
    // editor. The user is renaming, not changing the file's type.
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("RenameTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let original = folder.appendingPathComponent("photo.webp")
    try Data("x".utf8).write(to: original)

    let actions = FileActions()
    let renamed = try actions.rename(original, to: "Ammarrah")

    #expect(renamed.lastPathComponent == "Ammarrah.webp")
}

@Test func renameHonoursAnExplicitlyDifferentExtension() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("RenameTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let original = folder.appendingPathComponent("notes.txt")
    try Data("x".utf8).write(to: original)

    let actions = FileActions()
    let renamed = try actions.rename(original, to: "notes.md")

    #expect(renamed.lastPathComponent == "notes.md")
}
