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
so one color rolls into the next. Ink is the only strong value on the page —
there is no accent color. Display type is Instrument Serif; everything else is
the self-hosted Inter.

## Structure

- `src/components/landing.tsx`: composes the seven bands.
- `src/components/site-nav.tsx`: the bar that contracts into a pill on scroll,
  plus the download pill that follows you down the page.
- `src/components/hero.tsx`: parallaxing ridges, masked headline lines, and the
  product window rising out of a frosted tray.
- `src/components/pile.tsx`: scattered files that sort into a deck. Scrubbed to
  scroll position, so scrolling back un-sorts it.
- `src/components/decisions.tsx`: the sticky four-decision column and the card
  that leaves in the matching direction.
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

The demo is the real interaction, not a video. Keep, Stage and File advance the
sample queue; Skip rotates it to the back; `Z` undoes the previous decision, and
Start over resets the run. Arrow keys and Space work while the demo region has
keyboard focus — the handler is bound to the demo, not the document, so the page
keeps normal arrow-key scrolling everywhere else.

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

## Publishing a Windows release

Windows currently has no download and links to
https://github.com/RokiTheWise/DClutter-Windows. No installer, version, minimum
OS, or release date is implied.

When the Windows build is ready, update its record in `src/lib/platforms.ts`:

1. Set `status` to `"available"`.
2. Supply `version`, `downloadUrl`, `requirements`, `architecture`, and
   `releaseNotesUrl` with confirmed release information.
3. Run `npm run typecheck` and `npm run build` before deployment.

The discriminated release type requires a complete release record before an
enabled download is rendered. The hero's requirement line, the download band and
its fact row all read from that same configuration.
