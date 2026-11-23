# Task List — mysite-3.0

**Status:** Phase 3 complete (13/13 incl. owner pass 3.13, QA 10/10). **Phase 4 executing (2026-11-22):** safe half DONE — versioning ON, both CloudFront dists configured (headers+404) and apex origin repointed to the 3.0 bucket, 2.0 archive built. **Cutover (deploy.sh) NOT run — waiting on owner's word.** Architecture changed mid-run: the apex alias can't move (CNAMEAlreadyExists) so the cutover is now a **content swap with zero DNS change**; `dns-flip.sh` deleted, rollback via `rollback.sh` (S3 versioning manifest). Default mode: A (no 301, canonical tags). To finish: `./deploy/cutover.sh` (resumable) or `DEPLOY_IS_CUTOVER=1 ./deploy/deploy.sh` + `./deploy/verify-live.sh`
**Conventions:** each task names its owner persona; phases are ordered by dependency; check boxes off as things land. Decisions live in `docs/HOSTING.md` (D1–D11) and `docs/DESIGN.md` — this file tracks *work*, not *decisions*.

---

## Phase 1 — Foundations (no stack required, can start immediately)

- [x] **1.1 Design system v1** — `art-director`: finalize `docs/DESIGN.md`. Palette + self-hosted typeface, type scale, spacing scale, dark-mode tokens, page layout rules, motion rules (default: none), and the concrete pattern for "curated + expandable projects." ✅ 2026-11-21 — warm paper + rust accent, self-hosted Manrope variable, 6-size type / 9-step spacing scales, row-based lists, native `<details>` archive, zero JS / zero images in v1, ~150 KB per page.
- [x] **1.2 Content skeleton** — `editor`: create `content/` with conventions doc. Hero line, about, experience entries, projects (featured set + archive), blog index. Mine 2.0 for facts; `<!-- VERIFY -->` comments on anything uncertain. ✅ 2026-11-21 — 11 files, 8 experience entries, 3 featured + 2 archive, 9 VERIFY comments outstanding.
- [x] **1.3 Migrate matrix-calculus series** — `editor`: re-port the 3 posts as markdown with KaTeX math. Content first, no visual/image parity with 2.0 (D11). ✅ 2026-11-21 — 44 display-math blocks verified 1:1; 5 math errors from 2.0 corrected in the port.
- [x] **1.4 Owner review pass** — owner: review design tokens + all copy, resolve VERIFY comments, approve project curation (featured list + order). ✅ 2026-11-21 — hero links: Résumé · GitHub · Blog; featured = 3 (Hearts, MathSearch, ProjectX); Mountain View + "back since 2024" + Hearts 2025 confirmed; twitter/instagram dropped; "second part" promise cut; 5→6 math-correction VERIFYs kept as provenance NOTES.

## Phase 2 — Scaffolding (the parked stack decision un-parks here)

- [x] **2.1 Pick the SSG stack** — owner + `builder`: must satisfy HOSTING D3/D11/§10 — multi-page static output, real URLs, no SPA, near-zero runtime JS, build-time KaTeX, `dev`/`build`/`preview` scripts. ✅ 2026-11-21 — **Astro 7** (D12) + **build-time KaTeX** (D11, chosen over LaTeX→SVG / MathJax-static).
- [x] **2.2 Project scaffold** — `builder`: init project, layout shell (nav + footer), all routes (`/`, `/about`, `/experience`, `/projects`, `/blog`, `/blog/<slug>`, 404), and working `dev` / `build` / `preview` per HOSTING §10. ✅ 2026-11-21 — Astro 7.4 at repo root; all 9 routes build; **zero `<script>` tags** in output; copy wired from `content/` via content collections (single source of truth, nothing duplicated). KaTeX: `remark-math` + `rehype-katex` (html output) at build time — `@astrojs/katex` does not exist in the npm registry, so the equivalent pipeline is direct. Post-build finalizer (`scripts/finalize-katex.mjs`, needs `pip install fonttools`) subsets KaTeX faces to the glyphs the posts actually use, trims the CSS, content-hashes to `dist/_astro/`. Dev-time KaTeX copy vendored to `public/katex/` (`npm run vendor:katex`, on install; gitignored). Resume PDF copied from 2.0 as `/resume.pdf`.
- [x] **2.3 Design system into code** — `builder`: implement DESIGN.md tokens (typography, color, spacing, dark mode) as the base stylesheet every page inherits. ✅ 2026-11-21 — every §3–§7 token in `src/styles/global.css` as custom properties (warm-paper/rust light + dark palettes, 6-size type scale, 9-step spacing, 3 radii, hairline row pattern, link/`<details>`/focus states, dark mode via `prefers-color-scheme` + `color-scheme` meta). Manrope variable WOFF2 self-hosted (`latin` 24.4 KB + `latin-ext` 15.2 KB, `font-display:swap`, wght 200–800 axis verified); system mono for code. Math gets `role="img"` + TeX `aria-label` (html-only KaTeX output ships no MathML/alt).

## Phase 3 — Pages (pattern per page: `builder` implements → `visual-tester` checks responsive/dark/readability → owner looks)

- [x] **3.1 Home / hero** ✅ 2026-11-21
- [x] **3.2 About** ✅ 2026-11-21
- [x] **3.3 Experience** ✅ 2026-11-21 — lead line added (owner review: copy is orchestrator-drafted)
- [x] **3.4 Projects** (featured set + expandable archive) ✅ 2026-11-21 — lead line added; `<details>` archive click+keyboard verified
- [x] **3.5 Blog index + post template** (KaTeX rendered at build time) ✅ 2026-11-21 — lead line added
- [x] **3.6 Render the three migrated posts** ✅ 2026-11-21 — 44 display eqs render, no overflow at 360 px
- [x] **3.7 404 page** ✅ 2026-11-21 — noindex, centered, single filled button
- [x] **3.8 Finishing pass** — meta tags, favicon, robots.txt, manifest, footer link to `/old/` ✅ 2026-11-21 — canonical per page, theme-aware SVG favicon, robots allow-all, minimal manifest, `/old/` footer link

- [x] **3.9 Home: portrait + short bio** — owner request (2026-11-21): 2.0's `picture3.jpg` at native 1000 px (154 KB; re-exported after an earlier 320 px downscale blurred when enlarged), rounded-square 40 px radius, left of name/role/bio in an even 50/50 hero (home container 928 px), 2-sentence bio (orchestrator-drafted, pending owner review) ✅
- [x] **3.10 Transfer the 2.0 logo** — owner request (2026-11-21): `monogram.svg` in the nav (24 px beside the text wordmark) + favicon (tightened viewBox) ✅
- [x] **3.11 Color scheme** — owner found warm paper/rust "a little too warm"; chose **A: cool paper + ink blue** (2026-11-21). Tokens swapped in global.css + DESIGN §1; all 12 contrast pairs re-verified ≥4.5:1 (AA). ✅
- [x] **3.12 Theme toggle + mobile hamburger** — owner request (2026-11-21): nav theme toggle (light↔dark, `localStorage`-persisted, pre-paint restore, OS-preference fallback) + hamburger menu ≤ 640 px (real `<button>`, `aria-expanded`/`aria-controls`, closes on link click / Escape / outside click). The site's first and only JS: `src/scripts/ui.ts` (~1 KB, vanilla) + a ~200 B inline snippet. DESIGN §4/§8/§9/§10 amended (the v1 "no JS toggle" / "no hamburger" rules were superseded). QA (visual-tester, headless Chromium/CDP, real events): theme toggle pass (default no-flash, flip, icon swap, persistence, pre-paint restore); hamburger pass after one fix — base `.nav-links` rule was after the mobile media query and won the cascade (links visible in closed state), moved above it (`6c03a31`); re-check 7/7: closed `display:none`, open panel centered (0.01 px), closes on link/Escape/outside, desktop + toggle regressions clean. ✅

**Visual QA (2026-11-21, 36 runs: 9 pages × 2 viewports × 2 schemes):** all pass. Fixes folded in: D-1 leads, m-3 measure 576→640 px (gutter outside content width); spec amendments: m-4 3-line nav wrap at 360 px (2 lines geometrically impossible; superseded by the 3.12 hamburger), m-5/m-6 owner-approved copy wins (bullets, 1–3 line descriptions), D-2 §10 budgets measured on the wire (math pages exempt from the raw-HTML line; wire worst case 96 KB). m-7 (KaTeX CSS on all pages) was a QA false positive — it's scoped to the 3 posts.

## Phase 4 — Infra & cutover (all `ops`, follows HOSTING §6)

**Owner go-ahead: 2026-11-21.** Live state re-verified same day: both dists Deployed; ACM cert `43e7d0e9` (us-east-1) already covers `alexander-wang.net` + `*.alexander-wang.net`; no versioning on either bucket; apex A → legacy `d30bl45vk665e7` (Z2FDTNDATAQYW2), www A → `d1oevywpg7h4uc`.

**301 mechanism — cost question resolved (owner, 2026-11-21):** A is cheaper — strictly $0 (alias only, no new billable resource); B is ~$0 only inside the Lambda free tier (1M req + 400k GB-s/mo) and is a runtime exception against D9. Scripts default to **A** (both hostnames 200 + canonical tags); `WWW_MODE=redirect` keeps B one env var away. **Owner directive: all scripts written, nothing run — DNS flip explicitly not yet.**

**Architecture pivot (2026-11-22, found during execution):** the apex CNAME already sits on the legacy dist `E96YWX7J3SY11` and CloudFront rejects the same CNAME on two dists (`CNAMEAlreadyExists`) — the planned "add apex alias to the main dist" is impossible without a 1–2 h downtime window. New design (D1 amended, HOSTING §3/§6): **repoint the legacy dist's origin to the 3.0 bucket** (new OAI `EP45V9TDLIFAG` + bucket-policy grant); the cutover becomes a **content swap** (deploy + invalidate both edges) with **zero DNS change**. `dns-flip.sh` deleted; `rollback.sh` added (restores the pre-deploy bucket state from the S3-versioning manifest); the legacy dist now STAYS (it serves the apex) — decommission deletes only the orphaned 2.0 bucket.

- [x] **4.1** `deploy/deploy.sh` — CI-ready: non-interactive, idempotent, meaningful exit codes (10–50); build → archive staging → **version snapshot (rollback manifest)** → `s3 sync --delete` (bucket = exact mirror of dist) → two-tier header passes (self-copy: no-cache entry files / immutable hashed assets) → invalidate `/*` on **both** dists + wait for Completed → edge verify of **both** hostnames (status, cache, content-type, 404, `/old/`, security headers); `DEPLOY_IS_CUTOVER=1` stamps `deploy/.cutover-at`. Rewritten 2026-11-22 for the two-distribution design.
- [x] **4.2** CloudFront config — ✅ **RUN 2026-11-22:** `deploy/cfn-configure.sh` — response-headers policy `8ff123cd-…` (HSTS/nosniff/referrer as *structured* security headers — CLI v2.34 quirks hit + fixed), 404 → `/404.html` custom error response on both dists, apex dist origin **repointed** to the 3.0 bucket (OAI `EP45V9TDLIFAG`). Both dists Deployed. Idempotent (re-run safe).
- [x] **4.3** S3 versioning — ✅ **RUN 2026-11-22:** versioning **Enabled** on `www.alexander-wang.net`.
- [x] **4.4** 2.0 archive — ✅ **RUN 2026-11-22:** `old-archive/` built (34 MB, 99 files, 6 deep-link fallbacks, hero video included; 2.0 source tree left clean).
- [~] **4.5** Cutover + verification — **NOT run (owner's word):** `deploy.sh` (the content swap) + `verify-live.sh` (9 checks: 3.0 on apex, headers, 404, canonical, www mode, `/old/`, `/old/blog/`, direct-S3 403) via `deploy/cutover.sh` (gated, `--dry-run`, resumable). Rollback: `rollback.sh`.
- [~] **4.6** Decommission — **scripted, not run:** `deploy/decommission.sh` (soak check vs `deploy/.cutover-at`, default 7 days, type-to-confirm per step; orphaned 2.0 bucket → CircleCI. Legacy dist intentionally kept.)
- [ ] **4.7** *(later, owner's word)* Remove `/old/` and the footer link.

---

### 3.23 — /projects row-link hover underline (2026-11-22, owner)
- [x] "I want the hover effects of the links under projects to be nicer. Currently, there is a gap in the underline between the text and the end bracket." Root cause: `text-decoration: underline` breaks around the inline-block `ext-arrow`, leaving a gap before `]`.
- [x] Fix: the bracketed row links (`.row-alt-links a`) use a 1px `currentColor` background underline at the bottom of the anchor box, drawn in on hover/focus (`background-size: 0% → 100%`, 150 ms) — it spans `[label ↗]` continuously, brackets included. Scoped to /projects; the global link fade is untouched.

### 3.22 — /blog: "Just Be Brave" heading, no lead (2026-11-22, owner)
- [x] Removed the page lead ("Occasional posts on math and machine learning, starting with the matrix calculus series.") — /blog is now h1-only.
- [x] Replaced the "Blog" heading with **"Just Be Brave"** (h1 + `<title>`). The nav keeps the "Blog" label — the owner pointed at the page, not the nav.
- [x] `lead` removed from `content/blog/index.yaml` (comment records the change); `navLabelFor` no longer imported by the page.

### 3.21 — /projects: literal brackets around the links (2026-11-22, owner)
- [x] "I wanted the brackets to surround the links like [GitHub] or [arXiv]" — the brackets are now literal on the page: `Name · [GitHub ↗] · [Demo ↗]`.
- [x] Implemented as `::before`/`::after` content on the anchor (`.row-alt-links a`) — the whole bracketed unit is clickable and the hover underline spans it; no HTML duplication, no change to the shared Link component. Scoped to /projects (the only user of `.row-alt-links`).

### 3.20 — /projects: explicit link labels (2026-11-22, owner)
- [x] **Row format `Name [GitHub] [Demo]`** — "be explicit about the name, the demo link and the github": the name is now plain text (no link hiding in it); every link renders beside it with its explicit label, `· `-separated. GitHub first, then Demo (or arXiv).
- [x] **ProjectX 2021 + NN Sensitivity**: both GitHub and the paper — paper labeled `[arXiv]` (per owner's suggestion).
- [x] Final rows: Hearts `· GitHub · Demo` | MathSearch `· GitHub` | ProjectX 2021 `· GitHub · arXiv` | NN Sensitivity `· GitHub · arXiv` | Personal Website (v2) `· GitHub`.
- [x] `altLinks` helper retired (the name no longer carries the first link); DESIGN §6 + resolved #19; YAML comment documents the format.

### 3.19 — /projects: flat list + Hearts Live link (2026-11-22, owner)
- [x] **No expansion** — "let's just display all of them in order": the `Show all N projects` native `<details>` is removed; the featured and archive rows render into one `<ul class="rows">`, most relevant first. The `featured`/`archive` split in `projects.yaml` survives only as a row-shape distinction (hook+body+tags vs line+year).
- [x] **Hearts: Live + GitHub** — added a Live link to `https://hearts.alexander-wang.net` (verified live, 200 — the existing `E2F96O5L3ZEDKQ` distribution; untouched). Live is the first link, so it rides the row title (the name links to the app); GitHub sits beside it.
- [x] CSS: the `.archive` details/summary/chevron block deleted; motion exception #2 (chevron rotate) retired from §5; all stale `details`/`expandable` references updated (DESIGN §5/§6/§7/§9/§10, content/README, root README).

### 3.18 — Icon + logo fixes (2026-11-22, owner)
- [x] **One icon per theme mode** — owner: "I don't like the two emojis being pressed together. One emoji per mode." Two problems found:
  - (a) **Real bug (since 3.17):** the button actually showed *two* icons in light/dark mode — the base CSS hid only `.icon-sun`/`.icon-moon`, so `.icon-auto` stayed visible under the sun/moon. Fixed: all three icons hidden by default; the matching `:root[data-choice=…]` rule un-hides exactly one.
  - (b) The auto glyph (monitor + stand) read as two stacked symbols. Replaced with a single **half-filled circle** (the standard "auto" pictogram) — button + menu row, in `Nav.astro`.
- [x] **No white edge on experience logos in dark mode** — the TAE and Cornell PNGs carried white backgrounds, which showed as a white ring/box around the logo in dark mode (the chip background was also `#fff`). Fix:
  - Re-extracted all three plain logos (AWS, TAE, Cornell) from the 2.0 sources (`aws_light.jpg`, `tae.png`, `cornell_cis.jpg`) as **transparent-background art** via background un-multiplication (white-bg and per-row gradient-bg variants), centered on a 64 px canvas at 84 % fill.
  - Chip background `#fff` → `var(--bg)` (the page shows through).
  - Dark mode: the three logos become a **light silhouette** (`filter: brightness(0) invert(1)`, both `data-theme` and `prefers-color-scheme` sources); the Amazon Music chip keeps its full-bleed gradient in both themes (`xp-logo--color` via `COLOR_LOGOS` in `data.ts`).
  - The 2.0 sources are kept untouched in the 2.0 repo.
- [x] Verified: light/dark desktop, dark chips (aws/tae/music/cornell), light chips, theme menu (one icon per row), all three button icons, mobile 390×844. DESIGN.md amended (resolved #16 icon note, #17, §4 nav, §7 chips).

### 3.13 — Owner content/layout pass (2026-11-21)
- [x] **About verbatim** — `content/about.md` body replaced with the 2.0 "About Me" text exactly (drafted prose retired; lead dropped — 2.0's page had none). Emails kept as bold text, made mailto-clickable (display text unchanged).
- [x] **Hero links aligned to text** — `<p class=hero-links>` moved inside `.hero-copy` (owner: "align to the text instead of the picture"). Mobile: centered under the stacked text.
- [x] **Experience logos** — 4 company logos from 2.0's `public/images/` (aws_dark, amazon_music, cornell_cis, tae) → 64 px PNGs in `src/assets/` (~3 KB each), rendered as 36 px white chips before the title line (`:has()`-scoped flex so /projects + /blog rows are untouched). Logo key in `experience.yaml`, resolved by the `LOGOS` map in `src/lib/data.ts`.
- [x] **Experience curation** — cut per "paid professional software engineering jobs only + TA": ~~Researcher, Cornell~~ (P STAT paper entry) and ~~Project Lead, ProjectX 2021~~ (the one explicitly named). Kept: SWE II, SWE I (both AWS HealthOmics), TAE intern, Amazon Music intern, TA CS 4780, AWS Connect intern. Both cut entries are git-recoverable.
- [x] Build green; DESIGN.md amended (§4 hero, §7 experience, §8.6, §9.13, §9.1 inventory, resolved #11).

### 3.17 — Theme picker dropdown (2026-11-22, owner)

- [x] **Owner ask**: replace the light/dark toggle with a dropdown: **Automatic / Light / Dark**.
- [x] **Storage**: `localStorage.theme` = `auto|light|dark` (old `light`/`dark` values are valid choices — nothing migrates). `auto` → no `data-theme` on `<html>`: the OS `prefers-color-scheme` decides, JS-free, live OS flips tracked by the media query for free.
- [x] **Button icon mirrors the saved choice** — monitor (auto) / sun (light) / moon (dark) — via `data-choice` on `<html>` set by the pre-paint `<head>` snippet (extended to also set `data-theme`), so no icon flash. No `data-choice` (JS off) → auto icon by default.
- [x] **Menu**: hairline `--bg` box (no shadow — §8), right-anchored under the button (stays on screen at the mobile nav edge), rows = icon + label, chosen row in `--accent` + right-aligned check. `role=menu`/`menuitemradio`/`aria-checked`; button `aria-haspopup`/`aria-expanded`/`aria-controls`; closes on select / Escape / outside click; focus returns to the button.
- [x] **ui.ts** theme section rewritten (choice state machine: `storedChoice` / `applyChoice(choice, save)` / `setThemeMenuOpen`); old `systemDark` listener dropped — nothing to sync when the icon reflects the choice, not the effective theme.
- [x] Mobile nav grid: `grid-area: toggle` moved from `.theme-toggle` to the `.theme-picker` wrapper.
- [x] Verified headless: fresh visit → auto; stored light/dark/`banana` → correct pre-paint restore + icon + check; open/close + selection + persistence all pass; desktop + mobile screenshots.
- [x] DESIGN §8 (choices + priority), §4 nav line, resolved item 16 (supersedes item 9).

### 3.16 — Hero centering + footer below the fold (2026-11-22, owner)

- [x] **Owner ask**: "make the footer a little lower so it's off the page at the start… profile and text vertically centered on most screen sizes. Footer should only show up if the user scrolls."
- [x] `.hero` (home only) now: `min-height: calc(100svh - 65px)` desktop / `calc(100svh - 57px)` mobile (nav heights **measured** on the built page: 65 px / 57 px), `display: flex; align-items: center` — the profile + text center in the visible area under the nav, and the page is tall enough that the footer sits below the fold.
- [x] `100vh` fallback line before `100svh` (cascade) for browsers without svh.
- [x] Measured verification (headless): content center == visible center at 1280×800 and 1440×900 (±3 px at 1024×768, ±8 px mobile 390×844); footer top below the viewport in every size tested. Short windows (≈513 px) simply can't fit the 440 px portrait — content scrolls, acceptable.
- [x] DESIGN §4 hero section + resolved item 15 updated (supersedes the old "not full-viewport" rule — the video hero was the sin, not the height).

### 3.15 — Changelog migration (2026-11-22, owner)

- [x] **Migrate the 2.0 "Website History" page** → `/changelog` (same URL as 2.0). All seven entries (v1.0.0 → v2.3.0) carried over **verbatim** — only two obvious typos fixed silently ("home have" → "home page" in 2.1.0; "It's remnents" → "Its remnants" in 1.0.0).
- [x] **New 3.0.0 entry** (November 2026) records the full rebuild: static multi-page rewrite, design rework, timeline, build-time KaTeX, `/old/` availability, CircleCI retired.
- [x] **Data-driven**: `content/changelog.yaml` (`version`, `date`, markdown `body`), rendered as hairline rows ("Version X · Month Year" title line + body). Inline links work: same-origin links plain, external get the ↗ arrow.
- [x] **Footer link** ("Changelog" between GitHub and Old site) — 2.0 had it as a small footer link too; not in the nav.
- [x] **Astro 7 gotcha (new)**: `render()` from `astro:content` is entry-only — raw markdown strings must go through the `MarkdownProcessor.createRenderer()` API. The pipeline was extracted to `src/lib/markdown-pipeline.ts` (single source of truth; `astro.config.mjs` and `src/lib/render-markdown.ts` both use it). Result field is `code`, not `html`.
- [x] Blog KaTeX regression-checked after the pipeline extraction — clean.

### 3.14 — Owner pass 2 (2026-11-22)
- [x] **Favicon = bare monogram** — the accent disc is retired: bare AW letterforms, tight-cropped to the letterforms' actual bounds (the old `viewBox` was silently clipping ~10% off the top and bottom), ink blue `#1F5FA8` for light tabs + a `prefers-color-scheme: dark` twin in `#7AA5E8` (`public/favicon-dark.svg`). Favicons can't read the page's JS toggle, so the twin follows the browser/OS scheme. (Pitfall hit: SVG comments must not contain `--` — XML rejects them.)
- [x] **Résumé links open in a new tab** — all three (nav, hero, footer) get `target="_blank" rel="noopener noreferrer"` via a content `newTab: true` flag on the link (schema + `SiteLink` + renderers), not hardcoded per page. QA caught two renderers not forwarding the flag (footer, hero) — fixed.
- [x] **/experience = vertical timeline** — owner: "dates and pictures to the left, an open circle along the timeline, text descriptions to the right." 3-zone row: left 128 px column (date range nowrap + location, 48 px white logo chip — up from 36 px), a 24 px rail (1 px `--border` line, no stub above the first node / below the last), an open circle (12 px ring, 1.5 px `--accent` border, `--bg` fill masks the line), then title + bullets. The page lead ("The roles, newest first…") is removed. Mobile: rail hidden, logo + dates row above full-width text. Scoped under `.xp` — /projects + /blog rows verified untouched.
- [x] Screenshots verified: desktop light/dark, mobile; /projects + /blog regression. DESIGN.md amended (§6 header, §7 experience, resolved #12–13).
- [x] **Titles shortened to one line (owner, 2026-11-22):** organization dropped from the title line ("Software Engineer II · Amazon (AWS HealthOmics)" wrapped) — it now leads the first bullet, with the logo chip + location carrying the company. TA title: "Teaching Assistant" (CS 4780 dropped — opaque to non-Cornell readers; the course *name* stays in the bullet). `company:` field removed from the YAML.
- [x] **Rail breathing room + projects lead dropped (owner, 2026-11-22):** `--xp-rail` 24 → 32 px (16 px of air each side of the line — the rail-to-text gap read cluttered); the projects page lead ("What I've built that's still live…") removed — /projects is now h1-only like /experience.
- [x] **Timeline detail fixes (owner, 2026-11-22):** (a) open circle re-centered on the rail — the ring drifted ~2 px left because `border-box` makes the 12 px include the 1.5 px border, and the 1 px line's center sits 0.5 px right of its left edge; offsets now account for both; (b) logos fill the chip edge to edge (`object-fit: cover`, `overflow: hidden` for the rounded corners) — the 40 px-in-48 px sizing left a white gap ring around each image.

---

## Cross-cutting

- **Owner delegation (2026-11-21):** Phase 3 proceeds without per-page owner sign-off — owner reviews the finished Phase 3 as a whole. Phase 4 (infra + cutover) still starts only on owner's go, after the owner has seen the site.
- `reviewer` pass over the whole site before cutover (4.5).
- Every page in Phase 3 gets a `visual-tester` pass (mobile 360px, desktop, dark mode, readability).
- Any new decision → written into the docs in the same session (the docs are the team's shared memory).

## Blocked / parked

- (none — Phase 4 waits on the owner's whole-Phase-3 review)
