# Hosting Design — mysite-3.0

**Status:** Draft v1 · **Owner:** `ops` agent · **Last verified against live AWS state:** 2026-11-20
**Confirmed by owner:** canonical host is the apex (2026-11-20) — see D2

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
| CloudFront (apex, legacy) | `E96YWX7J3SY11` → `d30bl45vk665e7.cloudfront.net` | Origin: legacy apex bucket's website endpoint. Alias: `alexander-wang.net`. |
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
                       ┌──────────────────────▼──────────────────────┐
                       │        CloudFront (ONE distribution)        │
                       │  • aliases: apex + www                      │
                       │  • www behavior → 301 redirect to apex      │
                       │  • ACM cert, TLS ≥ 1.2, HSTS                │
                       │  • response-headers policy (security hdrs)  │
                       │  • origin request: OAC → private bucket     │
                       └──────────────────────┬──────────────────────┘
                                              │
                       ┌──────────────────────▼──────────────────────┐
                       │   S3  www.alexander-wang.net  (private)     │
                       │   • versioning ON (rollback)                │
                       │   • 404.html error document                 │
                       │   • two-tier cache headers (see §5)         │
                       └─────────────────────────────────────────────┘

  Deploy: GitHub Actions on push to main
          build → s3 sync (two-tier) → CloudFront invalidate /* → verify
```

**One bucket, one distribution, both hostnames.** The legacy apex bucket and distribution are removed after cutover (§6).

### Why this shape

- **Static multi-page site ⇒ no SPA fallback needed.** Every page is a real URL backed by a real `.html` file, plus one `404.html`. This is what lets the whole origin be "just S3 files" — no rewrite rules, no behavior on missing paths, cleanest possible cache.
- **One distribution** removes the legacy split-brain (two buckets, two distributions, two sets of config to keep in sync). One cert, one set of headers, one invalidation per deploy.
- **Keep the existing bucket** (`www.alexander-wang.net`): it's already private with an OAI-restricted policy, and reusing it means zero bucket-level migration risk. (Open question §8: fresh bucket name is possible but buys nothing.)

## 4. Key decisions

| # | Decision | Rationale |
|---|---|---|
| D1 | Single bucket + single CloudFront distribution serving both apex and www | Eliminates the legacy two-bucket/two-distribution split; one place to configure headers, cert, cache |
| D2 | ✅ **CONFIRMED (2026-11-20)** Canonical host: **apex** `alexander-wang.net`; `www` 301-redirects to apex | Shorter, cleaner URLs. Implemented at the edge (CloudFront per-alias redirect on the www behavior) — no S3 or app involvement. |
| D3 | Multi-page static output (MPP), real URLs, `404.html`, **no SPA** | Hosting stays trivially simple; SEO and deep-linking work with zero config; cache is fully effective |
| D4 | Deploy via **GitHub Actions on push to `main`** (repo already lives on GitHub) | Free, zero extra account to maintain, replaces CircleCI (paid per seat, and its pipeline never invalidated the CDN). Manual `deploy/` script kept as an escape hatch |
| D5 | Two-tier cache: hashed assets `immutable, max-age=31536000`; HTML `no-cache, no-store, must-revalidate` | Same strategy that works today: assets cache forever (content-hashed names), HTML always revalidates so new deploys are visible after invalidation |
| D6 | Private origin: bucket stays private, CloudFront accesses it via OAI (existing `E3PV3Z1GIPWEQ0`) or a new OAC | Direct `https://www.alexander-wang.net.s3…` access returns 403; only the edge can read content. Never public-read S3 |
| D7 | Security headers at the edge via a CloudFront *response headers policy*: `Strict-Transport-Security`, `X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin` | One config point, applies to every object, no per-object work |
| D8 | Enable **S3 versioning** | ~free at this scale; gives point-in-time rollback of a bad deploy without touching the live site |
| D9 | No WAF, no Lambda@Edge, no image-optimization service | YAGNI for a personal site with no secrets and build-time image optimization. Revisit only if a concrete need appears |

## 5. Caching & deploy mechanics

**Cache tiers (set as S3 object headers at deploy time):**

| Files | Cache-Control | Why |
|---|---|---|
| `/assets/*` (JS/CSS/fonts/images — content-hashed names) | `public, max-age=31536000, immutable` | A given hash never changes; cache for a year at edge and in browsers |
| `*.html`, `manifest.json`, `robots.txt`, `favicon*` | `no-cache, no-store, must-revalidate` | Entry points must always revalidate so new deploys land immediately |

**Deploy sequence (GitHub Actions job `deploy`):**

1. `npm ci && npm run build` → static output (HTML + hashed assets)
2. `aws s3 sync` assets → bucket (`--delete --exact-timestamps`, long cache)
3. `aws s3 sync` HTML → bucket (`no-cache` headers)
4. `aws s3` copy `404.html` (or ensure it's present with the right headers)
5. `aws cloudfront create-invalidation --paths "/*"` (1 path; free tier is 1,000/month — we'll do < 50)
6. **Verify through the edge:** `curl -sI https://alexander-wang.net/` (200, correct cache headers), a known 404 path, and the `www` → apex redirect. Fail the workflow on any mismatch.

**Rollback:** S3 versioning → restore the previous object versions (documented one-liner in `deploy/`), then invalidate `/*`. Target: < 5 minutes.

## 6. Migration plan (mysite-2.0 → 3.0, high level)

Ordered so the live site keeps working at every step; no DNS outage expected (alias records flip atomically per-record).

1. **Build & verify 3.0 locally** (done in the normal dev loop).
2. **Configure the target state on the existing www distribution (`E91NPMQZ9M9NQ`):** add the apex alias + ACM cert coverage, add the www→apex 301 behavior, attach the response-headers policy. (Apex cert: confirm the existing ACM cert covers both names; if not, request it — takes minutes.)
3. **Enable S3 versioning** on `www.alexander-wang.net`.
4. **Deploy the 3.0 build** to `www.alexander-wang.net` via the new GitHub Actions workflow. **This replaces the live site on `www`** — the cutover moment.
5. **Flip DNS:** point the apex alias A record at `d1oevywpg7h4uc.cloudfront.net` (replacing `d30bl45vk665e7`). Alias records propagate within seconds to minutes.
6. **Verify:** apex serves 3.0, www 301s to apex, 404s work, direct bucket URLs 403, cache headers correct.
7. **Decommission (after a soak period):** delete legacy distribution `E96YWX7J3SY11`, empty + delete legacy bucket `alexander-wang.net`, delete the CircleCI project, retire the old `deploy.sh` in mysite-2.0.

**Risk notes:** step 4 replaces www content before step 5 flips apex — for the gap between them, apex still shows 2.0 and www shows 3.0. Both work; no broken state. If anything is wrong, revert step 4 via S3 versioning and step 5 by re-pointing the alias.

## 7. Cost estimate (steady state)

| Item | Est. monthly |
|---|---|
| Route53 hosted zone (existing) | $0.50 |
| S3 storage + requests (~50 MB, low traffic) | ~$0.01 |
| CloudFront data transfer (free-tier-eligible at this scale) | ~$0 |
| CloudFront invalidations (< 50/month, limit 1,000) | $0 |
| GitHub Actions (2,000 free min/month on private repo; deploys use ~2 min) | $0 |
| ACM | $0 |
| **Total** | **~$0.50–1/month** |

## 8. Open questions (need owner)

1. **Bucket:** reuse `www.alexander-wang.net` (recommended) or create a fresh bucket for a clean break?
2. **CircleCI:** confirm retirement (recommended) — does any other project still use that account?
3. **Blog math:** the 2.0 blog has a KaTeX-based matrix-calculus series. If those posts come over, math must render **at build time** (keeps runtime JS near zero). Affects the stack/content pipeline, not hosting — parked until the content plan is set.
4. **HSTS preload:** enable HSTS at cutover (recommended); add to the HSTS preload list later once headers are verified in the wild.

## 9. Verification checklist (per deploy, automated in CI)

- [ ] `curl -sI` homepage: `200`, `Content-Type: text/html`, `Cache-Control: no-cache…`
- [ ] A hashed asset: `Cache-Control: public, max-age=31536000, immutable`
- [ ] `www` host: `301` → same path on apex
- [ ] Unknown path: `404` with the custom `404.html`
- [ ] `HSTS`, `X-Content-Type-Options`, `Referrer-Policy` headers present
- [ ] Direct S3 object URL (via OAI-less request): `403`
- [ ] Invalidation status `Completed` before the workflow exits
