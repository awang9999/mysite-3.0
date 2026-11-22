# Hosting Design — mysite-3.0

**Status:** v1 — all owner decisions locked (2026-11-20)
**Owner:** `ops` agent · **Last verified against live AWS state:** 2026-11-20

---

## 1. Goals

1. **Static and stays static.** Plain HTML/CSS/JS files. No server, no functions, no database, no runtime of any kind.
2. **Boring technology.** Infrastructure that is rarely touched, never on-call, and well documented.
3. **Fast.** Global edge caching via CDN; long-lived cache for content-hashed assets; small pages.
4. **Cheap.** ~$1/month all-in.
5. **One-command deploy.** Push to `main` → live at the edge in a few minutes, no human steps.
6. **Secure by default.** TLS everywhere, private origin, least-privilege access, sane security headers.

## 2. Current state (inherited from mysite-2.0)

Verified live on 2026-11-20 with the `awang` CLI profile (account `488985706349`).

| Resource | Current value | Notes |
|---|---|---|
| Domain | `alexander-wang.net` | Route53 hosted zone `Z04325761YBHOSD0AF7RH` |
| S3 bucket (main) | `www.alexander-wang.net` (us-west-1) | Private. Public access block fully on. Bucket policy allows `s3:GetObject` **only** to CloudFront OAI `E3PV3Z1GIPWEQ0`. No versioning. |
| S3 bucket (legacy apex) | `alexander-wang.net` (us-west-1) | Served via the S3 *static-website* endpoint. Redundant — slated for decommission (§6). |
| CloudFront (www) | `E91NPMQZ9M9NQ` → `d1oevywpg7h4uc.cloudfront.net` | Origin: `www.alexander-wang.net` bucket. Alias: `www.alexander-wang.net`. TLS ≥ 1.2 (2021). No WAF. |
| CloudFront (apex, legacy) | `E96YWX7J3SY11` → `d30bl45vk665e7.cloudfront.net` | Origin: legacy apex bucket's website endpoint (until the cutover repoints it to the 3.0 bucket — §6). Alias: `alexander-wang.net`. **Stays after cutover — it serves the apex.** |
| DNS | `www` → `d1oevywpg7h4uc` (alias A) · apex → `d30bl45vk665e7` (alias A) | Apex and www are served by **two different distributions and two different buckets** — a legacy split. |
| Unrelated | `E2F96O5L3ZEDKQ` (hearts game, us-west-2) | Out of scope — do not touch. |
| Old CI | CircleCI, triggered on `live` branch | Builds + `s3 sync`, but **never invalidates CloudFront** (known gap). To be retired. |
| Old manual deploy | `deploy.sh` in mysite-2.0 | Two-tier cache sync + `/*` invalidation. The behavior we keep, the script we rewrite. |

**Known docs bug (mysite-2.0):** `DEPLOYMENT.md` uses `d1oevywpg7h4uc` as a `--distribution-id` in several commands. That string is the distribution's **domain**, not its ID — the real ID is `E91NPMQZ9M9NQ` (as in `deploy.sh`). Verify against live state; don't trust the old doc.

## 3. Target architecture

```
                       ┌─────────────────────────────────────────────┐
                       │              Route 53                       │
  apex:                │  alexander-wang.net ──┐                     │
  www:                 │  www.alexander-       │   alias A records   │
  alexander-wang.net   │      wang.net ────────┘                     │
                       └──────────────────────┬──────────────────────┘
                                              │
            ┌─────────────────────┴─────────────────────┐
            │                                           │
   ┌────────▼──────────────────────────┐  ┌─────────────▼──────────────────────┐
   │  CloudFront — MAIN dist           │  │  CloudFront — LEGACY dist (apex)   │
   │  E91NPMQZ9M9NQ (www)              │  │  E96YWX7J3SY11                     │
   │  alias: www.alexander-wang.net    │  │  alias: alexander-wang.net (apex)  │
   └───────────────────────────────────┘  └────────────────────────────────────┘
   Both dists: same ACM cert (43e7d0e9), response-headers policy (HSTS,
   nosniff, referrer), 404 → 404.html custom error response, OAI access,
   both hostnames serve 200 (no static host-based 301 exists in CloudFront).
   The legacy dist's ORIGIN is repointed from the 2.0 bucket to the 3.0
   bucket at cutover (§6) — its alias and the DNS record never move.
                                              │
                       ┌──────────────────────▼──────────────────────┐
                                              │
                       ┌──────────────────────▼──────────────────────┐
                       │   S3  www.alexander-wang.net  (private)     │
                       │   • versioning ON (rollback)                │
                       │   • 404.html object (CloudFront serves it)  │
                       │   • two-tier cache headers (see §5)         │
                       └─────────────────────────────────────────────┘

  Deploy: local script (deploy/deploy.sh) — no CI (owner decision)
          build → s3 sync (two-tier) → CloudFront invalidate /* → verify
```

**One bucket, both hostnames.** The legacy apex *bucket* is orphaned at cutover and removed after the soak period (§6); the legacy *distribution* stays — it serves the apex.

### Why this shape

- **Static multi-page site ⇒ no SPA fallback needed.** Every page is a real URL backed by a real `.html` file, plus one `404.html`. This is what lets the whole origin be "just S3 files" — no rewrite rules, no behavior on missing paths, cleanest possible cache.
- **One distribution** removes the legacy split-brain (two buckets, two distributions, two sets of config to keep in sync). One cert, one set of headers, one invalidation per deploy.
- **Keep the existing bucket** (`www.alexander-wang.net`): it's already private with an OAI-restricted policy, and reusing it means zero bucket-level migration risk. (Open question §8: fresh bucket name is possible but buys nothing.)

## 4. Key decisions

| # | Decision | Rationale |
|---|---|---|
| D1 | ✅ **CONFIRMED, mechanism amended (2026-11-22)** Single bucket (`www.alexander-wang.net`, reused) + **two** CloudFront distributions: www on the main dist, apex on the legacy dist whose **origin is repointed** to the same bucket at cutover | Original plan (one dist, both aliases) is impossible: the apex CNAME already sits on the legacy dist and CloudFront rejects the same CNAME on two dists (`CNAMEAlreadyExists`); moving it = 1–2 h downtime. Repointing the origin instead: zero downtime, zero DNS change, both dists share one bucket + one cert (43e7d0e9). The legacy dist therefore STAYS (it is the apex's home); only the orphaned 2.0 *bucket* is decommissioned |
| D2 | ✅ **CONFIRMED (2026-11-20), mechanism amended (2026-11-21)** Canonical host: **apex** `alexander-wang.net`; `www` **serves 200, canonical tags point at apex** | Shorter, cleaner URLs. **Amendment:** a static www→apex 301 is impossible in CloudFront (behaviors branch on path, not host — both names arrive with identical paths); the only 301 route is a Lambda@Edge, which D9 excludes. So: one distribution serves both aliases (200); every page's `<link rel="canonical">` targets apex. `deploy.sh` keeps a `WWW_MODE=redirect` verification path if a Lambda@Edge 301 is ever wanted. |
| D3 | Multi-page static output (MPP), real URLs, `404.html`, **no SPA** | Hosting stays trivially simple; SEO and deep-linking work with zero config; cache is fully effective |
| D4 | ✅ **CONFIRMED** Deploy = **a single local script** (`deploy/deploy.sh`), **no CI for now** — CircleCI fully retired. **Door left open for GitHub Actions later.** | Owner preference: a personal site doesn't need a CI pipeline today. One command does build → two-tier sync → invalidate → verify. Replaces CircleCI (paid per seat, and its pipeline never even invalidated the CDN). The script is written **CI-ready**: non-interactive, idempotent, meaningful exit codes, AWS auth via standard profile/env — so adding a GitHub Actions workflow later is a thin wrapper (job runs the same script with OIDC-issued credentials), not a rewrite. |
| D5 | Two-tier cache: hashed assets `immutable, max-age=31536000`; HTML `no-cache, no-store, must-revalidate` | Same strategy that works today: assets cache forever (content-hashed names), HTML always revalidates so new deploys are visible after invalidation |
| D6 | Private origin: bucket stays private, CloudFront accesses it via OAI (existing `E3PV3Z1GIPWEQ0`) or a new OAC | Direct `https://www.alexander-wang.net.s3…` access returns 403; only the edge can read content. Never public-read S3 |
| D7 | ✅ **CONFIRMED** Security headers at the edge via a CloudFront *response headers policy*: `Strict-Transport-Security`, `X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin` | One config point, applies to every object. HSTS = header instructing browsers to always use HTTPS for this domain (blocks protocol-downgrade attacks); enabled with a moderate max-age at cutover, preload list later. |
| D8 | Enable **S3 versioning** | ~free at this scale; gives point-in-time rollback of a bad deploy without touching the live site |
| D9 | No WAF, no Lambda@Edge, no image-optimization service | YAGNI for a personal site with no secrets and build-time image optimization. Revisit only if a concrete need appears |
| D10 | ✅ **CONFIRMED** Old 2.0 site **archived at `/old/`** on the same bucket, linked from the 3.0 footer, removed later at the owner's word | No new infrastructure: rebuild 2.0 with `PUBLIC_URL=/old` (+ one-line router `basename="/old"`), sync to `s3://…/old/`. Only ~5 routes, so deep links work by copying `index.html` to those paths. Temporary by design. |
| D11 | ✅ **CONFIRMED** Blog math is **rendered at build time by KaTeX** — output is plain HTML + KaTeX CSS/fonts; no runtime math JS. Renderer chosen over **LaTeX→SVG** (a TeX distribution is too heavy a build dependency; the series already renders in KaTeX on 2.0, so compatibility is proven) and **MathJax-static** (heavier payload, awkward setup). Safety valve: per-equation SVG fallback if a future post needs a LaTeX package KaTeX lacks | Owner writes markdown; the build handles math. No visual parity with 2.0 required (images/styling are free rein). |
| D12 | ✅ **CONFIRMED (2026-11-21)** SSG stack: **Astro** (v7) | Every HOSTING/DESIGN constraint maps to a stock Astro feature: MPP real URLs (D3), zero JS by default (DESIGN §10), typed Content Collections for the `content/` frontmatter, `@astrojs/katex` (D11), built-in content-hashed assets (D5), built-in `dev`/`build`/preview (§10). Alternatives considered: Eleventy 3 (assemble hashing + KaTeX yourself), Hugo (Go-template friction + content remap). |

## 5. Caching & deploy mechanics

**Cache tiers (set as S3 object headers at deploy time):**

| Files | Cache-Control | Why |
|---|---|---|
| `/assets/*` (JS/CSS/fonts/images — content-hashed names) | `public, max-age=31536000, immutable` | A given hash never changes; cache for a year at edge and in browsers |
| `*.html`, `manifest.json`, `robots.txt`, `favicon*` | `no-cache, no-store, must-revalidate` | Entry points must always revalidate so new deploys land immediately |

**Deploy sequence (one command, run by `deploy/deploy.sh` — no CI for now; if GitHub Actions is added later, its deploy job simply runs this same script with OIDC credentials):**

1. `npm ci && npm run build` → static output (HTML + hashed assets; blog markdown → HTML with KaTeX rendered at build time)
2. `aws s3 sync` assets → bucket (`--delete --exact-timestamps`, long cache)
3. `aws s3 sync` HTML → bucket (`no-cache` headers)
4. `aws s3` copy `404.html` (or ensure it's present with the right headers)
5. `aws cloudfront create-invalidation --paths "/*"` (1 path; free tier is 1,000/month — we'll do < 50)
6. **Verify through the edge:** `curl -sI https://alexander-wang.net/` (200, correct cache headers), a known 404 path, and the `www` → apex redirect. Fail the workflow on any mismatch.

**Rollback:** S3 versioning → restore the previous object versions (documented one-liner in `deploy/`), then invalidate `/*`. Target: < 5 minutes.

## 6. Migration plan (mysite-2.0 → 3.0) — **as implemented in deploy/**

Ordered so the live site keeps working at every step. **No DNS change ever
happens** (see the D1 amendment): the apex keeps its alias on the legacy
dist; we repoint that dist's *origin* and then swap the bucket's content.

1. **Build & verify 3.0 locally** (done in the normal dev loop).
2. **`s3-versioning.sh`** — enable versioning on `www.alexander-wang.net` (rollback lever).
3. **`cfn-configure.sh`** — response-headers policy (HSTS, nosniff, referrer) + 404 → `404.html` custom error response on **both** dists; create an OAI for the legacy dist, grant it in the bucket policy, and **repoint the legacy dist's origin** from the 2.0 website endpoint to the 3.0 bucket. Waits for both dists to be `Deployed`. *Nothing visible changes yet.*
4. **`archive-2.0.sh`** — rebuild 2.0 as the `/old/` archive (basename + deep-link fallbacks), local only.
5. **`deploy.sh`** — **the cutover** (gated in `cutover.sh`): build → snapshot bucket versions → sync 3.0 + `/old/` → two-tier cache headers → invalidate `/*` on **both** dists → verify **both** hostnames. After ~1–15 min both `alexander-wang.net` and `www.alexander-wang.net` serve 3.0. `DEPLOY_IS_CUTOVER=1` stamps `deploy/.cutover-at` (the decommission soak clock).
6. **`verify-live.sh`** — 9 checks: 3.0 on apex, cache + security headers, 404 page, canonical → apex, www mode, `/old/` + `/old/blog/`, direct-S3 403.
7. **Decommission (after ≥ 7 days soak):** `decommission.sh` — delete the **orphaned 2.0 bucket** `alexander-wang.net`, retire CircleCI. **The legacy dist stays** (it serves the apex).
8. **Later, at the owner's word:** remove `/old/` (delete `old-archive/`, unset `OLD_ARCHIVE_DIR`, redeploy) and drop the footer link.

**Rollback (any time before decommission):** `rollback.sh` restores the exact pre-deploy bucket state from `deploy/.pre-cutover-versions.json` (S3 versioning), re-invalidates both edges, sanity-checks. Re-cutover: `deploy.sh`. The origin repoint needs no undoing — the apex dist serves the bucket, so a restored bucket shows the old site on both hostnames.

**Risk notes:** between steps 3 and 5 nothing is visible — the legacy dist's edge cache still holds 2.0 and the bucket still contains 2.0. The only moment of change is step 5's invalidation, which completes in minutes. The old 2.0 site stays fully intact (old bucket + `/old/` archive + S3 versions) until decommission, so the cutover is reversible well past "deploy failed".

## 7. Cost estimate (steady state)

| Item | Est. monthly |
|---|---|
| Route53 hosted zone (existing) | $0.50 |
| S3 storage + requests (~50 MB, low traffic) | ~$0.01 |
| CloudFront data transfer (free-tier-eligible at this scale) | ~$0 |
| CloudFront invalidations (< 50/month, limit 1,000) | $0 |
| ACM | $0 |
| **Total** | **~$0.50–1/month** |

## 8. Decisions log (all resolved 2026-11-21)

1. Canonical host: **apex** — www serves 200, canonical tags → apex (D2 amendment)
2. Bucket: **reuse** `www.alexander-wang.net` (D1)
3. CI: **retire CircleCI entirely; deploy = local script** (D4)
4. Blog math: **migrate the KaTeX matrix-calculus series as markdown, rendered at build time**; no visual parity with 2.0 required (D11)
5. HSTS: **enable at cutover**, preload list later (D7)
6. Archive: **old 2.0 site reachable at `/old/` for a while**, then removed (D10)
7. SSG stack: **Astro** (D12)
8. Math renderer: **KaTeX at build time** — chosen over LaTeX→SVG and MathJax-static; per-equation SVG fallback as escape hatch (D11)

## 9. Verification checklist (per deploy, automated by the deploy script)

- [ ] `curl -sI` homepage: `200`, `Content-Type: text/html`, `Cache-Control: no-cache…`
- [ ] A hashed asset: `Cache-Control: public, max-age=31536000, immutable`
- [ ] `www` host: `200` + apex canonical tag (or `301` → apex if `WWW_MODE=redirect`)
- [ ] Unknown path: `404` with the custom `404.html`
- [ ] `HSTS`, `X-Content-Type-Options`, `Referrer-Policy` headers present
- [ ] Direct S3 object URL (via OAI-less request): `403`
- [ ] Invalidation status `Completed` before the script exits

## 10. Local development & preview (owner requirement)

The site must be runnable locally at all times — the owner previews locally **before every deploy**.

- `npm run dev` — live-edit loop while working (hot reload)
- `npm run build` — produces exactly what gets deployed
- `npm run preview` (or equivalent) — serves the **built output** locally: same URLs, same hashed assets, same `404` behavior. The final pre-deploy check must be against the build artifact, not just the dev server — a dev-only preview can mask asset-path, routing, and 404 problems.

Preview must need **no AWS credentials** and never touch live infrastructure.
