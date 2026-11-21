# mysite-3.0

The third iteration of my personal website: **clean and straight to the point, with subtle design choices that make it comfortable to read and look at.** No fluff — the previous site had too much of it.

## Pages

- **Home** — hero (name, one-line role, links)
- **About** — who I am
- **Experience** — work history
- **Projects** — curated featured set, expandable into the full archive
- **Blog** — index + posts

## The agent team

This repo is developed by a small team of agentic personas in `.pi/agents/`, each with one job:

| Agent | Owns | Ask it to… |
|---|---|---|
| `art-director` | `docs/DESIGN.md` + visual direction | design a page, pick type/color/spacing, critique how something looks |
| `editor` | `content/` + every word on the site | write or trim copy, curate the project list, draft blog posts |
| `builder` | site code within static-first constraints | implement pages/components, keep JS near zero, keep it fast |
| `ops` | `docs/HOSTING.md` + `deploy/` + live AWS config | deploy, manage S3/CloudFront/DNS, fix caching |

Shared rules live in the docs, not in chat:

- `docs/HOSTING.md` — how the site is hosted (static on S3 + CloudFront; verified current AWS state; migration plan; open questions)
- `docs/DESIGN.md` — the design system (seeded; art-director owns it)
- `content/` — all site content as data (editor owns it)

## Stack

TBD — planning phase. Hosting constraints that already pin the choice: **static multi-page output, real URLs, no SPA, near-zero runtime JS** (see `docs/HOSTING.md` §4, D3). Blog math (KaTeX) is **rendered at build time** from markdown (D11). Deployment is a local script — no CI (D4).

## Old site

`~/projects/mysite-2.0` (github.com/awang9999/mysite-2.0) — content source and a catalog of ornamentation to avoid. Do not port its code.
