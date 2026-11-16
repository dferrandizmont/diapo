# Test like a human · Diapo web (site `diapo`, for app 0.1.0+6)

- **Verdict:** PASS
- **Date:** 2026-11-16 · **Commit:** 1cd0cfd (app repo) · **Level:** full (first version of the site)
- **Layer 1 target:** the whole generated site (`web/` → `dist/diapo/`): three languages, language switcher, light/dark toggle, "12 · 24 · 36" block, privacy page, legal notice link, 404, keyboard focus, external links, store buttons, external requests.
- **Build/serve:** `sitegen build diapo` OK, `sitegen check diapo` → `OK`, `sitegen serve diapo` on `http://127.0.0.1:4400/` (python PID 42180, stopped by PID at the end; port free).
- **Browser:** built-in browser pane (Chromium), desktop and 390 px emulation. Not deployed, nothing uploaded.

| Device | Type | Layer 0 | Layer 1 |
|---|---|---|---|
| Browser pane, desktop + 390×844 | web | OK, 0 findings (6 pages × desktop/mobile × light/dark, 404, offline) | OK, see below |

## Failures

| ID | Severity | Where | Summary | Reproduced |
|---|---|---|---|---|
| F1 | minor | `/`, `/ca/`, `/en/` · features list | Feature numbers read 01, 02, 03, 05, 06: the disposable camera (04) is rendered in its own block, so the sequence has a gap. | yes |
| F2 | minor | `/` · 390 px, text at 200 % | "12 · 24 · 36" wraps onto two lines and leaves "36" alone. No overflow, no clipping, page width unchanged. | yes |

## What was checked (layer 1)

- **Languages:** `/` (es), `/ca/`, `/en/`: correct `lang`, `<title>`, H1, canonical, `hreflang` links; the same for the three privacy pages. Clicking the switcher on `/privacy/` goes to `/en/privacy/` (same page, new language, theme kept).
- **Theme toggle:** visible when JS runs (`hidden` attribute otherwise, so it is harmless without JS: the content is static and follows `prefers-color-scheme`). Click switches dark → light (background changes, `aria-pressed` updates), stored in `localStorage` only (no cookies), persists after reload and across pages. Test value cleared at the end.
- **"12 · 24 · 36" at 390 px:** one line, inside its card, no horizontal scroll (document overflow 0). At 200 % text it wraps in two lines (F2) but stays inside the card; no overflow anywhere.
- **Privacy page:** full policy (about 2,100 words per language), version/date line, no HTML comments in any generated page, no TODO/FIXME/internal notes. The table is inside a scroll area; the page itself has no horizontal overflow at 390 px.
- **Legal notice:** footer link present on every page, points to the language-matching `docs/legal/aviso-legal[.ca|.en].md` on GitHub (the files exist in the repo; the link resolves only once the repo is public/pushed with them: not checked online).
- **404:** unknown URL answers 404 with the site's own page ("Página no encontrada · Diapo").
- **Keyboard:** Tab reaches links in order, `:focus-visible` gives a 3 px outline; skip link "Saltar al contenido" present.
- **External links:** GitHub repo, Ko-fi, `mailto:diapo@mainshai.com`, mainshai.com and the legal notice are present.
- **Store buttons:** show "Google Play · Próximamente / Coming soon / Pròximament" and the App Store equivalent; no store logos or images in the download block, no store URLs.
- **External requests:** every resource on home and privacy loads from `127.0.0.1:4400` only; fonts (Chakra Petch, Barlow Semi Condensed, Bowlby One, Space Mono, Caveat) are self-hosted and load; no `url(http…)` in CSS. Lazy images all load after scrolling.

## Coverage

| Page | desktop light | desktop dark | mobile light | mobile dark | layer 1 |
|---|---|---|---|---|---|
| `/`, `/ca/`, `/en/` | OK | OK | OK | OK | OK |
| `/privacy/`, `/ca/privacy/`, `/en/privacy/` | OK | OK | OK | OK | OK (es and en read in detail; ca by structure) |
| 404 | OK | | | | OK |

## Not tested

- Real deployment (Cloudflare headers, `diapo.mainshai.com` HTTPS), the online GitHub links, and the `_headers` file in production.
- Catalan text read for quality (structure and links only); contrast AA measured by eye on the contact sheets, not by tool.
- Slow network and no-JS rendering in a real browser with JS disabled (inferred from the static HTML and the `hidden` toggle).

## User exceptions

- none

Evidence: `qa/0.1.0/evidence/web/` (gitignored via `qa/*/evidence/`; the line was added to `.gitignore`, uncommitted).
