# Design System — mysite-3.0

**Status:** v1, finalized (2026-11-21) — owned by `art-director`.
**Source of truth:** This file. A decision made anywhere else gets written here or it doesn't exist.
**North Star (from the owner):** *Clean and straight to the point, with subtle design choices that make it comfortable to read and look at.*

Every page must feel **easy**, never **designed**. Subtlety is the brand.

---

## 1. Palette

Cool neutral base + **one ink-blue accent** (owner decision, 2026-11-21 — the original warm paper/rust palette read "a little too warm"). The accent appears only in links and interactive states — never as a fill, background, or large surface. Two schemes (light/dark) share the same token names; every color in the codebase is referenced through a token, never a raw hex.

### Tokens

| Token | Light | Dark | Job |
|---|---|---|---|
| `--bg` | `#F7F8FA` | `#13161B` | Page background — cool paper / cool near-black |
| `--surface` | `#EEF0F3` | `#1B1F26` | Recessed surface: code blocks, display math, inline code |
| `--fg` | `#1A1E24` | `#E8EAED` | Primary text |
| `--fg-muted` | `#5A6270` | `#9AA3B0` | Leads, meta, dates, footer, list sub-lines |
| `--border` | `#DFE2E8` | `#2A303A` | Hairlines only: nav bottom, list rows, footer top |
| `--accent` | `#1F5FA8` | `#7AA5E8` | Links + interactive states (hover, active nav, focus) |

**Rationale**

- Cool paper `#F7F8FA`, not `#FFF` — pure white is harsh and makes the accent vibrate; cool near-black `#13161B`, not `#000` — pure black causes light-text vibration and OLED banding. The base should read as *paper and lamp light*, matching the "comfortable to read" north star.
- Ink blue `#1F5FA8`, chosen by the owner (2026-11-21) over deep teal and accent-free mono: calm and professional for a software engineer's site; it pairs cleanly with the black-on-white 2.0 monogram. It is a saturated-but-deep blue — "ink", not "SaaS dashboard" (2.0's Nord blue-gray is still what we're replacing; this is a deliberate, single-hue accent, not a gray-blue scheme).
- The dark accent `#7AA5E8` is a lighter value, not a tint of the light one — it must stay ≥4.5:1 on near-black without going neon.
- Grays carry a cool cast to sit with the blue accent; warm grays would muddify it.

### Contrast (WCAG 2.1, computed 2026-11-21 — all pairs pass AA for *normal* text, ≥4.5:1; re-computed for the cool palette same day)

| Pair | Light | Dark |
|---|---|---|
| `--fg` on `--bg` (body text) | **15.7:1** | **15.0:1** |
| `--fg` on `--surface` (code/math) | 14.7:1 | 13.7:1 |
| `--fg-muted` on `--bg` | 5.8:1 | 7.1:1 |
| `--fg-muted` on `--surface` | 5.4:1 | 6.5:1 |
| `--accent` on `--bg` (links) | 6.1:1 | 7.2:1 |
| `--accent` on `--surface` | 5.6:1 | 6.6:1 |
| Button: `--bg` on `--fg` (inverted) | 15.7:1 | 15.0:1 |

No large-text-only pairs exist. Rationale: links are normal-sized text, so the accent must clear 4.5:1 on both schemes — verified, not assumed.

---

## 2. Typeface

**One family: Manrope** (variable), self-hosted. No pairing — one family everywhere keeps rhythm consistent across pages (principle: consistency beats novelty).

| Property | Value |
|---|---|
| Family | Manrope (variable font, wght 200–800 shipped) |
| Weights *used* | **400** body · **500** nav/links/buttons/list titles · **700** headings |
| Format | WOFF2, `font-display: swap`, single `@font-face` with `font-weight: 200 800` |
| Files (verified sizes, Google Fonts v23, 2026-11-21) | `manrope-latin.woff2` — **24,532 B** · `manrope-latin-ext.woff2` — **15,160 B** |
| Budget | ≤ ~30 KB per weight set → **met**: 24.5 KB (latin only) / 40 KB (both subsets), one file instead of three static weights |

**Rationale**

- Self-hosted under `/assets/fonts/` (content-hashed, `immutable` cache per HOSTING D5): 2.0 loaded Raleway from the Google Fonts CDN — a third-party render-blocking request on a personal site; self-hosting keeps third-party dependencies at zero, consistent with the near-zero-JS constraint.
- Weights: the file is variable, but only 400/500/700 are used — the range is available, the discipline is the design.
- Manrope over Inter/Roboto/etc.: a humanist sans with just enough character to avoid the generic-default look, designed for UI legibility, holds up from 48 px display down to 13 px meta.
- **Monospace is the system stack** — `ui-monospace, SFMono-Regular, Menlo, Consolas, monospace`. Rationale: code is functional, not branded; a third font family would cost ~30 KB for no design gain.
- **KaTeX ships its own math fonts** (functional, not decorative): the full set is several hundred KB; the build must ship only the faces the three posts actually use (typically `KaTeX_Main` regular/bold/italic + `KaTeX_Math-Italic` + `KaTeX_Size1/2` ≈ 90–100 KB), with glyph subsetting targeted to get under ~50 KB. This is a build task for 2.3; the cap here is a design constraint.
- Blog typography: body 18 px/1.65 in Manrope — no separate serif for posts. Rationale: a sans at 18 px with 65–75 ch measure reads beautifully (this is what Linear/Stripe-style docs do); a serif pairing would add a family, a payload, and a second rhythm to maintain.

---

## 3. Type scale & spacing

### Type scale — exactly 6 sizes

| Token | Size | Line-height | Weight | Used for |
|---|---|---|---|---|
| `--text-xs` | 13 px (0.8125 rem) | 1.5 | 400 | Dates, meta, footer, tags |
| `--text-sm` | 15 px (0.9375 rem) | 1.5 | 400–500 | Nav, buttons, list meta lines |
| `--text-base` | 18 px (1.125 rem) | 1.65 | 400 | Body text (all prose) |
| `--text-md` | 22 px (1.375 rem) | 1.4 | 500 | h3, list row titles |
| `--text-lg` | 28 px (1.75 rem) | 1.3 | 700 | h2 |
| `--text-xl` | 36→48 px, `clamp(2.25rem, 1.5rem + 2.5vw, 3rem)` | 1.15 | 700 | h1 — identical on every page, including the hero name |

- Body is 18 px, not 16 px — the north star says *comfortable to read*; at 18 px, 640 px ≈ 68–75 ch, inside the 65–75 target.
- 1.65 body line-height — standard long-form comfort.
- One h1 size site-wide — the hero is a heading, not a poster; the 2.0 100 px Raleway hero is the anti-example.
- The only fluid size is h1 (`clamp`); everything else is fixed so the rhythm is predictable.
- Letter-spacing: `--text-xl` at −0.015 em, `--text-lg` at −0.01 em, all others 0 — subtle tightening for large display only.

### Spacing scale — 4 px base, 9 steps

| Token | Value | Typical job |
|---|---|---|
| `--space-1` | 4 px (0.25 rem) | Micro gaps inside components |
| `--space-2` | 8 px (0.5 rem) | h1 → its lead line |
| `--space-3` | 12 px (0.75 rem) | Inline code padding, tag gaps |
| `--space-4` | 16 px (1 rem) | Related elements, list row padding (vertical) |
| `--space-5` | 24 px (1.5 rem) | Nav link gap, between list items, code block margin |
| `--space-6` | 32 px (2 rem) | Footer top padding, mobile h2 top |
| `--space-7` | 48 px (3 rem) | h2 top margin, section gap (mobile) |
| `--space-8` | 64 px (4 rem) | Page top padding, gap after page header, featured → archive |
| `--space-9` | 96 px (6 rem) | Major section rhythm (desktop), page bottom padding, hero padding |

Rationale: 4 px base keeps everything on one grid; 9 steps cover micro→macro so no arbitrary value is ever needed; the section rhythm is **96 px desktop / 48 px mobile** and nothing else.

### Radii (the only ones that exist)

| Token | Value | Used for |
|---|---|---|
| `--radius-sm` | 4 px | Inline code |
| `--radius-md` | 6 px | Buttons |
| `--radius-lg` | 8 px | Code blocks, display-math blocks |

Rationale: radius only where a recessed surface meets text; no rounded cards anywhere.

---

## 4. Layout

### Widths

| Token | Value | Used on |
|---|---|---|
| `--content-width` | **40 rem (640 px)** | All prose pages (about, experience, blog index, blog posts) + home hero |
| `--wide-width` | **48 rem (768 px)** | `/projects` only |
| Gutter | 20 px mobile / 32 px desktop | Page padding left/right |

Rationale: one measure for the whole site = one reading rhythm; 640 px at 18 px font lands at 68–75 ch. `/projects` is the single documented exception (rows carry title + description + link and want the room). No third width exists.

### Page header pattern — identical on /about, /experience, /projects, /blog

```
h1            --text-xl / 700, --fg
lead line     --text-base, --fg-muted, one sentence, ≤ 90 chars
[64 px gap]
content
```

- No eyebrow label, no icon, no rule under the title — the 64 px gap *is* the divider. This is the direct opposite of 2.0's `<h1>…<hr/>` habit.
- Same geometry on every subpage: instant orientation, zero per-page design decisions.
- Home is the exception: it has the hero pattern below, not a page header (it *is* the header).

### Hero (home only)

- A normal section, **not** full-viewport: 96 px top padding, name as h1 (`--text-xl`), role line (`--text-base`, `--fg-muted`), then 2–4 inline links (GitHub, Résumé, Email, Blog — exact set is owner's, see §11) as accent links with 24 px gap, 96 px bottom padding.
- Mostly text and whitespace: no video, no 100 vh, no chevron, no background treatment. One image is allowed: the hero portrait (owner, 2026-11-21).
- Rationale: 2.0's 100 vh video hero + 50 px scroll chevron is the defining sin of the old site; a 48 px name on a wall of whitespace reads as confident, not empty.

### Nav

- Static (not sticky), `--content-width` container, 16 px vertical padding; hairline bottom border (`--border`) — the only chrome rule on the page besides the footer's.
- Left: monogram badge (2.0's `monogram.svg`, transferred 2026-11-21, 24 px) + text wordmark **"Alexander Wang"** (`--text-sm`, 500, `--fg`) — the badge is the site's only image mark; the wordmark stays text.
- Right: About · Experience · Projects · Blog · Résumé (`--text-sm`, 400, `--fg-muted`; hover → `--fg`; **current page → `--accent`, 500**).
- Mobile (≤ 640 px): wraps onto centered lines — wordmark first, then the links, 16 px gap; two lines when they fit, three at 360 px (the five links need ~330 px of their own width). **No hamburger.** Rationale: a hamburger is JS + state + a11y work for five short links; wrapping is zero-JS and always visible. *(Amended 2026-11-21 after visual QA: the original “two lines” target was geometrically impossible at 360 px.)*
- Not sticky: the pages are short; blog posts are the only long pages and they end with a link back to /blog. Rationale: sticky chrome is a mobile-app habit that boxes the top of every screen.

### Footer

- Hairline top border, `--content-width` container, 32 px / 64 px top/bottom padding.
- Left: `© 2026 Alexander Wang` (`--text-xs`, `--fg-muted`). Right: Résumé · GitHub · `/old/` (same style, accent on hover).
- No social icon row — 2.0's Font Awesome icon strip in the footer is exactly the icon-font filler we're removing.
- Rationale: one line of metadata plus escape hatches (résumé, source, the 2.0 archive per HOSTING D10); nothing else has a job there.

### Section rhythm within pages

- h2: margin 48 px top / 16 px bottom (mobile 32/12). h3: 32 px / 8 px. Paragraphs: 16 px apart, no first-line indent.
- Featured set → archive on /projects: 64 px gap.
- Rationale: heading margins at ~2×/½ of their size give a predictable cadence without a design decision per heading.

### Mobile (360 px)

- Single column, 20 px gutter, type scale unchanged (h1 handled by the clamp), nav wraps, lists keep their rows, no horizontal scroll anywhere except inside code/math blocks (which scroll within their own `overflow-x: auto` surface).
- Rationale: the desktop layout must hold at 360 px with only the gutter and nav wrap changing — a mobile redesign is extra surface area to test.

### 404 page

- Centered in `--content-width`, 96 px top: "404" (`--text-xl`/700), one dry sentence (editor writes it — dry humor allowed exactly once), then **Go home** — the site's only filled button.
- Rationale: gives the button pattern its one real job and the page its one joke.

---

## 5. Motion

**Default: none.** The page is complete on load; nothing animates in, nothing follows the cursor, nothing responds to scroll.

Allowed exceptions (opacity/transform only, ≤ 200 ms, ease-out, all disabled under `prefers-reduced-motion: reduce`):

| # | What | Spec | Why it earns its place |
|---|---|---|---|
| 1 | Link hover | color swap + underline fade-in, 150 ms | Tells the user "this is clickable" — an affordance, not decoration |
| 2 | `<details>` chevron | 90° rotate on toggle, 150 ms, transform only | Shows the disclosure state changed — the only motion on /projects |
| 3 | Button hover | background swap, 150 ms | Same affordance logic |

Global rule: `@media (prefers-reduced-motion: reduce) { *, *::before, *::after { transition: none !important; animation: none !important; } }`

Rationale: if motion doesn't communicate state (hover, expanded, focus), it's noise. 2.0's chevron-bounce and smooth-scroll-to-hash are the anti-example.

---

## 6. The projects pattern — curated + expandable

This is the signature page. One language: **rows**. No cards, no images, no grid.

### Featured set (top of /projects)

- 3 projects (owner-approved 2026-11-21: Hearts, MathSearch, ProjectX 2021), single column, newest/most-relevant first.
- Each project is a row:
  1. **Line 1:** project name (`--text-md`, 500) — linked, accent on hover, external arrow if off-site
  2. **Line 2:** 1–3 line description (`--text-base`, `--fg-muted`) *(amended 2026-11-21: owner-approved copy runs 1–3 lines)*
  3. **Line 3 (optional):** tech tags (`--text-xs`, `--fg-muted`, plain text separated by ` · ` — **no pill badges**)
- Rows separated by a 1 px `--border` hairline (border-top on all but the first), 16 px vertical padding.
- No image cards. Rationale: 2.0's screenshot cards were ornament + payload; a text row *is* the project, and the link carries the proof. Zero image bytes, faster read, and it matches the blog index so the site has one list language.

### Archive (bottom of /projects) — native `<details>`

```html
<details class="archive">
  <summary>Show all N projects</summary>
  <ul>
    <li> <!-- same row structure as featured; meta line includes the year -->
```

- **Recommendation: native `<details>`, no JS.** Rationale:
  - Zero-JS progressive disclosure — the platform handles keyboard, screen reader, and state for free (the near-zero-JS constraint makes this the obvious choice).
  - A JS toggle (button + `aria-expanded` + hidden class) buys nothing for this user and adds script + a11y surface.
  - A separate `/projects/archive` URL is navigation friction for a page that exists for one click; the archive is short (a handful of items). Revisit only if the archive passes ~15 items.
- `summary` styled as a quiet link-button (`--text-sm`, 500, `--accent`) with a CSS-drawn chevron (border-based triangle or inline SVG) that rotates on open — motion exception #2.
- Archive rows add the **year** to the meta line; featured rows don't.
- The `open` state does not persist across reload — acceptable: it's an expansion, not a view.
- Rationale for the whole pattern: the featured set is the curation (what the editor vouches for), the `<details>` archive is the completeness (nothing deleted, nothing hidden behind a click *unless* the reader wants depth). Both read as rows, so the page is one idea.

---

## 7. Component patterns — one style each

### Links

- `--accent`, no underline at rest; on `:hover` and `:focus-visible`: 1 px underline, `text-underline-offset: 3px`, faded in over 150 ms.
- External links: append an inline SVG arrow (↗, 0.7 em, `currentColor`, top-aligned) — the only icon besides the details chevron. Rationale: users shouldn't have to hover to learn a link leaves the site.
- Nav links: `--fg-muted` → `--fg` on hover; current page `--accent`/500 (see §4).
- Rationale: underline-on-hover is the subtle standard; permanent underlines on a text-dense site are visual noise; the accent stays reserved.

### Headings

- h1 `--text-xl`/700, −0.015 em, margin-bottom 8 px. h2 `--text-lg`/700, −0.01 em, margin 48/16. h3 `--text-md`/**500** — list row titles are 500, not 700, because a row title is a list, not a section.
- Color `--fg`, never accent, never underlined, no decoration of any kind.
- Rationale: weight and size do the hierarchy; colored/underlined headings are 2.0-era ornament.

### Buttons — one style, used sparingly

- Filled: background `--fg`, text `--bg` (monochrome inversion — the accent stays reserved for links); padding 8 px 16 px, radius `--radius-md` (6 px), `--text-sm`/500, no border.
- Hover: background `--fg-muted`, 150 ms. Focus: 2 px `--accent` outline, 2 px offset.
- Primary actions are normally accent *links with arrows*, not buttons. The only filled button on the site: **Go home** on the 404 page.
- Rationale: a content site has almost no actions; a single button style prevents drift, and the inversion means no new color is ever needed for one.

### List rows — the site's one structural device

- Rows separated by 1 px `--border` hairlines (border-top on all but the first), 16 px vertical padding, no horizontal padding.
- Standard row anatomy: **title line** (`--text-md`/500, links in accent) · **meta line** (`--text-xs`, `--fg-muted`: date / year / role) · optional **body line** (`--text-base`, `--fg-muted`).
- Used on: featured projects, archive rows, blog index, experience entries.
- This is the *only* hairline usage besides nav/footer chrome. Rationale: 2.0's `<hr>` elements were decorative section dividers; a list-row border is table structure — same CSS, different job — and it replaces "card + shadow + image" as the way repeated items get grouped.

### Experience entries

- One row per role: title line "**Role** · Company" (`--text-md`/500), meta line date range (`--text-xs`, `--fg-muted`), body 2–3 sentences or 1–3 short bullets (`--text-base`). *(amended 2026-11-21: owner-approved copy uses bullets)*
- No timeline rail, dots, or connector line. Rationale: the timeline rail is a résumé-template cliché; date ranges as text are unambiguous, print well, and cost nothing.

### Blog index

- One row per post: meta line date (`--text-xs`, `--fg-muted`) · title (`--text-md`/500, accent link) · optional one-line excerpt (`--text-base`, `--fg-muted`). Newest first. No cards, no thumbnails.
- Rationale: a blog is a list; rows + dates are the honest representation, and it reuses the row pattern from /projects.

### Code & math (blog posts)

- Inline code: `--surface` background, radius 4 px, 1 px 5 px padding, 0.9 em system mono.
- Code blocks: `--surface` background, 16 px padding, radius 8 px, `overflow-x: auto`, `--text-sm` system mono, 24 px vertical margin.
- Display math (KaTeX, build-time per D11): same recessed treatment — `--surface` background, 16 px 24 px padding, radius 8 px, `overflow-x: auto` (long equations scroll on 360 px), 24 px vertical margin. Inline math: no background, KaTeX's own font.
- Rationale: one recessed surface for all embedded artifacts says "this is a block, not prose" consistently — and it's the only place `--surface` is used.

### Focus & selection (affordances, not decoration)

- `:focus-visible`: 2 px solid `--accent` outline, 2 px offset, on every interactive element (links, buttons, `<summary>`).
- `::selection`: background `--accent`, color `--bg`.
- Rationale: keyboard users get the same visual language as the accent system; the selection tint is free and on-brand.

---

## 8. Dark mode

- Pure CSS: tokens defined on `:root`, overridden inside `@media (prefers-color-scheme: dark)`. **No JS toggle in v1** — a toggle is script + state + a11y work for a personal site (seed decision, confirmed).
- Both schemes are designed from day one: no raw hex anywhere except the two token blocks.
- No shadows anywhere in either scheme — shadows don't survive a dark-mode translation, which is one more reason this design has zero of them (2.0's card stack relied on them).
- Rationale: the OS preference is the only preference a personal site needs; tokens make "both from day one" a build-time guarantee, not a v2 promise.

---

## 9. Hard "do not" list

Carried forward from the seed, expanded with 2.0's specific sins. If a proposal needs any of these, it's a no without a new decision written in this file.

1. **No video, autoplay, or looping media** anywhere — 2.0's hero `<video autoPlay loop>`.
2. **No scroll indicators, parallax, or scroll-triggered animation** — 2.0's 50 px bouncing chevron; the only chevron in 3.0 is the `<details>` disclosure.
3. **No icon fonts** — 2.0's Font Awesome; icons exist only as inline SVG and only where functional (external-link arrow, details chevron).
4. **No `<hr>` or dividers where spacing works** — hairlines exist only as nav/footer chrome and list-row borders; 2.0 had an `<hr>` after nearly every section heading.
5. **No single-page hash-scroll navigation** — real pages, real URLs (HOSTING D3).
6. **No image logo** — the only image mark on the site is the 2.0 monogram badge (owner, 2026-11-21); the wordmark stays text.
7. **No cards with shadows, or any `box-shadow`, anywhere.**
8. **No gradient backgrounds, decorative color blocks, or the inverted dark-hero/light-body trick** (2.0's hero was a dark block over a light page).
9. **No full-viewport hero** (`min-height: 100vh`) — the hero is a section, not a screen.
10. **No sticky nav, scrollspy, or hamburger menu** — the nav wraps on mobile.
11. **No font CDNs or any third-party script/style** — self-host everything; the only external resources on the live site are outbound links.
12. **No decorative borders, underlines, or color on headings.**
13. **No image-heavy layouts** — any image must justify its bytes (≤ 100 KB each); v1 ships exactly one image: the home portrait (29 KB, 320 px).
14. **No more than 6 type sizes, no values outside the spacing scale, no second accent color.**

---

## 10. Asset budget (for builder/ops)

- Fonts: 24.5 KB Manrope (latin) + 15.2 KB (latin-ext, optional but default yes) + KaTeX faces ≤ ~50 KB after subsetting.
- CSS: single stylesheet, target ≤ 15 KB minified.
- JS: **0 KB** in v1 (the `<details>` pattern needs none).
- Image: one portrait, ≤ ~50 KB (320 px JPEG; 29 KB as shipped 2026-11-21). All other pages: zero images.
- Per-page HTML: ≤ 20 KB (non-math pages). Math pages are exempt: server-rendered KaTeX DOM is span-verbose (chapter 1 ≈ 242 KB raw) but compresses ~10× over the wire.
- Total per page (wire, gzip-compressed — CloudFront compresses HTML/CSS by default), target: **≤ ~150 KB** before any image. Measured 2026-11-21: non-math ≈ 45–46 KB, math ≈ 96 KB worst case.
- Rationale: the site should hit the edge in one round trip and paint before a 3G upload of the old hero video would finish one frame.

---

## 11. Resolved items

1. **Hero link set** (owner, 2026-11-21): Résumé · GitHub · Blog. Email lives on the about page, not the hero.
2. **Featured project count + order** (owner, 2026-11-21): 3 — Hearts, MathSearch, ProjectX 2021.
3. **Container geometry** (visual QA, 2026-11-21): the gutter sits *outside* the content width — text measure is exactly 640 px (768 px on /projects); implemented as `max-width: calc(width + 2 × gutter)`.
4. **Page leads on all four subpages** (visual QA, 2026-11-21): /experience, /projects, /blog now carry a lead line like /about; copy drafted by the orchestrator, pending owner review.
5. **Budgets measured on the wire** (visual QA, 2026-11-21): §10 totals apply to gzip-compressed transfer sizes; raw KaTeX HTML is exempt per the math-page note.
6. **Bullets in experience entries; 1–3 line featured descriptions** (visual QA, 2026-11-21): owner-approved content wins over the original pattern wording; §6/§7 amended accordingly.
7. **Home portrait + 2.0 monogram** (owner, 2026-11-21): circular 88 px portrait + short bio on home (the one allowed image); 2.0's `monogram.svg` transferred to the nav (24 px beside the text wordmark) and the favicon (tightened viewBox).
8. **Color scheme: cool paper + ink blue** (owner chose A, 2026-11-21): the warm paper/rust v1 palette was retired as "a little too warm"; §1 tokens swapped (contrast re-verified, all pairs ≥4.5:1). Token-only change — no layout/type impact.
