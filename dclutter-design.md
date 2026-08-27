# DClutter — Design System

Native macOS. SwiftUI. This document is the visual spec for `DClutterUI`.

**Provenance:** the *approach* here is adapted from an editorial-restraint web system
(monumental tight type, flat surfaces, mono technical labels, media-led color). None of
its actual assets are used: no `CohereText`, `Unica77`, or `CohereMono` — those are
licensed typefaces belonging to another company — and none of its brand colors. Every
value below is independently chosen for this app.

---

## 0. The one design problem

Every other decision follows from this: **the preview is different on every single card.**
A PDF, then a photo, then a folder icon, then a zip. Wildly inconsistent content, one
frame.

Most apps design *around* consistent content. DClutter can't. So:

- **The frame carries the identity, because the content can't.** A screenshot should be
  recognizably DClutter from the card shape and the label treatment alone.
- **The UI never competes with the preview for color.** Color arrives through the file's
  own thumbnail. Everything else stays achromatic. This is not timidity — it's the only
  way a UI stays coherent when a neon album cover and a white PDF page appear back to back.
- **Metadata is the second content type**, and it's always text. It gets a deliberate
  voice of its own rather than being small grey afterthought labels.

---

## 1. Typography

### Faces

| Role | Face | Why |
|---|---|---|
| Filename | SF Pro Display, tight tracking | The one large piece of type on screen |
| Metadata labels | **SF Mono, uppercase, wide tracking** | The signature move — see below |
| Metadata values | SF Pro Text | Reads cleanly at small sizes |
| Chips | SF Pro Text, medium | Compact, legible in a pill |

All three ship with macOS. No bundling, no licensing, no font loading, and they render
correctly at every size and weight because Apple optically sized them.

### The signature move: mono uppercase labels

This is the thing worth stealing, and it does real work here rather than decorative work.

```
SIZE          8.2 MB
LAST OPENED   Never
FROM          canvas.ateneo.edu
ADDED         14 Mar 2026
```

Uppercase SF Mono at 11pt with +0.5pt tracking, in tertiary grey, against SF Pro Text
values in primary. It reads as instrumentation — a readout, not a form. That's exactly
right for an app whose entire job is presenting file forensics for a snap judgement.

It also solves a layout problem for free: monospaced labels align on a natural column
without a `Grid` or manual widths.

### Scale

Utility app, single window. There is no 96pt headline here; the source system's scale
does not transfer at all — only its *treatment* does.

| Token | Face | Size | Weight | Tracking | Use |
|---|---|---:|---|---:|---|
| `filename` | SF Pro Display | 22 | Regular | −0.4 | The file's name on the card |
| `filenameLong` | SF Pro Display | 17 | Regular | −0.2 | Fallback when the name is long |
| `metaLabel` | SF Mono | 11 | Regular | +0.5, UPPERCASE | `SIZE`, `FROM`, `LAST OPENED` |
| `metaValue` | SF Pro Text | 13 | Regular | 0 | The values beside them |
| `chip` | SF Pro Text | 11 | Medium | +0.1 | Flag pills |
| `count` | SF Mono | 13 | Regular | +0.3 | "142 of 771" — see §5 |
| `sheetTitle` | SF Pro Display | 17 | Semibold | 0 | Commit sheet only |

**Avoid bold.** Hierarchy comes from size, case, tracking, and color. Semibold appears
exactly once, in the commit sheet title, because that screen genuinely needs a raised
voice.

**Negative tracking on the filename** is what keeps it from looking like a system alert.
Tight display type reads as considered; default tracking reads as untouched.

---

## 2. Color

### Use semantic colors, not hex values

macOS needs light mode, dark mode, increased contrast, and the user's accent color. A
fixed palette breaks all four. So the base is semantic:

| Token | Source | Use |
|---|---|---|
| `surface` | `.windowBackgroundColor` | Window |
| `cardSurface` | `.controlBackgroundColor` | The card |
| `hairline` | `.separatorColor` | Every border |
| `textPrimary` | `.labelColor` | Filename, values |
| `textSecondary` | `.secondaryLabelColor` | Supporting text |
| `textTertiary` | `.tertiaryLabelColor` | Mono labels |

These adapt automatically. Hardcoding `#212121` would look correct in light mode and
wrong in dark, which is where most people will actually use this.

### The accent, singular

**One warm accent. Used only for the trash affordance and destructive confirmation.**

```swift
// Warm amber-red. Reads as "consequential" without the alarm-state
// connotation of pure red, which would be wrong for an action that is
// staged, reversible, and expected dozens of times per session.
static let consequence = Color(
    light: Color(red: 0.79, green: 0.31, blue: 0.16),
    dark:  Color(red: 0.93, green: 0.48, blue: 0.31)
)
```

Deliberately **not** red/green for trash/keep. Three reasons: red-green is the most
common color blindness; green-for-keep implies approval when keeping is just the null
action; and a session is ~80% trash, so a screen constantly flashing alarm-red is
exhausting. Keep is silent. Trash is warm. Move is neutral.

### Everything else stays achromatic

Chips are grey. Bins are grey. Borders are grey. The only color in the window comes
from the preview and the one accent. When a card shows a bright screenshot, the UI
must not fight it.

---

## 3. Shape and depth

**Flat. No drop shadows anywhere.** Depth comes from surface alternation and hairlines.
Shadows on a card this large read as heavy and dated, and they're the first tell of a
default-styled SwiftUI app.

| Token | Radius | Use |
|---|---:|---|
| `chip` | 6 | Flag pills |
| `preview` | 10 | Inset preview well |
| `card` | 20 | **The card** — the signature radius |
| `bin` | 14 | Destination bins |
| `sheet` | 12 | Commit sheet |

**20pt on the card is load-bearing.** It's large enough to read as a deliberate object
rather than a rounded rectangle, and it's the single most recognizable thing in a
screenshot. Do not reduce it toward the system default.

**The preview is inset within the card**, in a well with its own 10pt radius and a
hairline border — never bleeding to the card's edge. This is what makes arbitrary
content look intentional: the frame is always the same even when the contents are a
1:3 portrait scan or a 16:9 video poster. Letterbox with `cardSurface`, never with
black.

---

## 4. Layout

Base unit 4. Steps: 4, 8, 12, 16, 24, 32, 48.

```
┌─────────────────────────────────────┐
│  [ destination bins, hidden ]       │  slides in on drag (M4)
├─────────────────────────────────────┤
│                                     │
│    ╭───────────────────────────╮    │
│    │  ┌─────────────────────┐  │    │  preview well
│    │  │                     │  │    │  10pt radius, hairline
│    │  │      QuickLook      │  │    │  fixed aspect box
│    │  │                     │  │    │
│    │  └─────────────────────┘  │    │
│    │                           │    │
│    │  Enriquez_ProblemSet3.pdf │    │  filename, 22pt, tight
│    │                           │    │
│    │  ⟨3 copies⟩ ⟨never opened⟩│    │  chips
│    │                           │    │
│    │  SIZE         842 KB      │    │  mono label / value rows
│    │  LAST OPENED  Never       │    │
│    │  FROM         canvas.…    │    │
│    ╰───────────────────────────╯    │  20pt radius, hairline, flat
│                                     │
│  142 of 771                     ⌘⏎  │  mono counter, keyboard hint
└─────────────────────────────────────┘
```

- Card is centered with generous margin — at least 48 on each side at default window
  size. The emptiness is the point: one decision at a time, nothing else asking for
  attention.
- Preview well has a **fixed aspect box**, not intrinsic sizing. Cards must not resize
  between files or the whole queue jitters as you swipe. Fit content inside; never
  crop.
- Window minimum 520×640. Below that the card stops being a card.

---

## 5. Chips

Flag chips are the mechanism §4 of the plan asked for — surfacing "never opened" and
duplicate status prominently rather than burying them in the score.

```
⟨3 copies⟩        duplicate cluster member
⟨never opened⟩    downloaded, no last-used date
⟨already extracted⟩  archive whose folder sits beside it
```

Grey fill at ~8% `labelColor`, no border, 6pt radius, 11pt medium, 6pt/3pt padding.
Maximum three, wrapping to a second row only if necessary. **No icons** — the words are
short and unambiguous, and glyphs would add visual noise the preview is already
supplying.

Chips never use the accent. They're information, not warnings.

## 6. The counter

Per §0 of the plan, progress is measured in **items, not bytes**. The counter renders in
SF Mono precisely because it changes on every card — monospaced digits don't shift
horizontally as numbers change width, so it sits still instead of twitching through the
session. Small detail, constantly visible.

Never display reclaimed bytes. Anywhere.

---

## 7. Motion

One well-judged transition beats many small ones.

- **Card advance:** outgoing card translates in the decision's direction and fades over
  ~180ms; incoming card rises 12pt and fades in over ~200ms, offset ~40ms. Fast enough
  to hold a rhythm at speed, present enough to confirm the decision registered.
- **Chips and metadata** do not animate independently. The card moves as one object.
- **Destination shelf (M4):** driven by drag position, not triggered by threshold. Bins
  translate and gain opacity in proportion to the drag. This is the difference between
  a gesture that feels physical and one that feels like a menu.
- **Respect `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`** — replace
  translation with a plain crossfade.

No spring overshoot. Bouncy easing reads as playful; this app is quick and quiet.

---

## 8. What this must never look like

- Drop-shadowed cards on a grey background — the default SwiftUI look
- Red and green decision buttons
- Bold weights doing the work of hierarchy
- A progress bar of bytes reclaimed
- Icons beside every metadata row
- The preview bleeding to the card edge
- Gradients of any kind
