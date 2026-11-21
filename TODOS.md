# Task List — mysite-3.0

**Status:** Draft for owner sign-off (2026-11-21)
**Conventions:** each task names its owner persona; phases are ordered by dependency; check boxes off as things land. Decisions live in `docs/HOSTING.md` (D1–D11) and `docs/DESIGN.md` — this file tracks *work*, not *decisions*.

---

## Phase 1 — Foundations (no stack required, can start immediately)

- [x] **1.1 Design system v1** — `art-director`: finalize `docs/DESIGN.md`. Palette + self-hosted typeface, type scale, spacing scale, dark-mode tokens, page layout rules, motion rules (default: none), and the concrete pattern for "curated + expandable projects." ✅ 2026-11-21 — warm paper + rust accent, self-hosted Manrope variable, 6-size type / 9-step spacing scales, row-based lists, native `<details>` archive, zero JS / zero images in v1, ~150 KB per page.
- [ ] **1.2 Content skeleton** — `editor`: create `content/` with conventions doc. Hero line, about, experience entries, projects (featured set + archive), blog index. Mine 2.0 for facts; `<!-- VERIFY -->` comments on anything uncertain.
- [ ] **1.3 Migrate matrix-calculus series** — `editor`: re-port the 3 posts as markdown with KaTeX math. Content first, no visual/image parity with 2.0 (D11).
- [ ] **1.4 Owner review pass** — owner: review design tokens + all copy, resolve VERIFY comments, approve project curation (featured list + order).

## Phase 2 — Scaffolding (the parked stack decision un-parks here)

- [ ] **2.1 Pick the SSG stack** — owner + `builder`: must satisfy HOSTING D3/D11/§10 — multi-page static output, real URLs, no SPA, near-zero runtime JS, build-time KaTeX, `dev`/`build`/`preview` scripts. Small decision; everything in Phase 1 gives it concrete inputs (content volume, math, design tokens).
- [ ] **2.2 Project scaffold** — `builder`: init project, layout shell (nav + footer), all routes (`/`, `/about`, `/experience`, `/projects`, `/blog`, `/blog/<slug>`, 404), and working `dev` / `build` / `preview` per HOSTING §10.
- [ ] **2.3 Design system into code** — `builder`: implement DESIGN.md tokens (typography, color, spacing, dark mode) as the base stylesheet every page inherits.

## Phase 3 — Pages (pattern per page: `builder` implements → `visual-tester` checks responsive/dark/readability → owner looks)

- [ ] **3.1 Home / hero**
- [ ] **3.2 About**
- [ ] **3.3 Experience**
- [ ] **3.4 Projects** (featured set + expandable archive)
- [ ] **3.5 Blog index + post template** (KaTeX rendered at build time)
- [ ] **3.6 Render the three migrated posts**
- [ ] **3.7 404 page**
- [ ] **3.8 Finishing pass** — meta tags, favicon, robots.txt, manifest, footer link to `/old/`

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

- `reviewer` pass over the whole site before cutover (4.5).
- Every page in Phase 3 gets a `visual-tester` pass (mobile 360px, desktop, dark mode, readability).
- Any new decision → written into the docs in the same session (the docs are the team's shared memory).

## Blocked / parked

- Stack choice (2.1) — parked by owner; everything in Phase 1 proceeds without it.
