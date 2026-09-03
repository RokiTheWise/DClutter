# Folder Switching Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user triage any folder they pick, not just `~/Downloads`, with Downloads remaining the zero-setup default.

**Architecture:** The source folder becomes a bookmark-backed value instead of a constant. `SourceFolderStore` mints and resolves app-scoped security-scoped bookmarks for source folders and keeps a recents list — the same mechanism `DestinationStore` already uses for the write side, pointed at the read side. Because a source folder is touched continuously (scan, thumbnails, trash, rename, undo) rather than one file at a time, its security scope is held for the session's lifetime by a `ScopedFolderAccess` RAII holder instead of per-operation. Session persistence becomes one file per folder so decisions never leak across folders.

**Tech Stack:** Swift 6 (strict concurrency), SwiftUI, `@Observable`, Swift Testing, AppKit `NSOpenPanel`, Foundation security-scoped bookmarks.

**Spec:** `plandocs/dclutter-plan.md` (amended by Task 0 — see below)

## Global Constraints

Copied verbatim from the spec's handoff note and CLAUDE.md. Every task's requirements implicitly include this section.

- No code path calls `FileManager.removeItem` on a user file. Trash only, via `trashItem(at:resultingItemURL:)`.
- No file operation touches anything outside `~/Downloads` or a user-selected, bookmark-backed folder.
- `.staged` files are never touched on disk until the user confirms the commit sheet.
- Every `.moved` operation registers an undo before it executes, not after.
- Session state persists after every single decision, not on quit.
- `DClutterCore` imports **only** `Foundation` and `UniformTypeIdentifiers`. No AppKit, ever.
- Swift 6 language mode, strict concurrency. `DClutterCore` should be fully `Sendable`.
- `@Observable` (macOS 14+) rather than `ObservableObject`.
- Deployment target stays macOS 14. Universal binary (`x86_64 arm64`).
- "Unit tests target `DClutterCore` only. The platform layer is verified by hand; don't build an elaborate filesystem-mocking harness." Where this plan adds Platform tests they are pure-logic tests only — no filesystem or bookmark mocking.
- Ask before pushing. Committing locally is fine.
- **`plandocs/` and `CLAUDE.md` are gitignored on purpose** (`.gitignore:29` and `:34`, under "User Defined"). They are private working documents and have never been in the public repo. Edit them on disk; never `git add -f` them, and never include them in a commit.

---

## Why this is not a spec violation

§1 lists "Any folder other than `~/Downloads`" under **Explicitly NOT in v1**, and the handoff note says items on that list stay out even when they look easy. That gate was real and it held: v1 shipped as v0.4.0 with Downloads only.

This is post-v1 work, authorised explicitly. Task 0 amends the spec so the next reader does not meet a contradiction, because CLAUDE.md makes `plandocs/dclutter-plan.md` the spec rather than a historical record.

One argument from §7 does get weakened by this change and should be recorded honestly: the doc claims `downloads.read-write` means "no permission prompt", and that is wrong. The entitlement satisfies the *sandbox*, but TCC still prompts on first access to Downloads on macOS 14+. So the app already spends a permission prompt, and a folder picker does not introduce friction into an otherwise frictionless flow.

## File Structure

| File | Responsibility | Status |
|---|---|---|
| `DClutterKit/Sources/DClutterCore/SessionPersistence.swift` | Pure function mapping a folder URL to its session filename | Create |
| `DClutterKit/Sources/DClutterPlatform/ScopedFolderAccess.swift` | RAII holder for a session-lifetime security scope | Create |
| `DClutterKit/Sources/DClutterPlatform/SourceFolderStore.swift` | Bookmark persistence + recents list for source folders | Create |
| `DClutterKit/Sources/DClutterUI/FolderField.swift` | The folder location field and its menu | Create |
| `DClutterKit/Sources/DClutterUI/TriageView.swift` | Folder as state, reload path, switch confirmation | Modify |
| `DClutter/ContentView.swift` | Stops computing Downloads itself | Modify |
| `DClutterKit/Tests/DClutterCoreTests/SessionPersistenceTests.swift` | Filename derivation | Create |
| `DClutterKit/Tests/DClutterPlatformTests/SourceFolderStoreTests.swift` | Recents ordering/dedup/cap | Create |

`DClutterCore` gains one file and no dependencies. All bookmark and AppKit work stays in Platform and UI, so the module boundary is unchanged.

---

## Task 0: Amend the spec

**Files:**
- Modify: `plandocs/dclutter-plan.md:52` (§1 In scope), `plandocs/dclutter-plan.md:66` (§1 exclusions), `plandocs/dclutter-plan.md:381` (§7), `plandocs/dclutter-plan.md:405` (§8 table), `plandocs/dclutter-plan.md:472` (§9)

**Interfaces:**
- Consumes: nothing
- Produces: the spec every later task argues from

- [ ] **Step 1: Move the exclusion into scope**

In §1's "Explicitly NOT in v1" list, delete the line:

```markdown
- Any folder other than `~/Downloads`
```

In §1, under a new heading after "In scope for v1", add:

```markdown
### Added post-v1 (M6)

- **A source folder other than `~/Downloads`.** Downloads stays the launch
  default and needs no setup; any other folder is picked through
  `NSOpenPanel` and persisted as an app-scoped security-scoped bookmark —
  the same mechanism destinations already use, pointed at the read side.
  Session state is kept per folder, so switching never applies one folder's
  decisions to another's files.
```

- [ ] **Step 2: Correct the §7 permission-prompt claim**

Replace the paragraph beginning "The `downloads.read-write` entitlement grants" with:

```markdown
The `downloads.read-write` entitlement grants `~/Downloads` access without a
Full Disk Access requirement, which is why the original scope was
Downloads-only. Note the doc previously claimed this meant *no permission
prompt at all* — that is wrong. The entitlement satisfies the sandbox; TCC
still prompts on first access on macOS 14+. The app therefore already spends
one prompt, which is what makes a source-folder picker defensible rather than
a new tax on setup.

Move destinations, and any source folder other than Downloads, are outside
that grant, so they require the user to pick them via `NSOpenPanel`, after
which you persist an app-scoped security-scoped bookmark. Remember
`startAccessingSecurityScopedResource()` / `stopAccessing...` around every
write — and note that a *source* folder needs that scope held for the whole
session, not per operation, because the scan, thumbnails, trash, rename and
undo all sit inside it.
```

- [ ] **Step 3: Add M6 to the timeline table**

Append a row to the §8 milestone table:

```markdown
| **M6 — Folder switching** | Folder location field, source-folder bookmarks, per-folder session state, staged-trash resolution on switch | Post-v1 |
```

- [ ] **Step 4: Prune the superseded §9 entry**

In §9, replace the line `- Expand to ~/Desktop (needs different entitlement strategy)` with:

```markdown
- ~~Expand to `~/Desktop`~~ — superseded by M6, which generalises to any
  user-picked folder rather than naming one.
```

- [ ] **Step 5: Do not commit**

`plandocs/` is gitignored deliberately — the spec is a private working
document. Leave the edits in the working tree, uncommitted and untracked.
Do not `git add -f` it.

---

## Task 1: Per-folder session filename

The session file is a single fixed path today, so the first folder switch would reconcile one folder's saved decisions against another folder's files. This is a latent bug that must be fixed before anything can switch folders.

**Files:**
- Create: `DClutterKit/Sources/DClutterCore/SessionPersistence.swift`
- Test: `DClutterKit/Tests/DClutterCoreTests/SessionPersistenceTests.swift`

**Interfaces:**
- Consumes: nothing
- Produces: `SessionPersistence.filename(for folder: URL) -> String`

- [ ] **Step 1: Write the failing test**

Create `DClutterKit/Tests/DClutterCoreTests/SessionPersistenceTests.swift`:

```swift
//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import Testing
import Foundation
@testable import DClutterCore

@Suite("Session persistence filenames")
struct SessionPersistenceTests {
    @Test("The same folder always maps to the same file")
    func stableForSameFolder() {
        let folder = URL(fileURLWithPath: "/Users/someone/Downloads")
        #expect(
            SessionPersistence.filename(for: folder)
                == SessionPersistence.filename(for: folder)
        )
    }

    @Test("Different folders never share a session file")
    func distinctForDifferentFolders() {
        let downloads = URL(fileURLWithPath: "/Users/someone/Downloads")
        let desktop = URL(fileURLWithPath: "/Users/someone/Desktop")
        #expect(
            SessionPersistence.filename(for: downloads)
                != SessionPersistence.filename(for: desktop)
        )
    }

    @Test("Trailing slashes and dot segments name the same folder")
    func normalisesEquivalentPaths() {
        let plain = URL(fileURLWithPath: "/Users/someone/Downloads")
        let trailing = URL(fileURLWithPath: "/Users/someone/Downloads/")
        let dotted = URL(fileURLWithPath: "/Users/someone/Music/../Downloads")
        #expect(SessionPersistence.filename(for: plain) == SessionPersistence.filename(for: trailing))
        #expect(SessionPersistence.filename(for: plain) == SessionPersistence.filename(for: dotted))
    }

    @Test("The result is a single usable path component")
    func isASinglePathComponent() {
        let name = SessionPersistence.filename(for: URL(fileURLWithPath: "/Users/someone/Downloads"))
        #expect(!name.contains("/"))
        #expect(name.hasPrefix("session-"))
        #expect(name.hasSuffix(".json"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
swift test --package-path DClutterKit --filter SessionPersistenceTests
```

Expected: FAIL — `cannot find 'SessionPersistence' in scope`.

- [ ] **Step 3: Write minimal implementation**

Create `DClutterKit/Sources/DClutterCore/SessionPersistence.swift`:

```swift
//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import Foundation

/// Where a folder's session state lives.
///
/// One file per source folder, not one file overall. `DClutterSession`
/// reconciles a snapshot against whatever candidates it is handed, so a
/// single fixed `session.json` would apply Downloads' saved decisions to
/// another folder's files the moment the source folder can change.
///
/// Keeping them separate also makes "leave them staged" a coherent answer
/// when switching folders: the staged set stays with the folder it belongs
/// to and is still there when you switch back.
public enum SessionPersistence {
    /// FNV-1a over the normalised path. A hash rather than the path itself
    /// because a path contains `/` and can exceed the filename length
    /// limit; FNV-1a rather than SHA because Core is limited to Foundation
    /// and this needs to be stable, not cryptographic.
    public static func filename(for folder: URL) -> String {
        let path = folder.resolvingSymlinksInPath().standardizedFileURL.path
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in path.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return "session-\(String(hash, radix: 16)).json"
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
swift test --package-path DClutterKit --filter SessionPersistenceTests
```

Expected: PASS, 4 tests.

- [ ] **Step 5: Commit**

```bash
git add DClutterKit/Sources/DClutterCore/SessionPersistence.swift DClutterKit/Tests/DClutterCoreTests/SessionPersistenceTests.swift
git commit -m "Key session state per source folder"
```

---

## Task 2: Session-lifetime security scope

**Files:**
- Create: `DClutterKit/Sources/DClutterPlatform/ScopedFolderAccess.swift`
- Test: `DClutterKit/Tests/DClutterPlatformTests/ScopedFolderAccessTests.swift`

**Interfaces:**
- Consumes: nothing
- Produces: `ScopedFolderAccess(url: URL)`, `.url: URL`, `.isScoped: Bool`

- [ ] **Step 1: Write the failing test**

Create `DClutterKit/Tests/DClutterPlatformTests/ScopedFolderAccessTests.swift`:

```swift
//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import Testing
import Foundation
@testable import DClutterPlatform

@Suite("Scoped folder access")
struct ScopedFolderAccessTests {
    /// A plain directory URL carries no security scope. That is the normal
    /// answer for ~/Downloads, where the entitlement grants access
    /// directly, so it must not be treated as a failure.
    @Test("A non-scoped URL reports isScoped false and still exposes its url")
    func plainURLIsNotScoped() {
        let dir = FileManager.default.temporaryDirectory
        let access = ScopedFolderAccess(url: dir)
        #expect(access.isScoped == false)
        #expect(access.url == dir)
    }

    @Test("Releasing a non-scoped access is harmless")
    func deinitIsSafeWhenNeverStarted() {
        for _ in 0..<3 {
            _ = ScopedFolderAccess(url: FileManager.default.temporaryDirectory)
        }
        #expect(Bool(true))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
swift test --package-path DClutterKit --filter ScopedFolderAccessTests
```

Expected: FAIL — `cannot find 'ScopedFolderAccess' in scope`.

- [ ] **Step 3: Write minimal implementation**

Create `DClutterKit/Sources/DClutterPlatform/ScopedFolderAccess.swift`:

```swift
//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import Foundation

/// Holds a folder's security scope open for as long as this object lives.
///
/// The plan's handoff note asks for exactly this — "security-scoped
/// bookmarks silently fail if you forget `startAccessingSecurityScopedResource()`;
/// wrap it in a helper so this can't be forgotten at a call site."
///
/// `FileActions` takes scope per operation, which is right for a
/// *destination*: it is touched one file at a time. A *source* folder is
/// the opposite — the scan, every thumbnail, every trash, rename and undo
/// all need it — so its scope is tied to the session instead of to a call.
public final class ScopedFolderAccess {
    public let url: URL
    private let didStart: Bool

    public init(url: URL) {
        self.url = url
        self.didStart = url.startAccessingSecurityScopedResource()
    }

    /// False when the URL carries no security scope at all. That is the
    /// correct, expected answer for `~/Downloads`, which the entitlement
    /// grants directly — so a false here is not on its own an error.
    public var isScoped: Bool { didStart }

    deinit {
        if didStart { url.stopAccessingSecurityScopedResource() }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
swift test --package-path DClutterKit --filter ScopedFolderAccessTests
```

Expected: PASS, 2 tests.

- [ ] **Step 5: Commit**

```bash
git add DClutterKit/Sources/DClutterPlatform/ScopedFolderAccess.swift DClutterKit/Tests/DClutterPlatformTests/ScopedFolderAccessTests.swift
git commit -m "Hold source-folder scope for the session, not per operation"
```

---

## Task 3: Source folder bookmarks and recents

**Files:**
- Create: `DClutterKit/Sources/DClutterPlatform/SourceFolderStore.swift`
- Test: `DClutterKit/Tests/DClutterPlatformTests/SourceFolderStoreTests.swift`

**Interfaces:**
- Consumes: nothing
- Produces: `SourceFolderStore(defaults:)`, `.recents() -> [URL]`, `.remember(_ url: URL)`, `SourceFolderStore.maximumRecents`, and the pure helper `SourceFolderStore.merged(_:adding:) -> [String]`

Note on testing: bookmark minting is not exercised in tests. `.withSecurityScope` bookmarks behave differently outside a sandbox, and the spec forbids an elaborate filesystem harness. The ordering rules are extracted into `merged(_:adding:)` so the part with actual logic is tested and the part that is a Foundation call is verified by hand.

- [ ] **Step 1: Write the failing test**

Create `DClutterKit/Tests/DClutterPlatformTests/SourceFolderStoreTests.swift`:

```swift
//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import Testing
import Foundation
@testable import DClutterPlatform

@Suite("Source folder recents")
struct SourceFolderStoreTests {
    @Test("A new folder goes to the front")
    func newestFirst() {
        let merged = SourceFolderStore.merged(["/a", "/b"], adding: "/c")
        #expect(merged == ["/c", "/a", "/b"])
    }

    @Test("Re-picking a folder promotes it instead of duplicating it")
    func promotesExisting() {
        let merged = SourceFolderStore.merged(["/a", "/b", "/c"], adding: "/c")
        #expect(merged == ["/c", "/a", "/b"])
    }

    @Test("The list is capped")
    func capsAtMaximum() {
        let existing = (1...SourceFolderStore.maximumRecents).map { "/folder\($0)" }
        let merged = SourceFolderStore.merged(existing, adding: "/new")
        #expect(merged.count == SourceFolderStore.maximumRecents)
        #expect(merged.first == "/new")
        #expect(!merged.contains("/folder\(SourceFolderStore.maximumRecents)"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
swift test --package-path DClutterKit --filter SourceFolderStoreTests
```

Expected: FAIL — `cannot find 'SourceFolderStore' in scope`.

- [ ] **Step 3: Write minimal implementation**

Create `DClutterKit/Sources/DClutterPlatform/SourceFolderStore.swift`:

```swift
//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import Foundation

/// Remembers which folders the user has triaged, as app-scoped
/// security-scoped bookmarks (§7).
///
/// Deliberately the same shape as `DestinationStore`: a plain path would
/// not survive relaunch, because the sandbox only grants `~/Downloads`
/// directly and every other folder has to be re-entered through a bookmark
/// minted from the user's own `NSOpenPanel` choice.
///
/// `~/Downloads` is not stored here. It needs no bookmark, it is always
/// offered, and keeping it out means the recents list is exactly "folders
/// you chose".
public struct SourceFolderStore {
    /// Small on purpose. This is a shortcut back to somewhere you were, not
    /// a file browser.
    public static let maximumRecents = 5

    private let defaultsKey = "dev.djenriquez.DClutter.sourceFolders"
    // Not Sendable: UserDefaults isn't, and this is only ever touched from
    // the main actor by the view that owns the folder field.
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private struct Stored: Codable {
        let bookmark: Data
        let path: String
    }

    /// Most recent first. An entry whose bookmark no longer resolves is
    /// dropped rather than offered as a folder that cannot be opened.
    public func recents() -> [URL] {
        stored().compactMap { entry in
            var isStale = false
            return try? URL(
                resolvingBookmarkData: entry.bookmark,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
        }
    }

    /// Records `url` as the most recently used folder. Silently does
    /// nothing if a bookmark cannot be minted — the folder still works for
    /// this session, it just will not be offered next launch.
    public func remember(_ url: URL) {
        guard let bookmark = try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return }

        let order = Self.merged(stored().map(\.path), adding: url.path)
        // uniquingKeysWith, not uniqueKeysWithValues: the latter traps on a
        // duplicate, and a defaults blob is not something we control.
        var byPath = Dictionary(stored().map { ($0.path, $0) }, uniquingKeysWith: { first, _ in first })
        byPath[url.path] = Stored(bookmark: bookmark, path: url.path)

        let updated = order.compactMap { byPath[$0] }
        guard let data = try? JSONEncoder().encode(updated) else { return }
        defaults.set(data, forKey: defaultsKey)
    }

    /// Newest first, no duplicates, capped. Split out from `remember` so
    /// the ordering rules are testable without minting real bookmarks.
    static func merged(_ existing: [String], adding path: String) -> [String] {
        var result = existing.filter { $0 != path }
        result.insert(path, at: 0)
        return Array(result.prefix(maximumRecents))
    }

    private func stored() -> [Stored] {
        guard let data = defaults.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([Stored].self, from: data)
        else { return [] }
        return decoded
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
swift test --package-path DClutterKit --filter SourceFolderStoreTests
```

Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
git add DClutterKit/Sources/DClutterPlatform/SourceFolderStore.swift DClutterKit/Tests/DClutterPlatformTests/SourceFolderStoreTests.swift
git commit -m "Persist chosen source folders as security-scoped bookmarks"
```

---

## Task 4: Make the folder switchable state

No new tests: this is view wiring, which the spec puts under "verified by hand". Verification is the manual checklist in Step 5.

**Files:**
- Modify: `DClutterKit/Sources/DClutterUI/TriageView.swift:41-43` (stored folder), `:625-646` (`loadSession`)
- Modify: `DClutter/ContentView.swift:9-27`

**Interfaces:**
- Consumes: `SessionPersistence.filename(for:)` (Task 1), `ScopedFolderAccess` (Task 2), `SourceFolderStore` (Task 3)
- Produces: `TriageView.switchFolder(to url: URL)`, `TriageView.folder` as `@State`, `TriageView.defaultDownloadsFolder` as a `public static var`

- [ ] **Step 1: Move the Downloads lookup into TriageView**

`ContentView` currently computes the folder. That belongs next to the code that can also change it. Replace the whole body of `DClutter/ContentView.swift` with:

```swift
//
//  ContentView.swift
//  DClutter
//

import SwiftUI
import DClutterUI

struct ContentView: View {
    var body: some View {
        TriageView(folder: TriageView.defaultDownloadsFolder)
    }
}

#Preview {
    ContentView()
}
```

- [ ] **Step 2: Turn the folder into state and add the Downloads default**

In `TriageView.swift`, replace `let folder: URL` and the initialiser with:

```swift
    /// The folder being triaged. State, not a constant: it is the one
    /// thing on this screen the user can change without quitting.
    @State private var folder: URL
    /// Held for as long as this folder is the source. Nil for Downloads,
    /// which the entitlement reaches without a bookmark.
    @State private var access: ScopedFolderAccess?
    @State private var recentFolders: [URL] = []
    private let sourceFolderStore = SourceFolderStore()

    public init(folder: URL) {
        _folder = State(initialValue: folder)
    }

    /// In a sandboxed app, `homeDirectoryForCurrentUser` returns the
    /// container path, not the real home — appending "Downloads" to it
    /// would scan an empty folder inside the container.
    /// `.downloadsDirectory` is what the
    /// `com.apple.security.files.downloads.read-write` entitlement (§7)
    /// resolves to the real ~/Downloads.
    ///
    /// Note it resolves to a *symlink* into the real folder, not the
    /// folder itself; `DirectoryMetadataProvider` resolves that, since the
    /// URL-based directory enumeration refuses to follow symlinks.
    public static var defaultDownloadsFolder: URL {
        (try? FileManager.default.url(for: .downloadsDirectory, in: .userDomainMask, appropriateFor: nil, create: false))
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
    }

    /// True when `folder` is the entitlement-granted Downloads folder,
    /// which needs neither a bookmark nor a held scope.
    private var isDownloads: Bool {
        folder.resolvingSymlinksInPath().standardizedFileURL
            == Self.defaultDownloadsFolder.resolvingSymlinksInPath().standardizedFileURL
    }
```

- [ ] **Step 3: Key the session file to the folder, and carry the old one forward**

In `loadSession()`, replace the two lines that build `persistenceURL`:

```swift
        let persistenceURL = (supportDir ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("session.json")
```

with:

```swift
        let stateDir = supportDir ?? FileManager.default.temporaryDirectory
        let persistenceURL = stateDir
            .appendingPathComponent(SessionPersistence.filename(for: folder))

        // Anyone upgrading from ≤0.4.0 has an in-progress session in the
        // old fixed filename. It can only ever have been Downloads, so
        // carry it onto Downloads' new name rather than silently dropping
        // someone's half-finished run.
        let legacy = stateDir.appendingPathComponent("session.json")
        if isDownloads,
           FileManager.default.fileExists(atPath: legacy.path),
           !FileManager.default.fileExists(atPath: persistenceURL.path) {
            try? FileManager.default.moveItem(at: legacy, to: persistenceURL)
        }
```

- [ ] **Step 4: Add the switch itself, and make the load re-run**

Change the `ProgressView` branch in `body` from `.task { await loadSession() }` to:

```swift
                ProgressView().task(id: folder) { await loadSession() }
```

Then add, next to the other private helpers:

```swift
    /// Points the app at a different folder. The previous folder's scope is
    /// released only after the new one is held, and the session is torn
    /// down so `.task(id:)` rebuilds it against the new candidates.
    ///
    /// Decisions already carried out on disk are left alone — a move is a
    /// finished action, and having twenty of them fly back to Downloads
    /// because you glanced at another folder is a worse surprise than
    /// leaving them where you put them. Only staged trash is pending, and
    /// `confirmSwitch` resolves that before calling this.
    private func switchFolder(to url: URL) {
        guard url.standardizedFileURL != folder.standardizedFileURL else { return }
        access = ScopedFolderAccess(url: url)
        if url.resolvingSymlinksInPath().standardizedFileURL
            != Self.defaultDownloadsFolder.resolvingSymlinksInPath().standardizedFileURL {
            sourceFolderStore.remember(url)
            recentFolders = sourceFolderStore.recents()
        }
        viewModel = nil
        context = nil
        loadError = nil
        shelfOpen = false
        swipeMonitor.endShelfSteering()
        folder = url
        isFocused = true
    }

    /// Asks for a folder. The sandbox grants access only through the panel
    /// or a bookmark it minted — a typed path grants nothing — so this is
    /// the only way in.
    private func chooseSourceFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Triage Folder"
        panel.message = "Pick a folder to sort through."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        requestSwitch(to: url)
    }
```

Add `import AppKit` to the top of `TriageView.swift` if it is not already present, and load recents on appear by adding this line to the existing `.onAppear` block:

```swift
            recentFolders = sourceFolderStore.recents()
```

- [ ] **Step 5: Verify by hand**

`requestSwitch(to:)` does not exist yet — it arrives in Task 6. Until then, temporarily call `switchFolder(to:)` directly from `chooseSourceFolder` so the build passes, and restore the call in Task 6.

Build and run, then confirm:

```bash
xcodebuild -project DClutter.xcodeproj -scheme DClutter -configuration Debug -destination 'platform=macOS' build
```

- App still opens on Downloads with no new prompt.
- An existing `session.json` in `~/Library/Containers/dev.djenriquez.DClutter/Data/Library/Application Support/DClutter/` is renamed to `session-<hash>.json` on first launch, and prior decisions survive.
- Making a decision writes to the hashed filename, not `session.json`.

- [ ] **Step 6: Commit**

```bash
git add DClutterKit/Sources/DClutterUI/TriageView.swift DClutter/ContentView.swift
git commit -m "Make the source folder switchable state"
```

---

## Task 5: The folder location field

**Files:**
- Create: `DClutterKit/Sources/DClutterUI/FolderField.swift`
- Modify: `DClutterKit/Sources/DClutterUI/TriageView.swift:330-336` (`controlBar`)

**Interfaces:**
- Consumes: `TriageView.switchFolder(to:)`, `TriageView.chooseSourceFolder()`
- Produces: `FolderField(url:recents:onPick:onChoose:)`

**Why this is a menu and not a text field.** It reads like a location field — a tilde-abbreviated path — but it is not editable, because under the sandbox a typed path grants no access whatsoever. There is no API that turns a string into permission. Access comes only from an `NSOpenPanel` selection or a bookmark one previously minted, so every route in has to pass through the panel.

`NSPathControl` was the other candidate and is rejected: in `.popUp` style it offers every *ancestor* of the path as a destination, and the sandbox grants access to none of them, so most of its menu would be dead entries.

- [ ] **Step 1: Create the control**

```swift
//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import SwiftUI

/// Which folder is being triaged, and the way to change it.
///
/// Reads as a location field so the answer to "where am I?" is always on
/// screen, but it is a menu rather than an editable field: under the
/// sandbox a typed path grants no access at all, so the only routes in are
/// `NSOpenPanel` and a bookmark that panel already minted.
struct FolderField: View {
    let url: URL
    let recents: [URL]
    /// A folder already bookmarked — switch straight to it.
    let onPick: (URL) -> Void
    /// Open the panel for somewhere new.
    let onChoose: () -> Void

    var body: some View {
        Menu {
            Button("Downloads") { onPick(TriageView.defaultDownloadsFolder) }
            if !recents.isEmpty {
                Divider()
                ForEach(recents, id: \.self) { recent in
                    Button(Self.displayPath(for: recent)) { onPick(recent) }
                }
            }
            Divider()
            Button("Choose Folder…") { onChoose() }
        } label: {
            HStack(spacing: DesignTokens.Spacing.unit) {
                Image(systemName: "folder")
                    .font(.system(size: 11))
                Text(Self.displayPath(for: url))
                    .font(.system(size: 12, design: .monospaced))
                    .lineLimit(1)
                    // A long path loses its middle, never its end — the
                    // folder name is the part that identifies it.
                    .truncationMode(.middle)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9))
            }
            .foregroundStyle(DesignTokens.ColorToken.textSecondary)
            .frame(maxWidth: 260, alignment: .leading)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Triaging \(url.path) — click to switch folders")
    }

    /// `~/Downloads` rather than `/Users/you/Downloads`.
    ///
    /// Cannot use `abbreviatingWithTildeInPath`: in a sandboxed app
    /// `NSHomeDirectory()` is the *container*, not the real home, so the
    /// substitution silently never matches and the field shows a full path.
    /// `getpwuid` reports the real home regardless of the container.
    static func displayPath(for url: URL) -> String {
        let path = url.resolvingSymlinksInPath().standardizedFileURL.path
        guard !realHome.isEmpty, path == realHome || path.hasPrefix(realHome + "/") else {
            return path
        }
        return "~" + path.dropFirst(realHome.count)
    }

    private static let realHome: String = {
        guard let entry = getpwuid(getuid()), let dir = entry.pointee.pw_dir else { return "" }
        return String(cString: dir)
    }()
}
```

- [ ] **Step 2: Put it in the control bar**

In `controlBar`, immediately after the `BrandMark` block and before `Spacer()`, insert:

```swift
            Divider().frame(height: 16)
            FolderField(
                url: folder,
                recents: recentFolders,
                onPick: { requestSwitch(to: $0) },
                onChoose: { chooseSourceFolder() }
            )
```

As in Task 4, call `switchFolder(to:)` in place of `requestSwitch(to:)` until Task 6 lands.

- [ ] **Step 3: Verify by hand**

```bash
xcodebuild -project DClutter.xcodeproj -scheme DClutter -configuration Debug -destination 'platform=macOS' build
```

- The bar reads `~/Downloads` at launch, not the full `/Users/...` path.
- "Choose Folder…" opens the panel; picking a folder reloads the queue against it.
- That folder then appears under the Downloads entry on the next launch.
- **`ScopedFolderAccess`'s default closures actually work.** The unit suite
  only exercises the injected seam, never the defaults that call the real
  `startAccessingSecurityScopedResource`. This is the first task where the
  sandboxed app runs them, so it is the first chance to catch a mis-wiring:
  switch to a non-Downloads folder and confirm its files load, thumbnails
  render, and a rename succeeds. All three fail if scope is not actually
  held.
- Switching back to Downloads restores Downloads' own decisions, not the other folder's.

- [ ] **Step 4: Commit**

```bash
git add DClutterKit/Sources/DClutterUI/FolderField.swift DClutterKit/Sources/DClutterUI/TriageView.swift
git commit -m "Add the folder location field and its switcher menu"
```

---

## Task 6: Resolve staged trash before switching

**Files:**
- Modify: `DClutterKit/Sources/DClutterUI/TriageView.swift`

**Interfaces:**
- Consumes: `switchFolder(to:)` (Task 4), `SessionViewModel.stagedForCommit`, `SessionViewModel.confirmCommit()`
- Produces: `TriageView.requestSwitch(to url: URL)`

- [ ] **Step 1: Add the pending-switch state**

Alongside the other `@State` properties:

```swift
    /// A folder the user asked for while files were still staged. Held
    /// until they say what should happen to the staged set.
    @State private var pendingSwitch: URL?
```

- [ ] **Step 2: Add the gate**

```swift
    /// Staged trash is the only genuinely pending state — a move already
    /// happened on disk and stays done. So a switch asks about staged files
    /// and nothing else.
    private func requestSwitch(to url: URL) {
        guard let viewModel, !viewModel.stagedForCommit.isEmpty else {
            switchFolder(to: url)
            return
        }
        pendingSwitch = url
    }
```

- [ ] **Step 3: Add the confirmation**

Attach to the same view that carries `showResetConfirm`'s dialog:

```swift
        .confirmationDialog(
            "Switch folders?",
            isPresented: Binding(
                get: { pendingSwitch != nil },
                set: { if !$0 { pendingSwitch = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let viewModel {
                Button("Trash \(viewModel.stagedForCommit.count) File\(viewModel.stagedForCommit.count == 1 ? "" : "s")", role: .destructive) {
                    viewModel.confirmCommit()
                    // Only leave if it worked. confirmCommit keeps the error
                    // on the view model when a file could not be trashed, and
                    // switching away would take that message off screen along
                    // with the folder it belongs to.
                    if viewModel.commitError == nil, let target = pendingSwitch {
                        switchFolder(to: target)
                    }
                    pendingSwitch = nil
                }
            }
            Button("Leave Them Staged") {
                if let target = pendingSwitch { switchFolder(to: target) }
                pendingSwitch = nil
            }
            Button("Cancel", role: .cancel) { pendingSwitch = nil }
        } message: {
            if let viewModel {
                Text("\(viewModel.stagedForCommit.count) file\(viewModel.stagedForCommit.count == 1 ? " is" : "s are") staged for trash. Files you already filed into folders stay where they are either way.")
            }
        }
```

- [ ] **Step 4: Restore the real call sites**

Replace the temporary `switchFolder(to:)` calls from Tasks 4 and 5 with `requestSwitch(to:)` in `chooseSourceFolder()` and in the `FolderField`'s `onPick`.

- [ ] **Step 5: Verify by hand**

```bash
xcodebuild -project DClutter.xcodeproj -scheme DClutter -configuration Debug -destination 'platform=macOS' build
```

- Switching with nothing staged switches immediately, no dialog.
- Stage two files, then switch: the dialog names two files.
- "Leave Them Staged" switches; returning to that folder shows both still staged.
- "Trash 2 Files" empties them into the Trash, then switches.
- Files filed into destination folders stay filed under either choice.
- Cancel leaves you exactly where you were.

- [ ] **Step 6: Commit**

```bash
git add DClutterKit/Sources/DClutterUI/TriageView.swift
git commit -m "Resolve staged trash before switching folders"
```

---

## Task 7: Documentation

**Files:**
- Modify: `README.md:36`, `README.md:193-199`, `README.md:63-91` (controls tables)
- Modify: `CLAUDE.md`

- [ ] **Step 1: Correct the README's scope line**

Replace `It reads ~/Downloads and nothing else.` with:

```markdown
It opens on `~/Downloads` and needs no setup to do it. You can point it at
any other folder from the path shown in the top bar — macOS will ask you to
pick that one explicitly, because an app in the sandbox can only reach a
folder you handed it yourself.
```

- [ ] **Step 2: Remove the shipped item from "Not done yet"**

Delete the whole `**Scanning a folder other than ~/Downloads.**` bullet, leaving the notarised-distribution one.

- [ ] **Step 3: Document the control**

Add to the **Trackpad and mouse** table:

```markdown
| Click the folder path | Switch folders, or add a new one |
```

- [ ] **Step 4: Update CLAUDE.md's current state**

Replace the "Current state" paragraph's first sentence with a line noting v0.4.0 shipped and M6 (folder switching) is on `m6-folder-switching`, and delete the claim that scanning another folder is unbuilt.

- [ ] **Step 5: Full verification**

```bash
swift test --package-path DClutterKit
```

Expected: all tests pass, including the 9 added by this plan.

```bash
xcodebuild -project DClutter.xcodeproj -scheme DClutter -configuration Release -destination 'platform=macOS' build
```

Then, per `docs/RELEASING.md`, check the built binary rather than the project file:

```bash
otool -l "$(find ~/Library/Developer/Xcode/DerivedData/DClutter-*/Build/Products/Release/DClutter.app -name DClutter -type f)" | grep -A3 LC_BUILD_VERSION | head
lipo -archs "$(find ~/Library/Developer/Xcode/DerivedData/DClutter-*/Build/Products/Release/DClutter.app -name DClutter -type f)"
```

Expected: `minos 14.0`, and `x86_64 arm64`.

- [ ] **Step 6: Commit**

`CLAUDE.md` is gitignored — edit it on disk, but commit only the README:

```bash
git add README.md
git commit -m "Document folder switching"
```

---

## Out of scope

Named here so they are decisions, not oversights:

- **Multiple folders at once.** §1 excludes bulk mode; one folder at a time is the same principle.
- **Renaming a folder's label.** Cut from M4 for the destination shelf; no reason to reintroduce it here.
- **Watching the folder for changes.** The app is episodic by design (CLAUDE.md) — a scan at open is the right granularity.
- **Recursing into subfolders.** Today the queue is one level deep and `isDirectory` is carried but not descended. Changing that is a queue-semantics change, not a folder-source change.
