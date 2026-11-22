# Content conventions

All site content lives here, as data (markdown + YAML). The editor owns this directory; the builder renders it. Nothing in this directory is stack-specific — it must stay portable to whatever SSG lands in task 2.1.

## File layout

```
content/
├── README.md            ← this file
├── site.yaml            ← global metadata: title, description, nav, footer, socials
├── home.md              ← hero (name, role line, links) — no body prose
├── about.md             ← about page (frontmatter title + lead, then prose)
├── 404.md               ← the 404 page's one dry sentence
├── experience.yaml      ← all work entries, newest first
├── projects.yaml        ← featured set + archive
├── changelog.yaml       ← website history entries (2.0 migration), newest first
└── blog/
    ├── index.yaml       ← source of truth for the /blog page (order, titles, dates, summaries)
    ├── matrix-calculus-preface.md
    ├── matrix-calculus-chapter-1.md
    └── matrix-calculus-chapter-2.md
```

One file per page, one file per post. No per-page config files — if a page needs data, it goes in that page's frontmatter.

## Frontmatter fields

Markdown files use a YAML frontmatter block. Blog posts (and `blog/index.yaml`) additionally carry series fields.

| Field | Where | Required | Notes |
|---|---|---|---|
| `title` | about, 404, posts | yes | Display title. For posts: full title, e.g. `Matrix Calculus — Preliminaries`. |
| `lead` | about, (future prose pages) | no | One sentence, ≤ 90 chars, rendered under the h1 in muted text (DESIGN §4). |
| `name`, `role`, `links` | home | yes | Hero: `name` is the h1; `role` is the muted line; `links` is a list of `{label, href, external?}` — 2–3 links (owner picks the set, DESIGN §11). |
| `date` | posts, index.yaml | yes | ISO `YYYY-MM-DD`. The builder chooses the display format. |
| `slug` | posts, index.yaml | yes | URL path under `/blog/`. Must match the filename stem. |
| `summary` | posts, index.yaml | yes | One line, ≤ ~160 chars. The index row's excerpt. |
| `readingTime` | posts, index.yaml | yes | Minutes, ~200 wpm, recomputed from final word count. |
| `series`, `part` | posts, index.yaml | no | Group posts into a series; `part` 0-indexed for reading order. Drives the "In this series" nav. |
| `line` | 404 | yes | The single dry sentence. |

**Blog index is the source of truth for `/blog` display.** `blog/index.yaml` lists posts in display order (newest date first; same-date series posts in reading order) and must stay in sync with each post's frontmatter (`title`, `date`, `summary`, `readingTime`). The builder may render the series nav from the `series`/`part` fields and then drop the in-body "In this series" list if it prefers generated nav.

## Experience entries

`experience.yaml` → one row per role (DESIGN §7). Fields: `role`, `company`, `location` (all optional except role), `dates` (display string, e.g. `Jul 2025 — present`), `bullets` (1–3, concrete), optional `links` (`{label, href, external?}`). Newest first. The row renders as "**role** · company" / date range / bullets.

## Projects — featured vs archive

`projects.yaml` has two lists (pattern: DESIGN §6, rows, no images):

- **Featured** — 3–4 projects, newest or most-relevant first. The editor's vouch: public, substantive, and the work a visitor should actually look at. Fields: `name` (linked), `hook` (one line, ≤ ~120 chars), optional `body` (1–3 sentences), `tags` (plain text, rendered with ` · ` separators), `links`, `year` (data only — featured rows don't display it).
- **Archive** — everything else that still exists: one line each (`name`, `line`, `year` in the meta line, optional `links`). Rendered in a native `<details>` ("Show all N projects"). Nothing is deleted or hidden unless the reader wants depth; revisit the pattern if the archive passes ~15 items.

Demotion rule: a project leaves Featured (to Archive, not to oblivion) when a newer, more representative project takes its slot, or when it duplicates an Experience entry that already carries the links.

## Blog math — KaTeX

Standard KaTeX, rendered at build time (HOSTING D11). No custom macros, no `\begin{equation}` wrappers:

- **Inline math:** `$...$` — no background, KaTeX's own fonts.
- **Display math:** `$$...$$` on its own lines — the builder renders each block into a recessed `--surface` block (16px 24px padding, radius 8, `overflow-x: auto` so long equations scroll at 360px).
- Supported constructs: `\frac`, `\lim`, `\sum`, `\int`, `\begin{bmatrix}`/`\begin{pmatrix}`, `\begin{align*}`, `\mathbb`, `\mathbf`, `\nabla`, `\|` for norms, `o(h)` for little-O (plain letter).
- Keep one display equation per block. Long derivations split across blocks rather than one giant `align*`.

## Tone rules

- Plain, specific, first person. Concrete nouns and numbers over adjectives: show the artifact, not the enthusiasm.
- **Banned:** "passionate", "excited", "delve", "leverage", "seamless", "robust", "cutting-edge", "in order to", "I hope you enjoy", exclamation marks.
- One idea per sentence. If a clause repeats the one before it, cut the clause.
- Short sentences, active voice. The reader should finish a paragraph knowing one more thing.
- Dry humor: allowed exactly once on the whole site (the 404 page owns it).
- Rewrite, don't translate: when porting copy from 2.0, mine the facts, then write fresh. Never copy 2.0 prose.
- **Second pass is mandatory:** after a first draft of any new/rewritten copy, cut at least 10% of the words before calling it done.
- **No invented facts.** Any fact you're not sure of gets a `<!-- VERIFY: ... -->` comment (in markdown) or a `# VERIFY:` comment (in YAML) right next to it. The owner resolves all VERIFY comments in task 1.4.

## YAML gotcha

YAML reads `word: word` as a mapping. **All prose scalar values in YAML files are double-quoted** (`bullets`, `hook`, `body`, `line`, `summary`, `lead`, `dates`). If a value contains a `"` inside, escape it as `\"`.

## VERIFY convention

`<!-- VERIFY: <what's uncertain and where the source is> -->` — markdown files. `# VERIFY: <same>` — YAML files. Never ship a guess silently; never delete a VERIFY comment yourself — the owner's review pass (1.4) does that.

## Assets that live outside this directory

- **Résumé PDF:** copy `alexander_wang_resume.pdf` (from mysite-2.0 `public/files/`) into the build output as `/resume.pdf`. Verify it's current before cutover (last updated Jul 2026). See `site.yaml`.
- **Images:** v1 targets zero images (DESIGN §9/§13). Any image must justify its bytes.
