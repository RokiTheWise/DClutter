# DClutter website

The app's product website, built with Next.js App Router, TypeScript, Motion,
and ordinary CSS. It lives alongside the native app but builds and deploys
independently. No backend, account service, analytics, or external font requests
at runtime.

## Develop

Requires Node.js 20.9 or newer.

```sh
cd website
npm ci
npm run dev
```

Open the URL printed by Next.js. To use a different port:

```sh
npm run dev -- --port 3020
```

## Check and build

```sh
npm run typecheck
npm run build
```

Type checking generates Next.js route types first, so it also works before the
first development run or build. The Website GitHub Actions workflow runs both
checks for website pull requests; it does not deploy the site.

`npm run build` exports the static site into `out/`. Deploy that directory to a
static host, or select `website` as the project root in a Next.js hosting service.
The current site assumes deployment at the root of a domain. GitHub Pages under
`/DClutter/` would need a base path and corresponding public-asset paths.

## Design

The page is one continuous scroll from pale sky to near-black. Five muted
colors carry it, declared as tokens in `globals.css`:

| Token     | Value     | Where it lands            |
| --------- | --------- | ------------------------- |
| `--ink`   | `#020204` | type, buttons, the window |
| `--sand`  | `#f7e9d0` | hero floor, the pile      |
| `--sage`  | `#e0eddf` | four decisions            |
| `--sky`   | `#e0edf6` | hero sky, privacy         |
| `--blush` | `#edd6d9` | undo                      |

One tint owns each band and the bands meet on arcs rather than straight edges,
so one color rolls into the next. Ink is the only strong value on the page,
and there is no accent color. Display type is Merriweather; body text and controls
use Poppins. Both fonts are self-hosted through Next.js.

## Structure

- `src/components/landing.tsx`: composes the seven bands.
- `src/components/site-nav.tsx`: the bar that contracts into a pill on scroll,
  plus the download pill that follows you down the page.
- `src/components/hero.tsx`: parallaxing ridges, masked headline lines, and the
  product window rising out of a frosted tray.
- `src/components/hero-demo.tsx`: an automatic sample session: stage, keep,
  rename, file, review trash, and move to Trash, then reset to the first file.
  The roughly ten-second loop uses fictional lecture notes, an invoice, and a
  research proposal, with local document previews in `public/demo/`. Filing
  dismisses the destination shelf as the card exits upward.
  Playback pauses offscreen or in a hidden tab, with autoplay disabled for
  reduced-motion preferences. Only the app window is visible; there are no
  captions or playback controls.
  Its native UI was checked in the installed app with disposable sample files:
  system type, two-column metadata, inline rename footer, top destination shelf,
  and the modal trash checklist. The website fonts apply outside this window.
- `src/components/pile.tsx`: scattered files that sort into a deck. Scrubbed to
  scroll position, so scrolling back un-sorts it.
- `src/components/decisions.tsx`: an accordion gallery of the four actions,
  inspired by the React Bits expanding-panel pattern. Desktop uses vertical
  action rails beside one large live preview; mobile stacks accordion rows.
  Peach, lavender, blue, and sage tints distinguish the actions. The title and
  gallery share a frame sized to the laptop viewport. Panel expansion uses
  a 0.6-second power3.out curve, an 8-degree tilt on closed rails, and a
  0.06-second content stagger. The active panel takes 72% of the gallery.
  Fine-pointer hover on desktop, click/tap, focus, arrow keys, Home, and End
  select a panel. Hover follows actual pointer movement so resizing panels
  cannot override keyboard selection. Native app content
  keeps a fixed width during expansion to avoid text reflow, then scales
  uniformly to fit the available width and height via ResizeObserver. Only the open
  panel plays; closed previews reset and are inert and hidden from assistive
  technology. `decision-preview.tsx` loops each action, including directional
  exits, incoming files, synchronized counters, and the destination shelf.
  Autoplay pauses offscreen/in hidden tabs and respects reduced motion.
  The section reserves clearance above the following band's raised arc.
- `src/components/triage-demo.tsx`: the interactive demo.
- `src/components/privacy.tsx`, `undo-section.tsx`, `site-end.tsx`: the closing
  bands.
- `src/components/file-card.tsx`, `window-chrome.tsx`: shared product chrome.
- `src/lib/samples.ts`: sample files, the four decisions with their key
  bindings, and each decision's exit vector.
- `src/lib/card-motion.ts`: the card enter/exit variants.
- `src/lib/platforms.ts`: release versions, download URLs, requirements, and
  repository links for both platforms.
- `src/app/globals.css`: tokens, base styles, and every band's layout.
- `src/app/layout.tsx`: metadata and both fonts.
- `public/logo.png`, `public/fonts/`: the app logo, and Inter with its OFL
  license.

## Interactions

The platform download links in the hero and footer start the download and open
a native modal with platform-specific installation steps. Mac has four stages:
open the DMG and drag the app to Applications, eject the image and dismiss
the warning with Done, choose Open Anyway in Privacy & Security, and confirm
Open Anyway in the final dialog.
Windows has three steps.
Release attachments target a hidden frame, keeping the current page visible
instead of opening an empty tab during the download handoff.
All four Mac panels use supplied light-mode screenshots in `public/install/`,
with highlights on the relevant buttons. Windows uses focused HTML/CSS illustrations.
A “Download again” link retries the same release asset. Escape, the close button, or
clicking the backdrop dismisses it; keyboard focus returns to the trigger.

The separate “Try it” demo is interactive. Keep, Stage and File advance the
sample queue; Skip rotates it to the back; `Z` undoes the previous decision, and
Start over resets the run. Arrow keys and Space work while the demo region has
keyboard focus. The handler is bound to the demo rather than the document, so
the page keeps normal arrow-key scrolling everywhere else.

Both product windows use the native app's light appearance via `win--light`:
white file cards and folder shelves, gray controls, orange trash actions, and
blue checklist selections and focus rings. The theme is scoped to the preview
windows, including rename and trash review, independently of the page palette.

A card's exit direction is only known once the decision is made, so it arrives
through `AnimatePresence`'s `custom` at exit time. That requires a *function
variant*; an inline `exit={...}` object resolves too early to carry it. The same
mechanism drives the decisions section, including when alternating between Keep
and Stage.

The four decisions section can also be driven by hover, click or focus rather
than scroll.

Motion honors `prefers-reduced-motion` throughout: the tints and the layout
stay, the movement stops.

The website does not depend on the ignored `videos/` project or any video file.

## Releases

Mac v1.1.0 links to the published DMG, with its drag-to-Applications window.
The original ZIP remains available on GitHub. Both packages contain the same app;
adding a disk image does not change the app version or signing status.

Both platforms are described by `src/lib/platforms.ts`, which is the only
place a version, a download URL or a minimum OS appears. The download
buttons, the release blocks and the footer all read from it.

Windows [v1.0.0](https://github.com/RokiTheWise/DClutter-Windows/releases/tag/v1.0.0)
is published for Windows 10 and 11 (x64). The website links directly to
`DClutter_1.0.0_x64-setup.exe`; an MSI is also available on the release page.
The Windows installation modal follows the repository’s setup instructions,
including the SmartScreen prompt and installation without administrator rights.

To take Windows off the site, set its `status` back to `"development"`. The
release block then reads "In development" and the button disappears.

To update either platform, change `version`, `downloadUrl`, `requirements`,
`architecture` and `releaseNotesUrl` in its record, then run `npm run
typecheck` and `npm run build`. The discriminated release type will not let an
`"available"` record through without all of them.
