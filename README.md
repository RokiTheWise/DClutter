<div align="center">

<img src="docs/assets/logo.png" width="160" alt="DClutter">

# DClutter

**Swipe to clean your files.**

One file at a time, with a real preview and the metadata that actually decides
its fate. Keep it, trash it, or file it — with a gesture or a keystroke.

[![CI](https://img.shields.io/github/actions/workflow/status/RokiTheWise/DClutter/ci.yml?branch=main&style=flat-square&logo=githubactions&logoColor=white&label=CI&labelColor=24292e)](https://github.com/RokiTheWise/DClutter/actions/workflows/ci.yml)
[![Platform](https://img.shields.io/badge/macOS-14%2B-lightgrey.svg?style=flat-square&logo=apple&logoColor=white&labelColor=24292e)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6-orange.svg?style=flat-square&logo=swift&logoColor=white&labelColor=24292e)](https://swift.org)
[![Stars](https://img.shields.io/github/stars/RokiTheWise/DClutter.svg?style=flat-square&logo=github&logoColor=white&labelColor=24292e&color=yellow)](https://github.com/RokiTheWise/DClutter/stargazers)
[![License](https://img.shields.io/github/license/RokiTheWise/DClutter.svg?style=flat-square&logo=apache&logoColor=white&labelColor=24292e&color=blue)](LICENSE)

<!-- Uncomment once the first release is tagged — until then both render
     "no releases", which looks broken rather than early.
[![Release](https://img.shields.io/github/v/release/RokiTheWise/DClutter?include_prereleases&style=flat-square&logo=github&logoColor=white&labelColor=24292e&color=orange)](https://github.com/RokiTheWise/DClutter/releases)
[![Downloads](https://img.shields.io/github/downloads/RokiTheWise/DClutter/total.svg?style=flat-square&logo=docsdotrs&logoColor=white&labelColor=24292e&color=blue)](https://github.com/RokiTheWise/DClutter/releases)
-->

</div>

---

## What this is

Your Downloads folder isn't a disk-space problem — it's a folder of undecided
items. Measured against a real 771-item folder, every duplicate in it combined
wasted 27 MB: half a percent. Space wasn't the problem. The 771 unmade decisions
were.

So DClutter is a **decluttering tool, not a disk-space tool**. It shows you one
file at a time, ordered so the obviously-actionable things come first, and asks
for a single decision. Progress is measured in files resolved, never in bytes
reclaimed.

It reads `~/Downloads` and nothing else.

## How it works

Files are ranked, not listed alphabetically. The score is additive — size,
staleness, whether it was ever opened, whether it's a redundant copy, whether
it's an archive you already extracted — so no single signal can drown out the
others. Duplicates are found by filename and size, no hashing.

Then you decide:

- **Keep** — does nothing. The file stays exactly where it is.
- **Trash** — staged, not deleted. Nothing is touched until you review the list
  and confirm. Files go to the Trash, never `unlink`.
- **File it** — moves immediately into one of three folders you choose, and is
  undoable.

Reversibility is matched to risk: keep is free, a move is instant but undoable,
and a deletion requires an explicit confirmation of a list you can see.

## Controls

Keyboard is the primary interface; every action has a pointer equivalent.

### Keyboard

| Key | Action |
|---|---|
| `→` | Keep, next card |
| `←` | Stage for trash, next card |
| `Space` | Skip — comes back at the end |
| `1` – `3` | File into a destination folder |
| `↑` | Open the destination shelf |
| `←` `→` then `⏎` | Choose a folder and file it |
| `⌫` | Remove the highlighted folder |
| `Esc` / `↓` | Close the shelf |
| `⏎` | Open this file |
| `↓` | Rename this file |
| `⌘Z` / `⇧⌘Z` | Undo / redo |
| `⌘⏎` | Review and trash staged files |
| `⌘N` | Add a destination folder |
| `?` | Show the controls |

### Trackpad and mouse

| Gesture | Action |
|---|---|
| Swipe right / left | Keep / stage for trash |
| Two fingers up | Open the shelf, slide across, let go to file |
| Drag back down | Close the shelf without filing |
| Double-click | Open the file |
| Right-click | Reveal in Finder, rename, copy name |

## Installing

No notarized build yet, so macOS will refuse to open it on first launch. Build
it yourself (below), or if you were sent a build: try to open it once, then go
to **System Settings → Privacy & Security** and click **Open Anyway**.

## Building

Requires Xcode 16+ and macOS 14+.

```bash
open DClutter.xcodeproj
```

The core logic is a standalone SwiftPM package and its tests run without Xcode:

```bash
swift test --package-path DClutterKit
```

## Architecture

Three modules, with a hard boundary between metadata acquisition and everything
else — so a future port reimplements one protocol rather than the whole app, and
so the logic is testable without a UI.

| Module | Contains | Depends on |
|---|---|---|
| `DClutterCore` | Scoring, the session state machine, file metadata | Foundation only |
| `DClutterPlatform` | Trash, move, rename, destination bookmarks | Core |
| `DClutterUI` | SwiftUI views | Core + Platform |

`DClutterCore` never touches AppKit and never performs a destructive file
operation. It records what should happen and reports back the disk work its
caller must carry out.

### Safety rules

These hold on every commit and are covered by tests:

1. No code path calls `removeItem` on a user file — only `trashItem`.
2. Nothing outside `~/Downloads` or a folder you explicitly chose is touched.
3. Staged files are untouched on disk until you confirm.
4. A move registers its undo before the file is touched, never after.
5. Session state is written after every decision, so quitting loses nothing.

## Status

Pre-release, in active development. Keep, trash, file, rename, undo/redo and
gestures all work; the app is used daily by its author.

Not done yet: notarized distribution, and renaming a destination bin's label.

## License

Apache-2.0. See [LICENSE](LICENSE).
