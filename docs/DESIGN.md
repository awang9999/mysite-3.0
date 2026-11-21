# Design Direction — mysite-3.0

**Status:** Seed draft — owned by the `art-director` agent, refine on first pass
**Source of truth:** This file. Decisions made anywhere else get written here or they don't exist.

## North Star (from the owner)

> Clean and straight to the point, with subtle design choices that make it comfortable to read and look at.

## Initial principles

1. Whitespace is the primary material.
2. Typography does the design — one font family or one careful pairing, body measure 65–75ch, body line-height ~1.6–1.7, ≤6 type sizes.
3. One accent color on a neutral base (warm grays over blue-grays).
4. Dark mode via `prefers-color-scheme` from day one (tokens, no toggle in v1).
5. Motion is a whisper: opacity/transform only, ≤200ms, `prefers-reduced-motion` respected. Default: none.
6. No element without a job.
7. Consistency beats novelty: same scale and rhythm on every page.

## Hard "do not" list (learned from mysite-2.0)

- No video hero background, no autoplay media of any kind.
- No animated scroll indicators / parallax.
- No icon fonts as decoration.
- No `<hr>` where spacing works.
- No single-page hash-scroll navigation — real pages, real URLs.

## Pages in scope

Home (hero) · About · Experience · Projects (curated featured set + expandable archive) · Blog (index + posts)

## Open (for the art-director)

- Palette + typeface (self-hosted; budget ≤ ~30KB per family per weight set)
- How "expandable" reads for projects (native `<details>`? progressive disclosure on the index? one-line → card?)
- Blog typography, and whether math posts need a special treatment (pending content decision)
- 404 page tone (dry humor allowed once)
