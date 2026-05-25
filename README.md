# Bricolage Sky

A custom Hugo theme for [bricolage.micro.blog](https://bricolage.micro.blog/).

Built from a clickable HTML prototype (see `../../design_reference/`). The visual direction is **Sky** — typography-first, an iridescent gradient hairline as the only chromatic flourish, a "pigeon" palette in light + dark.

## What's here

- **Layouts** for the home page (pinned long-form + microposts feed), category archives (Games, Pigeons, Microposts, Longform), and the built-in micro.blog `/photos/` + `/books/` pages.
- **CSS variables** for both the color palette and the type system. A `data-theme` attribute switches light/dark; a `data-fonts` attribute swaps DM Serif Display + Spectral + JetBrains Mono for Atkinson Hyperlegible Next + Atkinson Mono.
- **Data files** in `data/` (`games.yml`, `pigeons.yml`, `now.yml`) — the home page "Now" panel and the Games / Pigeons journal headers read from these so editing your status doesn't require editing templates.

## How it maps to micro.blog

| Page on the site | Template | Source of content |
|---|---|---|
| `/` | `layouts/index.html` | Latest **Longform** post pinned at top, then paginated microposts |
| `/photos/` | `layouts/section/photos.html` | Built-in micro.blog photo posts |
| `/books/` | `layouts/section/books.html` | Built-in micro.blog Bookshelves |
| `/categories/games/` | `layouts/taxonomy/category.html` (Games branch) | Data file `games.yml` + posts tagged `games` |
| `/categories/pigeons/` | `layouts/taxonomy/category.html` (Pigeons branch) | Data file `pigeons.yml` + posts tagged `pigeons` |
| `/categories/longform/` | `layouts/taxonomy/category.html` (default branch) | Posts tagged `longform` |
| Single post | `layouts/_default/single.html` | Any post |
| About, Archive, etc | `layouts/_default/single.html` | Built-in micro.blog pages |

## Install

```bash
git clone <this repo> themes/bricolage-sky
```

Then in `config.json` (or whatever your micro.blog plug-in config uses):

```json
{ "theme": "bricolage-sky" }
```

## Tweaking

- **Palette**: edit the `--paper / --ink / --iri-*` tokens at the top of `static/css/bricolage.css`.
- **Type**: by default loads both Editorial (DM Serif + Spectral + JetBrains Mono) and Hyperlegible (Atkinson) stacks. Switch the default via `<html data-fonts="hyperlegible">` in `layouts/_default/baseof.html` or add a user toggle.
- **Dark mode**: `<html data-theme="dark">`. Respects `prefers-color-scheme` automatically; an inline script in `partials/head.html` honors a `localStorage["theme"]` override.

## File map

```
layouts/
├── _default/
│   ├── baseof.html         base template (html shell + header + footer)
│   ├── list.html           generic section/list fallback
│   ├── single.html         single post / page
│   └── term.html           generic taxonomy term fallback
├── index.html              home page (pinned + microposts)
├── partials/
│   ├── head.html           <head> contents — fonts, CSS, theme bootstrap
│   ├── header.html         iridescent top bar + nav
│   ├── sidebar.html        left column: about, tags, archive
│   ├── now.html            right column: now-reading / playing / watching
│   ├── post-card.html      single short-post card
│   ├── page-header.html    section page H1 with iri rule
│   └── footer.html
├── section/
│   ├── photos.html         featured photo + grid
│   └── books.html          currently reading + finished
└── taxonomy/
    └── category.html       smart router — pigeons / games / default
static/css/bricolage.css    all styles, ~6 KB un-gzipped
data/
├── games.yml               { now_playing, backlog, finished }
├── pigeons.yml             named pigeons + notes
└── now.yml                 reading / playing / watching
```

## Notes for the implementer

- The HTML prototype lives in `../../design_reference/index.html`. Open it locally to see the intended look and the dark/type toggles. The Sky direction is the third artboard.
- I built the prototype with React + inline JSX so I could prototype interactions quickly. **Do not port the React code into the theme** — the theme is plain Hugo templates + CSS, which is what micro.blog needs. The prototype is a visual spec.
- micro.blog injects some HTML of its own (conversations, replies UI, reply boxes). If you want those, the safest pattern is to start from the official `theme-tiny-theme` or `theme-marfa` and overlay these layouts + CSS on top, rather than ship a fully-standalone theme.
- All CSS is in `static/css/bricolage.css` (no Hugo Pipes / SCSS) so it survives any micro.blog build pipeline.
