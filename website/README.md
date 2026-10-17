# DClutter website

The app's product website, built with Next.js App Router, TypeScript, Motion,
and ordinary CSS. It lives alongside the native app but builds and deploys
independently. No backend, account service, analytics, or external font requests.

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

`npm run build` exports the static site into `out/`. Deploy that directory to a
static host, or select `website` as the project root in a Next.js hosting service.
The current site assumes deployment at the root of a domain. GitHub Pages under
`/DClutter/` would need a base path and corresponding public-asset paths.

## Content and interactions

- `src/components/landing.tsx`: page content, release/download URLs, sample-file
  demo, and adjustable pace preview.
- `src/app/globals.css`: responsive layout, design tokens, and CSS motion.
- `src/app/layout.tsx`: metadata and the self-hosted Inter variable font.
- `public/triage-layout.png`: actual DClutter 1.1.0 screenshot with sample files.
- `public/logo.png`: the app's existing logo.
- `public/fonts/`: Inter and its OFL license, reused from the teaser's assets.

The hero is an explicitly labeled illustration with sample files, not a running
Mac app. Keep/Stage/File advance the sample queue; Skip rotates it; Undo restores
the preceding decision. Arrow keys and Space work while the demo region itself
has keyboard focus. Left/right dragging also works. The pace preview is opt-in,
pauses offscreen or when the tab is hidden, and supports 0.5–8 files per second.
Motion honors `prefers-reduced-motion`. FAQs use native disclosure elements.

The website does not depend on the ignored `videos/` project or any video file.
