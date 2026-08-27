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

// MARK: - Move to destination

private func makeScratch() throws -> URL {
    let folder = FileManager.default.temporaryDirectory
        .appendingPathComponent("MoveTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    return folder
}

@Test func moveRelocatesTheFileIntoTheDestination() throws {
    let scratch = try makeScratch()
    defer { try? FileManager.default.removeItem(at: scratch) }
    let source = scratch.appendingPathComponent("source.pdf")
    let target = scratch.appendingPathComponent("Receipts", isDirectory: true)
    try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
    try Data("payload".utf8).write(to: source)

    let moved = try FileActions().move(source, intoFolder: target)

    #expect(moved.deletingLastPathComponent().standardizedFileURL == target.standardizedFileURL)
    #expect(!FileManager.default.fileExists(atPath: source.path))
    #expect(try Data(contentsOf: moved) == Data("payload".utf8))
}

@Test func moveSuffixesRatherThanOverwritingAnExistingFile() throws {
    // Never clobber. A file already sitting in the destination belongs to
    // the user just as much as the one being filed.
    let scratch = try makeScratch()
    defer { try? FileManager.default.removeItem(at: scratch) }
    let source = scratch.appendingPathComponent("notes.txt")
    let target = scratch.appendingPathComponent("Receipts", isDirectory: true)
    try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
    try Data("incoming".utf8).write(to: source)
    let occupied = target.appendingPathComponent("notes.txt")
    try Data("already here".utf8).write(to: occupied)

    let moved = try FileActions().move(source, intoFolder: target)

    #expect(moved.lastPathComponent == "notes 2.txt")
    #expect(try Data(contentsOf: occupied) == Data("already here".utf8))  // untouched
    #expect(try Data(contentsOf: moved) == Data("incoming".utf8))
}

@Test func moveRefusesAMissingDestination() throws {
    let scratch = try makeScratch()
    defer { try? FileManager.default.removeItem(at: scratch) }
    let source = scratch.appendingPathComponent("source.pdf")
    try Data("x".utf8).write(to: source)
    let missing = scratch.appendingPathComponent("NotThere", isDirectory: true)

    #expect(throws: FileActionError.self) {
        _ = try FileActions().move(source, intoFolder: missing)
    }
    #expect(FileManager.default.fileExists(atPath: source.path))  // left where it was
}

@Test func moveBackRestoresTheFileToItsOriginalPath() throws {
    let scratch = try makeScratch()
    defer { try? FileManager.default.removeItem(at: scratch) }
    let source = scratch.appendingPathComponent("source.pdf")
    let target = scratch.appendingPathComponent("Receipts", isDirectory: true)
    try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
    try Data("payload".utf8).write(to: source)

    let actions = FileActions()
    let moved = try actions.move(source, intoFolder: target)
    try actions.moveBack(moved, to: source)

    #expect(FileManager.default.fileExists(atPath: source.path))
    #expect(!FileManager.default.fileExists(atPath: moved.path))
    #expect(try Data(contentsOf: source) == Data("payload".utf8))
}
