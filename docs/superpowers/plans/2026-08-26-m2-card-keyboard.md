# M2 — Card + Keyboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A fully usable, keyboard-driven triage app: one file at a time from `~/Downloads`, QuickLook preview, metadata panel, keep/trash/skip/undo, a commit sheet that actually trashes staged files, and a session that survives quitting mid-run.

**Architecture:** `DClutterSession` (new, `DClutterCore`) is the state machine — fixed queue order from `QueueScorer.rank`, a `[URL: FileState]` map, JSON persistence after every decision. `FileActions` (new, `DClutterPlatform`) wraps `FileManager.trashItem` behind an injectable executor. A new `DClutterUI` SwiftPM target holds the SwiftUI layer — `CardView`, `PreviewPane` (`QLThumbnailGenerator` at rest, live `QLPreviewView` on focus), `MetadataPanel`, chips, `CommitSheet`, and a `SessionViewModel` that is the *only* thing that imports both `DClutterCore` and `DClutterPlatform` — Core never calls Platform directly, preserving the boundary from §3. The Xcode app target links the new product and hosts a thin `TriageView` root.

**Tech Stack:** Swift 6 strict concurrency, SwiftUI, Swift Testing (`import Testing`), `QuickLook`/`QuickLookThumbnailing` frameworks in `DClutterUI` only.

**Spec:** `plandocs/dclutter-plan.md` (functional — §3 architecture, §4 scoring, §6 interaction spec, non-negotiable invariants), `dclutter-design.md` (visual spec for `DClutterUI`).

## Global Constraints

- `DClutterCore` imports only Foundation + UniformTypeIdentifiers — no Observation, no AppKit, no QuickLook. `DClutterSession` is a plain `@MainActor final class`, not `@Observable`.
- Never `FileManager.removeItem` on a user file — `FileActions.trash` uses `trashItem(at:resultingItemURL:)` only.
- No file operation touches anything outside `~/Downloads` — M2 has no destination bins yet (M4), so this is automatically satisfied: the only Platform action is trash.
- `.staged` files are never touched on disk until the user confirms the commit sheet — `stage()` only mutates in-memory/persisted *state*; `FileActions.trash` is called exclusively from `SessionViewModel.confirmCommit()`, after commit-sheet confirmation.
- Session state persists after every single decision (`keep`/`stage`/`skip`/`undo`), not on quit.
- Move-to-destination, `NSUndoManager`, trackpad gestures, and the destination shelf are explicitly out of scope — M4.
- Unit tests target `DClutterCore` and `DClutterPlatform` only, using real temp files/dirs — no mocking harness. `DClutterUI` is verified by running the app.

---

### Task 1: QueueContext — duplicate cluster size

**Files:**
- Modify: `DClutterKit/Sources/DClutterCore/QueueContext.swift`
- Test: `DClutterKit/Tests/DClutterCoreTests/QueueContextTests.swift`

**Interfaces:**
- Produces: `QueueContext.duplicateCount(for: FileCandidate) -> Int` — cluster size including the keeper; `1` if the candidate isn't part of any duplicate cluster. Needed by the `⟨N copies⟩` chip (`dclutter-design.md` §5).

- [ ] **Step 1: Write the failing test**

```swift
@Test func duplicateCountReflectsFullClusterSize() {
    let a = candidate("Report.pdf", bytes: 10_000)
    let b = candidate("Report (2).pdf", bytes: 10_000)
    let c = candidate("Report (3).pdf", bytes: 10_000)
    let ctx = QueueContext(candidates: [a, b, c])
    #expect(ctx.duplicateCount(for: a) == 3)
    #expect(ctx.duplicateCount(for: b) == 3)
    #expect(ctx.duplicateCount(for: c) == 3)
}

@Test func duplicateCountIsOneForNonClusteredFile() {
    let a = candidate("Report.pdf", bytes: 10_000)
    let ctx = QueueContext(candidates: [a])
    #expect(ctx.duplicateCount(for: a) == 1)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd DClutterKit && swift test --filter duplicateCount`
Expected: FAIL — "value of type 'QueueContext' has no member 'duplicateCount'"

- [ ] **Step 3: Add cluster-size tracking to `QueueContext`**

In `findRedundantCopies`, alongside `redundant: Set<UUID>`, build `clusterSize: [UUID: Int]` (every member of a cluster with `count > 1` maps to `members.count`) and return both. Store the second as a new private property, expose it:

```swift
public func duplicateCount(for candidate: FileCandidate) -> Int {
    clusterSizeByID[candidate.id] ?? 1
}
```

(`findRedundantCopies` becomes `findDuplicateInfo(in:) -> (redundant: Set<UUID>, clusterSize: [UUID: Int])`, called once from `init`.)

- [ ] **Step 4: Run test to verify it passes**

Run: `cd DClutterKit && swift test --filter duplicateCount`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add DClutterKit/Sources/DClutterCore/QueueContext.swift DClutterKit/Tests/DClutterCoreTests/QueueContextTests.swift
git commit -m "Add QueueContext.duplicateCount for the copies chip"
```

---

### Task 2: FileState

**Files:**
- Create: `DClutterKit/Sources/DClutterCore/FileState.swift`
- Test: `DClutterKit/Tests/DClutterCoreTests/FileStateTests.swift`

**Interfaces:**
- Produces: `public enum FileState: Codable, Equatable, Sendable { case pending, kept, staged, trashed, moved(to: URL) }` — used by Task 3+.

- [ ] **Step 1: Write the failing test**

```swift
import Testing
import Foundation
@testable import DClutterCore

@Test func fileStateRoundTripsThroughJSON() throws {
    let states: [FileState] = [.pending, .kept, .staged, .trashed, .moved(to: URL(fileURLWithPath: "/tmp/x"))]
    let data = try JSONEncoder().encode(states)
    let decoded = try JSONDecoder().decode([FileState].self, from: data)
    #expect(decoded == states)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd DClutterKit && swift test --filter fileStateRoundTrips`
Expected: FAIL — "cannot find 'FileState' in scope"

- [ ] **Step 3: Write the enum**

```swift
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd DClutterKit && swift test --filter fileStateRoundTrips`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add DClutterKit/Sources/DClutterCore/FileState.swift DClutterKit/Tests/DClutterCoreTests/FileStateTests.swift
git commit -m "Add FileState enum"
```

---

### Task 3: DClutterSession — queue, current, counts (no decisions yet)

**Files:**
- Create: `DClutterKit/Sources/DClutterCore/DClutterSession.swift`
- Test: `DClutterKit/Tests/DClutterCoreTests/DClutterSessionTests.swift`

**Interfaces:**
- Consumes: `FileCandidate` (existing), `FileState` (Task 2).
- Produces: `@MainActor public final class DClutterSession { public let queue: [FileCandidate]; public init(candidates: [FileCandidate], persistenceURL: URL); public var current: FileCandidate? { get }; public var remainingCount: Int { get }; public var totalCount: Int { get } }` — `keep`/`stage`/`skip`/`undo` land in Task 4.

- [ ] **Step 1: Write the failing test**

```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd DClutterKit && swift test --filter DClutterSession`
Expected: FAIL — "cannot find 'DClutterSession' in scope"

- [ ] **Step 3: Write the minimal class**

```swift
//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import Foundation

/// The §3 state machine. `queue` order is fixed at init (the caller passes
/// an already-ranked list from QueueScorer.rank) — skip reorders logically
/// via `deferred`, never mutates `queue` itself, which keeps persistence
/// and reconciliation on relaunch simple.
@MainActor
public final class DClutterSession {
    public let queue: [FileCandidate]
    public private(set) var states: [URL: FileState] = [:]
    private var deferred: Set<URL> = []
    let persistenceURL: URL

    public init(candidates: [FileCandidate], persistenceURL: URL) {
        self.queue = candidates
        self.persistenceURL = persistenceURL
    }

    private var effectiveOrder: [FileCandidate] {
        queue.filter { !deferred.contains($0.url) } + queue.filter { deferred.contains($0.url) }
    }

    public var current: FileCandidate? {
        effectiveOrder.first { (states[$0.url] ?? .pending) == .pending }
    }

    public var remainingCount: Int {
        queue.filter { (states[$0.url] ?? .pending) == .pending }.count
    }

    public var totalCount: Int { queue.count }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd DClutterKit && swift test --filter DClutterSession`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add DClutterKit/Sources/DClutterCore/DClutterSession.swift DClutterKit/Tests/DClutterCoreTests/DClutterSessionTests.swift
git commit -m "Add DClutterSession queue/current/counts"
```

---

### Task 4: DClutterSession — keep/stage/skip/undo

**Files:**
- Modify: `DClutterKit/Sources/DClutterCore/DClutterSession.swift`
- Test: `DClutterKit/Tests/DClutterCoreTests/DClutterSessionTests.swift`

**Interfaces:**
- Produces: `public func keep()`, `public func stage()`, `public func skip()`, `public func undo()`, `public var canUndo: Bool { get }`, `public func stagedForCommit() -> [FileCandidate]`, `public func commitTrashed(_ urls: Set<URL>)`.

- [ ] **Step 1: Write the failing tests**

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd DClutterKit && swift test --filter DClutterSession`
Expected: FAIL — "value of type 'DClutterSession' has no member 'keep'" (etc.)

- [ ] **Step 3: Implement decisions and undo**

```swift
private enum Decision {
    case keep(URL)
    case stage(URL)
    case skip(URL)
}

extension DClutterSession {
    public var canUndo: Bool { !history.isEmpty }

    public func keep() {
        guard let url = current?.url else { return }
        states[url] = .kept
        history.append(.keep(url))
    }

    public func stage() {
        guard let url = current?.url else { return }
        states[url] = .staged
        history.append(.stage(url))
    }

    public func skip() {
        guard let url = current?.url else { return }
        deferred.insert(url)
        history.append(.skip(url))
    }

    public func undo() {
        guard let last = history.popLast() else { return }
        switch last {
        case .keep(let url), .stage(let url):
            states.removeValue(forKey: url)
        case .skip(let url):
            deferred.remove(url)
        }
    }

    public func stagedForCommit() -> [FileCandidate] {
        queue.filter { states[$0.url] == .staged }
    }

    /// Called once trashing succeeds for the given URLs. Transitions them
    /// from .staged to the terminal .trashed state and clears undo history
    /// entirely — a committed file cannot be un-trashed via ⌘Z (that would
    /// need M4's real file-recovery logic), and history may reference
    /// decisions from before the commit boundary that no longer make sense
    /// to reverse in isolation.
    public func commitTrashed(_ urls: Set<URL>) {
        for url in urls where states[url] == .staged {
            states[url] = .trashed
        }
        history.removeAll()
    }
}
```

Add `private var history: [Decision] = []` as a stored property on the class itself (extensions can't add stored properties).

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd DClutterKit && swift test --filter DClutterSession`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add DClutterKit/Sources/DClutterCore/DClutterSession.swift DClutterKit/Tests/DClutterCoreTests/DClutterSessionTests.swift
git commit -m "Add DClutterSession keep/stage/skip/undo"
```

---

### Task 5: DClutterSession — JSON persistence

**Files:**
- Modify: `DClutterKit/Sources/DClutterCore/DClutterSession.swift`
- Test: `DClutterKit/Tests/DClutterCoreTests/DClutterSessionTests.swift`

**Interfaces:**
- Produces: persistence is automatic (invariant 5) — every mutating call (`keep`/`stage`/`skip`/`undo`/`commitTrashed`) writes `persistenceURL`; `init` loads and reconciles if the file exists.

- [ ] **Step 1: Write the failing tests**

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd DClutterKit && swift test --filter DClutterSession`
Expected: FAIL — file is never written; `SessionSnapshot` doesn't exist.

- [ ] **Step 3: Implement `SessionSnapshot` and wire persistence into every mutator**

```swift
struct SessionSnapshot: Codable {
    let queueOrder: [String]      // url.absoluteString, in effective order at save time
    let states: [String: FileState]
    let deferred: [String]
}

extension DClutterSession {
    private func persist() {
        let snapshot = SessionSnapshot(
            queueOrder: queue.map(\.url.absoluteString),
            states: states.reduce(into: [:]) { $0[$1.key.absoluteString] = $1.value },
            deferred: deferred.map(\.absoluteString)
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: persistenceURL, options: .atomic)
    }

    static func loadSnapshot(from url: URL) -> SessionSnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(SessionSnapshot.self, from: data)
    }
}
```

Update `init` to reconcile:

```swift
public init(candidates: [FileCandidate], persistenceURL: URL) {
    self.queue = candidates
    self.persistenceURL = persistenceURL
    if let snapshot = Self.loadSnapshot(from: persistenceURL) {
        let known = Set(candidates.map(\.url.absoluteString))
        self.states = snapshot.states.reduce(into: [:]) { result, entry in
            guard known.contains(entry.key), let url = URL(string: entry.key) else { return }
            result[url] = entry.value
        }
        self.deferred = Set(snapshot.deferred.compactMap { known.contains($0) ? URL(string: $0) : nil })
    }
}
```

Call `persist()` at the end of `keep()`, `stage()`, `skip()`, `undo()`, and `commitTrashed()` (Task 4's bodies each get one added line).

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd DClutterKit && swift test --filter DClutterSession`
Expected: PASS

- [ ] **Step 5: Run the full Core suite to confirm no regressions, then commit**

Run: `cd DClutterKit && swift test`
Expected: all tests pass.

```bash
git add DClutterKit/Sources/DClutterCore/DClutterSession.swift DClutterKit/Tests/DClutterCoreTests/DClutterSessionTests.swift
git commit -m "Add DClutterSession JSON persistence and relaunch reconciliation"
```

---

### Task 6: FileActions (trash) in DClutterPlatform

**Files:**
- Create: `DClutterKit/Sources/DClutterPlatform/FileActions.swift`
- Create: `DClutterKit/Tests/DClutterPlatformTests/FileActionsTests.swift`
- Modify: `DClutterKit/Package.swift` (add `DClutterPlatformTests` target)

**Interfaces:**
- Produces: `public struct FileActions: Sendable { public init(); public func trash(_ url: URL) throws }`, `public enum FileActionError: Error { case trashFailed(URL, underlying: Error) }`.

- [ ] **Step 1: Add the test target to Package.swift**

```swift
.testTarget(name: "DClutterPlatformTests", dependencies: ["DClutterPlatform"]),
```

(Insert after the `DClutterPlatform` target definition, alongside the existing `DClutterCoreTests` entry.)

- [ ] **Step 2: Write the failing tests**

```swift
import Testing
import Foundation
@testable import DClutterPlatform

@Test func trashDelegatesToInjectedExecutor() throws {
    var calledWith: URL?
    let actions = FileActions(executor: { url in calledWith = url })
    let target = URL(fileURLWithPath: "/tmp/example.pdf")
    try actions.trash(target)
    #expect(calledWith == target)
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
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `cd DClutterKit && swift test --filter FileActions`
Expected: FAIL — "cannot find 'FileActions' in scope"

- [ ] **Step 4: Implement `FileActions`**

```swift
//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import Foundation

public enum FileActionError: Error {
    case trashFailed(URL, underlying: Error)
}

/// The only place in DClutter that may touch a user file destructively —
/// and even here, only via `trashItem`. Never `removeItem`.
public struct FileActions: Sendable {
    private let executor: @Sendable (URL) throws -> Void

    public init() {
        self.init(executor: Self.systemTrash)
    }

    init(executor: @escaping @Sendable (URL) throws -> Void) {
        self.executor = executor
    }

    public func trash(_ url: URL) throws {
        do {
            try executor(url)
        } catch {
            throw FileActionError.trashFailed(url, underlying: error)
        }
    }

    private static func systemTrash(_ url: URL) throws {
        var resultingURL: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &resultingURL)
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd DClutterKit && swift test --filter FileActions`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add DClutterKit/Package.swift DClutterKit/Sources/DClutterPlatform/FileActions.swift DClutterKit/Tests/DClutterPlatformTests/FileActionsTests.swift
git commit -m "Add FileActions.trash with injectable executor"
```

---

### Task 7: DClutterUI SwiftPM target + design tokens

**Files:**
- Modify: `DClutterKit/Package.swift` (add `DClutterUI` target/product)
- Create: `DClutterKit/Sources/DClutterUI/DesignTokens.swift`

**Interfaces:**
- Produces: `enum DesignTokens { enum ColorToken; enum Radius; enum Spacing; enum FontToken }` per `dclutter-design.md` §1–4. Internal (not `public`) — only `DClutterUI`'s own views use these.

- [ ] **Step 1: Add the target and product**

```swift
.library(name: "DClutterUI", targets: ["DClutterUI"]),
```
(alongside the existing two library products)

```swift
.target(name: "DClutterUI", dependencies: ["DClutterCore", "DClutterPlatform"]),
```
(after the `DClutterPlatform` target, before the test targets)

- [ ] **Step 2: Write `DesignTokens.swift`**

```swift
//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import SwiftUI

/// Visual spec: dclutter-design.md. Semantic system colors only — no fixed
/// hex values, so light/dark/increased-contrast all adapt for free.
enum DesignTokens {
    enum ColorToken {
        static let surface = Color(nsColor: .windowBackgroundColor)
        static let cardSurface = Color(nsColor: .controlBackgroundColor)
        static let hairline = Color(nsColor: .separatorColor)
        static let textPrimary = Color(nsColor: .labelColor)
        static let textSecondary = Color(nsColor: .secondaryLabelColor)
        static let textTertiary = Color(nsColor: .tertiaryLabelColor)

        /// Warm amber-red — reads as "consequential," not alarm-red.
        /// Trash-only; never used for chips or informational UI.
        static let consequence = Color(
            light: Color(red: 0.79, green: 0.31, blue: 0.16),
            dark: Color(red: 0.93, green: 0.48, blue: 0.31)
        )
    }

    enum Radius {
        static let chip: CGFloat = 6
        static let preview: CGFloat = 10
        static let card: CGFloat = 20
        static let bin: CGFloat = 14
        static let sheet: CGFloat = 12
    }

    enum Spacing {
        static let unit: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xLarge: CGFloat = 24
        static let xxLarge: CGFloat = 32
        static let cardMargin: CGFloat = 48
    }
}

private extension Color {
    init(light: Color, dark: Color) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(dark) : NSColor(light)
        })
    }
}
```

- [ ] **Step 3: Verify the package builds**

Run: `cd DClutterKit && swift build`
Expected: builds clean (no tests yet — `DesignTokens` has no logic worth unit testing; it's verified visually in later tasks).

- [ ] **Step 4: Commit**

```bash
git add DClutterKit/Package.swift DClutterKit/Sources/DClutterUI/DesignTokens.swift
git commit -m "Add DClutterUI target and design tokens"
```

---

### Task 8: Wire DClutterUI into the Xcode app target

**Files:**
- Modify: `DClutter.xcodeproj/project.pbxproj` (via Xcode's UI, not a text edit)

**Interfaces:**
- Produces: the `DClutter` app target links the `DClutterUI` product, so `import DClutterUI` becomes available in `DClutter/ContentView.swift` and later files.

`project.pbxproj` is a generated file with an internal ID scheme (`XCSwiftPackageProductDependency`, `PBXBuildFile` cross-references, build-phase membership lists). Hand-editing it to splice in a third product — even carefully, mirroring the existing `DClutterCore`/`DClutterPlatform` entries — risks a subtly malformed project that only surfaces as a confusing Xcode error later. Xcode's own UI makes this exact change in about ten seconds and cannot produce an invalid file, so this step is manual rather than scripted.

- [ ] **Step 1: Ask the user to link the product in Xcode**

Hand off with these instructions: open `DClutter.xcodeproj`, select the `DClutter` target, go to *General → Frameworks, Libraries, and Embedded Content* (or *Build Phases → Link Binary With Libraries*), click **+**, and choose **DClutterUI** from the already-linked `DClutterKit` local package. Save.

- [ ] **Step 2: Wait for confirmation, then verify from the command line**

Once the user confirms the product is linked:

Run: `plutil -lint "DClutter.xcodeproj/project.pbxproj"`
Expected: `OK`

Run: `xcodebuild -project DClutter.xcodeproj -scheme DClutter -destination 'platform=macOS' build 2>&1 | tail -30`
Expected: `BUILD SUCCEEDED` (nothing imports `DClutterUI` yet, so this just proves the link is valid).

- [ ] **Step 3: Commit**

```bash
git add DClutter.xcodeproj/project.pbxproj
git commit -m "Link DClutterUI product into the DClutter app target"
```

---

### Task 9: Chip view + chip builder

**Files:**
- Create: `DClutterKit/Sources/DClutterUI/Chip.swift`

**Interfaces:**
- Consumes: `FileCandidate`, `QueueContext` (existing Core types).
- Produces: `struct Chip: View { let text: String }`, `enum ChipBuilder { static func chips(for: FileCandidate, in: QueueContext) -> [String] }`.

- [ ] **Step 1: Write `Chip.swift`**

```swift
//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import SwiftUI
import DClutterCore

/// dclutter-design.md §5 — grey, no icons, no accent color. Information,
/// not warnings.
struct Chip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .kerning(0.1)
            .padding(.horizontal, DesignTokens.Spacing.small)
            .padding(.vertical, 3)
            .background(DesignTokens.ColorToken.textPrimary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.chip))
            .foregroundStyle(DesignTokens.ColorToken.textSecondary)
    }
}

enum ChipBuilder {
    /// Capped at 3, per the design spec — wrapping to a second row is a
    /// layout concern for the caller, not this builder.
    static func chips(for candidate: FileCandidate, in context: QueueContext) -> [String] {
        var result: [String] = []
        let dupCount = context.duplicateCount(for: candidate)
        if dupCount > 1 { result.append("\(dupCount) copies") }
        if candidate.lastOpened == nil && candidate.sourceURL != nil {
            result.append("never opened")
        }
        if context.isExtractedArchive(candidate) { result.append("already extracted") }
        return Array(result.prefix(3))
    }
}
```

- [ ] **Step 2: Verify the package builds**

Run: `cd DClutterKit && swift build`
Expected: builds clean.

- [ ] **Step 3: Commit**

```bash
git add DClutterKit/Sources/DClutterUI/Chip.swift
git commit -m "Add Chip view and ChipBuilder"
```

---

### Task 10: MetadataPanel

**Files:**
- Create: `DClutterKit/Sources/DClutterUI/MetadataPanel.swift`

**Interfaces:**
- Consumes: `FileCandidate`.
- Produces: `struct MetadataPanel: View { let candidate: FileCandidate }`.

- [ ] **Step 1: Write `MetadataPanel.swift`**

```swift
//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import SwiftUI
import DClutterCore

/// dclutter-design.md §1 — the "instrumentation" voice: uppercase SF Mono
/// labels in tertiary grey, SF Pro Text values in primary. Monospaced
/// labels also align on a column for free, no Grid needed.
struct MetadataPanel: View {
    let candidate: FileCandidate

    private var rows: [(String, String)] {
        var result = [("SIZE", Self.byteFormatter.string(fromByteCount: candidate.bytes))]
        result.append(("LAST OPENED", candidate.lastOpened.map(Self.dateFormatter.string) ?? "Never"))
        if let host = candidate.sourceURL?.host {
            result.append(("FROM", host))
        }
        result.append(("ADDED", Self.dateFormatter.string(from: candidate.created)))
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.unit * 2) {
            ForEach(rows, id: \.0) { label, value in
                HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.small) {
                    Text(label)
                        .font(.system(size: 11, design: .monospaced))
                        .kerning(0.5)
                        .foregroundStyle(DesignTokens.ColorToken.textTertiary)
                        .frame(width: 90, alignment: .leading)
                    Text(value)
                        .font(.system(size: 13))
                        .foregroundStyle(DesignTokens.ColorToken.textPrimary)
                }
            }
        }
    }

    private static let byteFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM yyyy"
        return f
    }()
}
```

- [ ] **Step 2: Verify the package builds**

Run: `cd DClutterKit && swift build`
Expected: builds clean.

- [ ] **Step 3: Commit**

```bash
git add DClutterKit/Sources/DClutterUI/MetadataPanel.swift
git commit -m "Add MetadataPanel"
```

---

### Task 11: PreviewPane (thumbnail + focus-toggled live preview)

**Files:**
- Create: `DClutterKit/Sources/DClutterUI/PreviewPane.swift`

**Interfaces:**
- Consumes: `FileCandidate`.
- Produces: `struct PreviewPane: View { let candidate: FileCandidate; @Binding var focused: Bool }`.

- [ ] **Step 1: Write `PreviewPane.swift`**

```swift
//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import SwiftUI
import Quartz
import QuickLookThumbnailing
import DClutterCore

/// §6: a static QLThumbnailGenerator thumbnail at rest; only on focus does
/// this become a live QLPreviewView. Keeps the scroll/swipe conflict
/// impossible by default and renders faster for the common (unfocused) case.
struct PreviewPane: View {
    let candidate: FileCandidate
    @Binding var focused: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.preview)
                .fill(DesignTokens.ColorToken.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.preview)
                        .strokeBorder(DesignTokens.ColorToken.hairline)
                )
            if focused {
                LivePreview(url: candidate.url)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.preview))
            } else {
                ThumbnailPreview(url: candidate.url)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.preview))
            }
        }
        .aspectRatio(4.0 / 3.0, contentMode: .fit)
    }
}

private struct ThumbnailPreview: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> NSImageView {
        let view = NSImageView()
        view.imageScaling = .scaleProportionallyUpOrDown
        loadThumbnail(into: view)
        return view
    }

    func updateNSView(_ view: NSImageView, context: Context) {
        loadThumbnail(into: view)
    }

    private func loadThumbnail(into view: NSImageView) {
        let size = CGSize(width: 400, height: 300)
        let request = QLThumbnailGenerator.Request(
            fileAt: url, size: size, scale: 2, representationTypes: .thumbnail
        )
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { thumbnail, _ in
            guard let thumbnail else { return }
            DispatchQueue.main.async { view.image = thumbnail.nsImage }
        }
    }
}

private struct LivePreview: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> QLPreviewView {
        let view = QLPreviewView(frame: .zero, style: .normal)
        view.previewItem = url as QLPreviewItem
        return view
    }

    func updateNSView(_ view: QLPreviewView, context: Context) {
        if (view.previewItem as? URL) != url {
            view.previewItem = url as QLPreviewItem
        }
    }
}
```

- [ ] **Step 2: Verify the package builds**

Run: `cd DClutterKit && swift build`
Expected: builds clean.

- [ ] **Step 3: Commit**

```bash
git add DClutterKit/Sources/DClutterUI/PreviewPane.swift
git commit -m "Add PreviewPane with thumbnail/live-preview toggle"
```

---

### Task 12: CardView

**Files:**
- Create: `DClutterKit/Sources/DClutterUI/CardView.swift`

**Interfaces:**
- Consumes: `FileCandidate`, `QueueContext`, `Chip`/`ChipBuilder` (Task 9), `MetadataPanel` (Task 10), `PreviewPane` (Task 11).
- Produces: `struct CardView: View { let candidate: FileCandidate; let context: QueueContext; @Binding var previewFocused: Bool }`.

- [ ] **Step 1: Write `CardView.swift`**

```swift
//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import SwiftUI
import DClutterCore

/// dclutter-design.md §3–4: flat, 20pt-radius card — "the signature move."
/// No drop shadow; depth comes from surface alternation and the hairline.
struct CardView: View {
    let candidate: FileCandidate
    let context: QueueContext
    @Binding var previewFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.large) {
            PreviewPane(candidate: candidate, focused: $previewFocused)

            Text(candidate.url.lastPathComponent)
                .font(.system(size: 22, weight: .regular))
                .kerning(-0.4)
                .foregroundStyle(DesignTokens.ColorToken.textPrimary)
                .lineLimit(2)

            let chips = ChipBuilder.chips(for: candidate, in: context)
            if !chips.isEmpty {
                HStack(spacing: DesignTokens.Spacing.small) {
                    ForEach(chips, id: \.self) { Chip(text: $0) }
                }
            }

            MetadataPanel(candidate: candidate)
        }
        .padding(DesignTokens.Spacing.xLarge)
        .background(DesignTokens.ColorToken.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.card)
                .strokeBorder(DesignTokens.ColorToken.hairline)
        )
        .frame(maxWidth: 480)
        .id(candidate.id) // forces a fresh identity so .transition fires on advance
        .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .opacity
        ))
    }
}
```

- [ ] **Step 2: Verify the package builds**

Run: `cd DClutterKit && swift build`
Expected: builds clean.

- [ ] **Step 3: Commit**

```bash
git add DClutterKit/Sources/DClutterUI/CardView.swift
git commit -m "Add CardView"
```

---

### Task 13: SessionViewModel

**Files:**
- Create: `DClutterKit/Sources/DClutterUI/SessionViewModel.swift`

**Interfaces:**
- Consumes: `DClutterSession` (Core, Task 3–5), `FileActions` (Platform, Task 6).
- Produces: `@MainActor @Observable final class SessionViewModel` — the only type in the app that imports both `DClutterCore` and `DClutterPlatform`.

**Why the `version` counter below is load-bearing, not decoration:** `@Observable` only instruments access to *this class's own* stored properties — it rewrites their getters to register with the observation registrar. `current`, `remainingCount`, and `canUndo` are computed properties that read from `session`, a plain (non-`@Observable`) `DClutterSession`. Reading them touches zero stored properties of `SessionViewModel` itself, so no dependency is ever recorded, and SwiftUI never re-renders after `keep()`/`stage()`/etc. mutate `session` underneath it — every keystroke would change state and nothing on screen. `version` is a stored property every mutator bumps and every computed property reads (even via a throwaway `_ = version`), giving the observation system something of `SessionViewModel`'s own to actually track.

- [ ] **Step 1: Write `SessionViewModel.swift`**

```swift
//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import Observation
import DClutterCore
import DClutterPlatform

/// The one place Core and Platform meet. DClutterSession never calls
/// FileActions itself — this view model does, and only from
/// `confirmCommit()`, which is only ever invoked after the commit sheet's
/// explicit confirmation (invariant 3).
@MainActor
@Observable
final class SessionViewModel {
    private let session: DClutterSession
    private let fileActions: FileActions

    /// Bumped by every mutator, read by every computed property below.
    /// See the task note above — without this, SwiftUI never re-renders.
    private var version = 0

    var previewFocused = false
    var showCommitSheet = false
    var commitError: String?

    init(session: DClutterSession, fileActions: FileActions = FileActions()) {
        self.session = session
        self.fileActions = fileActions
    }

    var current: FileCandidate? { _ = version; return session.current }
    var remainingCount: Int { _ = version; return session.remainingCount }
    var totalCount: Int { _ = version; return session.totalCount }
    var canUndo: Bool { _ = version; return session.canUndo }
    var stagedForCommit: [FileCandidate] { _ = version; return session.stagedForCommit() }

    func keep() { previewFocused = false; session.keep(); version += 1 }
    func stage() { previewFocused = false; session.stage(); version += 1 }
    func skip() { previewFocused = false; session.skip(); version += 1 }
    func undo() { session.undo(); version += 1 }
    func toggleFocus() { previewFocused.toggle() }

    /// Trashes every staged file, transitions the successful ones to
    /// .trashed (never .pending again — see FileState/commitTrashed), and
    /// keeps the sheet open on any failure so the error is actually visible
    /// instead of being dismissed along with it.
    func confirmCommit() {
        var trashed: Set<URL> = []
        var anyFailed = false
        for candidate in session.stagedForCommit() {
            do {
                try fileActions.trash(candidate.url)
                trashed.insert(candidate.url)
            } catch {
                anyFailed = true
                commitError = "Couldn't trash \(candidate.url.lastPathComponent): \(error.localizedDescription)"
            }
        }
        session.commitTrashed(trashed)
        version += 1
        if !anyFailed {
            commitError = nil
            showCommitSheet = false
        }
    }
}
```

- [ ] **Step 2: Verify the package builds**

Run: `cd DClutterKit && swift build`
Expected: builds clean.

- [ ] **Step 3: Commit**

```bash
git add DClutterKit/Sources/DClutterUI/SessionViewModel.swift
git commit -m "Add SessionViewModel bridging DClutterSession and FileActions"
```

---

### Task 14: CommitSheet

**Files:**
- Create: `DClutterKit/Sources/DClutterUI/CommitSheet.swift`

**Interfaces:**
- Consumes: `SessionViewModel` (Task 13).
- Produces: `struct CommitSheet: View { let viewModel: SessionViewModel }`.

- [ ] **Step 1: Write `CommitSheet.swift`**

```swift
//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import SwiftUI

/// §2 principle 4: lists every staged file, requires explicit confirm,
/// reports a count — never bytes reclaimed (§0).
struct CommitSheet: View {
    @Bindable var viewModel: SessionViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.large) {
            Text("Trash \(viewModel.stagedForCommit.count) files?")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(DesignTokens.ColorToken.textPrimary)

            List(viewModel.stagedForCommit) { candidate in
                Text(candidate.url.lastPathComponent)
                    .font(.system(size: 13))
            }
            .frame(minHeight: 200)

            if let error = viewModel.commitError {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(DesignTokens.ColorToken.consequence)
            }

            HStack {
                Spacer()
                Button("Cancel") { viewModel.showCommitSheet = false }
                    .keyboardShortcut(.cancelAction)
                Button("Trash \(viewModel.stagedForCommit.count) Files") {
                    viewModel.confirmCommit()
                }
                .keyboardShortcut(.defaultAction)
                .tint(DesignTokens.ColorToken.consequence)
            }
        }
        .padding(DesignTokens.Spacing.xLarge)
        .background(DesignTokens.ColorToken.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sheet))
        .frame(width: 420)
    }
}
```

- [ ] **Step 2: Verify the package builds**

Run: `cd DClutterKit && swift build`
Expected: builds clean.

- [ ] **Step 3: Commit**

```bash
git add DClutterKit/Sources/DClutterUI/CommitSheet.swift
git commit -m "Add CommitSheet"
```

---

### Task 15: TriageView (root view + keyboard bindings) and app wiring

**Files:**
- Create: `DClutterKit/Sources/DClutterUI/TriageView.swift`
- Modify: `DClutter/ContentView.swift`

**Interfaces:**
- Consumes: `SessionViewModel` (Task 13), `CardView` (Task 12), `CommitSheet` (Task 14), `DirectoryMetadataProvider`/`QueueScorer`/`QueueContext` (Core, existing), `DClutterSession` (Core).
- Produces: `public struct TriageView: View { public init(folder: URL) }` — the one entry point `ContentView` needs.

- [ ] **Step 1: Write `TriageView.swift`**

```swift
//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import SwiftUI
import DClutterCore

/// §6 keyboard table (M2 subset — 1-3/move and gestures are M4):
/// →/K keep, ←/X stage, ⌘Z undo, Space skip, ⌘⏎ commit sheet,
/// ↑ focus preview, Esc unfocus.
public struct TriageView: View {
    @State private var viewModel: SessionViewModel?
    @State private var context: QueueContext?
    let folder: URL

    public init(folder: URL) {
        self.folder = folder
    }

    public var body: some View {
        Group {
            if let viewModel, let context {
                content(viewModel: viewModel, context: context)
            } else {
                ProgressView().task { await loadSession() }
            }
        }
    }

    @ViewBuilder
    private func content(viewModel: SessionViewModel, context: QueueContext) -> some View {
        VStack(spacing: DesignTokens.Spacing.xLarge) {
            Spacer()
            if let current = viewModel.current {
                CardView(candidate: current, context: context, previewFocused: Binding(
                    get: { viewModel.previewFocused },
                    set: { viewModel.previewFocused = $0 }
                ))
            } else {
                Text("All done.")
                    .foregroundStyle(DesignTokens.ColorToken.textSecondary)
            }
            Spacer()
            HStack {
                Text("\(viewModel.totalCount - viewModel.remainingCount) of \(viewModel.totalCount)")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(DesignTokens.ColorToken.textTertiary)
                Spacer()
                Text("⌘⏎ commit")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(DesignTokens.ColorToken.textTertiary)
            }
        }
        .padding(DesignTokens.Spacing.cardMargin)
        .background(DesignTokens.ColorToken.surface)
        .focusable()
        .focusEffectDisabled()
        .onKeyPress { press in handle(press, viewModel: viewModel) }
        .sheet(isPresented: Bindable(viewModel).showCommitSheet) {
            CommitSheet(viewModel: viewModel)
        }
    }

    private func handle(_ press: KeyPress, viewModel: SessionViewModel) -> KeyPress.Result {
        if press.modifiers.contains(.command) {
            switch press.key {
            case "z": viewModel.undo(); return .handled
            case .return: viewModel.showCommitSheet = true; return .handled
            default: return .ignored
            }
        }
        switch press.key {
        case .rightArrow, "k": viewModel.keep(); return .handled
        case .leftArrow, "x": viewModel.stage(); return .handled
        case .upArrow: viewModel.previewFocused = true; return .handled
        case .escape: viewModel.previewFocused = false; return .handled
        case .space: viewModel.skip(); return .handled
        default: return .ignored
        }
    }

    private func loadSession() async {
        let provider = DirectoryMetadataProvider()
        guard let candidates = try? await provider.candidates(in: folder) else { return }
        let ranked = QueueScorer.rank(candidates).map(\.candidate)
        let supportDir = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        ).appendingPathComponent("DClutter", isDirectory: true)
        if let supportDir {
            try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
        }
        let persistenceURL = (supportDir ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("session.json")
        let session = DClutterSession(candidates: ranked, persistenceURL: persistenceURL)
        self.context = QueueContext(candidates: ranked)
        self.viewModel = SessionViewModel(session: session)
    }
}
```

- [ ] **Step 2: Wire it into the app**

Replace `DClutter/ContentView.swift`:

```swift
//
//  ContentView.swift
//  DClutter
//

import SwiftUI
import DClutterUI

struct ContentView: View {
    var body: some View {
        TriageView(folder: Self.downloadsFolder)
    }

    /// In a sandboxed app, `homeDirectoryForCurrentUser` returns the
    /// container path (~/Library/Containers/dev.djenriquez.DClutter/Data),
    /// not the real home — appending "Downloads" to it would scan an empty
    /// folder inside the container. `.downloadsDirectory` is what the
    /// `com.apple.security.files.downloads.read-write` entitlement (§7)
    /// actually redirects to the real ~/Downloads. The fallback only matters
    /// if that lookup itself throws, which the entitled, standard-domain
    /// case shouldn't.
    private static var downloadsFolder: URL {
        (try? FileManager.default.url(for: .downloadsDirectory, in: .userDomainMask, appropriateFor: nil, create: false))
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
    }
}

#Preview {
    ContentView()
}
```

- [ ] **Step 3: Build the full app**

Run: `xcodebuild -project DClutter.xcodeproj -scheme DClutter -destination 'platform=macOS' build 2>&1 | tail -40`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Manual smoke test**

Launch the app (via Xcode run, or `open` the built `.app`), grant Downloads access if prompted, and confirm by hand:

- A card appears with a real thumbnail, filename, chips, and metadata rows matching the top of the M1 gate-check ranking.
- →/K keeps and advances; ←/X stages and advances; Space skips and the skipped file reappears once everything else is decided; ⌘Z undoes the last decision; ↑ shows a live QuickLook preview, Esc returns to the thumbnail; ⌘⏎ opens the commit sheet listing staged files, and confirming actually moves them to Trash (verify in Finder).
- Quit and relaunch: previously-decided files don't reappear as `current`.

This is the hand-verification step for `DClutterUI` per the project's testing convention — no XCUITest added.

- [ ] **Step 5: Commit**

```bash
git add DClutterKit/Sources/DClutterUI/TriageView.swift DClutter/ContentView.swift
git commit -m "Add TriageView with keyboard bindings and wire it into the app"
```

---

## Post-plan check

After Task 15, re-run `cd DClutterKit && swift test` (all Core + Platform tests) and confirm `DClutterCoreTests` still exercises invariants 3 and 5 explicitly (Task 4/5's tests), and `DClutterPlatformTests` exercises invariant 1 (Task 6's `realTrashMovesFileOutOfItsFolderNotDeletesIt`). Invariant 4 (undo before move) has no code path yet — M4's job, not a gap here.

Also confirm during the Task 15 manual smoke test that ⌘Z after a commit does nothing (no reverted card for a file that's now in Trash) — `commitTrashedTransitionsStateAndClearsUndoHistory` (Task 4) covers this at the unit level, but it's worth eyeballing once against the real app since it was the most severe bug caught in this plan's review.
