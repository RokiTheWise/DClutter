# M3 — Dogfood friction log

**The rule (plan §8): write it down, don't fix it.** Every genuinely good
utility comes from the author being irritated by their own app for a week.
The point of logging rather than fixing is that the annoyances which survive
a week are a different, much shorter list than the ones that feel urgent in
the first ten minutes — and the difference is the whole value of M3.

Fix only what still annoys you at the end. Resist the urge to fix mid-week;
a fix you make on day 1 is a fix you never got to evaluate.

**Started:** 2026-08-27 (M2 merged as `44a9b54`)
**Ends:** run it every day for a week, then triage this list.

Run it from `/Applications/DClutter.app` (Release build installed 2026-08-27).
Rebuild and reinstall after any change:

```bash
xcodebuild -project DClutter.xcodeproj -scheme DClutter -configuration Release -destination 'platform=macOS' build \
  && rm -rf /Applications/DClutter.app \
  && cp -R ~/Library/Developer/Xcode/DerivedData/DClutter-*/Build/Products/Release/DClutter.app /Applications/
```

Reset the session (discard all decisions, keep files untouched):

```bash
rm -rf ~/Library/Containers/dev.djenriquez.DClutter/Data/Library/Application\ Support/DClutter
```

---

## How to log

One line per friction point, as it happens. Don't polish. What matters is
whether the same thing shows up on three different days.

```
| Date | What happened | How much it actually mattered |
```

Rate the last column honestly: **blocked** (had to stop / work around it),
**annoyed** (noticed it, kept going), **noticed** (mildly imperfect).
Most things are "noticed" and most "noticed" items should never be built.

---

## Log

| Date | What happened | Mattered |
|---|---|---|
| | | |

---

## Carried in from the first M2 run (2026-08-27)

Raised within the first ~15 minutes of use, before the dogfood week began.
**These have not earned a fix yet** — they are here so they aren't lost, not
because they're approved. Re-rate each one at the end of the week; anything
that never came up again during real use is a candidate to drop, not build.

| Item | Note | Re-rated after the week? |
|---|---|---|
| Mouse/trackpad-only controls (undo, redo, commit, quit) | The app is close to unusable without the keyboard. §2 principle 5 says keyboard *wins* where they conflict — not that pointer users get nothing. Strongest case of the four. | |
| Redo (⇧⌘Z — not ⌘Y, which is the Windows binding) | Cheap now that `history` exists; becomes an undo/redo stack pair. | |
| Cancel all / reset the session from inside the app | Today it needs deleting JSON by hand. Must never touch already-trashed files (`.trashed` is terminal in `FileState`). | |
| Click a card to open the file | For when preview + metadata aren't enough. May be redundant with ↑ (focus live preview) — a week of use is exactly what settles that. | |

## Known unresolved bug

- **↑ on a `.docx` shows a QuickLook spinner that never resolves.** Thumbnails
  for the same file types are fine (they fall back to the file-type icon).
  Suspected sandbox interaction with `QLPreviewView`. Not investigated. This
  is a *bug*, not a friction point — it can be fixed during the week without
  violating the M3 rule.

## Deferred from code review (not user-facing)

Real but harmless; listed so the week's triage can weigh them alongside
anything the log turns up.

- `SessionSnapshot.queueOrder` is written on every persist but never read back
  during reconciliation — dead data. Becomes useful if skip-ordering should
  survive a relaunch.
- `deferred` entries for trashed files are never pruned — unbounded growth
  across a long session, no behavioural effect.
- `persist()` swallows encode/write failures with `try?`, so the
  persist-after-every-decision invariant can stop holding silently.
- `commitError` keeps only the last failure's message when several files fail
  in one commit.
- Session state falls back to `temporaryDirectory` if Application Support is
  unavailable — the OS may wipe it.
- `QueueContext` is built once at load, so a "3 copies" chip still says 3
  after two of the three are trashed.
