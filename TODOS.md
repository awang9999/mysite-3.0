# Task List — mysite-3.0

**Status:** Phase 3 complete (visual QA passed with fixes folded in) — awaiting owner's whole-Phase-3 review; Phase 4 starts on owner's go
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

**Visual QA (2026-11-21, 36 runs: 9 pages × 2 viewports × 2 schemes):** all pass. Fixes folded in: D-1 leads, m-3 measure 576→640 px (gutter outside content width); spec amendments: m-4 3-line nav wrap at 360 px (2 lines geometrically impossible), m-5/m-6 owner-approved copy wins (bullets, 1–3 line descriptions), D-2 §10 budgets measured on the wire (math pages exempt from the raw-HTML line; wire worst case 96 KB). m-7 (KaTeX CSS on all pages) was a QA false positive — it's scoped to the 3 posts.

## Phase 4 — Infra & cutover (all `ops`, follows HOSTING §6)

- [ ] **4.1** `deploy/deploy.sh` — CI-ready: non-interactive, idempotent, meaningful exit codes; build → two-tier sync → invalidate → verify (§9 checklist).
- [ ] **4.2** CloudFront: add apex alias + cert coverage, `www` → apex 301 behavior, response-headers policy (HSTS, nosniff, referrer).
- [ ] **4.3** Enable S3 versioning; confirm `404.html` error document.
- [ ] **4.4** Build the 2.0 archive → `/old/` (`PUBLIC_URL=/old` + router basename, copy `index.html` to the ~5 route paths).
- [ ] **4.5** Cutover (HOSTING §6 steps 5–7) + full verification (§9).
- [ ] **4.6** Decommission: CircleCI project, legacy dist `E96YWX7J3SY11`, legacy bucket `alexander-wang.net`, old `deploy.sh`.
- [ ] **4.7** *(later, owner's word)* Remove `/old/` and the footer link.

---

## Cross-cutting

- **Owner delegation (2026-11-21):** Phase 3 proceeds without per-page owner sign-off — owner reviews the finished Phase 3 as a whole. Phase 4 (infra + cutover) still starts only on owner's go, after the owner has seen the site.
- `reviewer` pass over the whole site before cutover (4.5).
- Every page in Phase 3 gets a `visual-tester` pass (mobile 360px, desktop, dark mode, readability).
- Any new decision → written into the docs in the same session (the docs are the team's shared memory).

## Blocked / parked

- (none — Phase 3 page-by-page polish is next: 3.1–3.7 pages are already implemented and functional via 2.2/2.3, so 3.x is the visual/finishing pass — per-page `visual-tester` runs, then 3.8 meta/favicon/robots + `/old/` footer link)
