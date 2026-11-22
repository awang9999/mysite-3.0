# deploy/ — Phase 4 hosting & cutover scripts

Local script suite (no CI for now; scripts are CI-ready). All are
**non-interactive, idempotent, and exit with meaningful codes**, so a future
GitHub Actions job can run the same scripts with OIDC credentials.

## The cutover, in one paragraph

The apex hostname's CNAME alias lives on the *legacy* CloudFront
distribution (`E96YWX7J3SY11`), and CloudFront forbids the same CNAME on two
distributions — so the alias never moves. Instead, `cfn-configure.sh`
**repoints the apex dist's origin** from the old 2.0 bucket (website
endpoint) to the 3.0 bucket (private, OAI-locked). From then on both
hostnames are served from the **same bucket**, and the cutover is a pure
**content swap**: deploy to the bucket + invalidate both edges. **Route53 is
never touched; there is no DNS flip and no downtime window.**

| hostname | served by | origin |
|---|---|---|
| `alexander-wang.net` (apex) | legacy dist `E96YWX7J3SY11` (repointed) | `www.alexander-wang.net` bucket |
| `www.alexander-wang.net` | main dist `E91NPMQZ9M9NQ` | `www.alexander-wang.net` bucket |

## Run order

```
./deploy/cutover.sh --dry-run     # read the plan, run nothing
./deploy/cutover.sh               # runs 1-3, stops at the GATE
# ... type "cutover" ...          # runs 4 (the cutover) + 5
```

| # | Script | What it does | Reversible? |
|---|---|---|---|
| 1 | `s3-versioning.sh` | Enable bucket versioning (the rollback lever). Name-locked, idempotent. | suspend versioning |
| 2 | `cfn-configure.sh` | Headers policy (HSTS/nosniff/referrer) + 404→`/404.html` on **both** dists; repoint apex origin to the 3.0 bucket (new OAI + bucket grant). Idempotent. Nothing visible changes. | re-run with repoint undone (see below) |
| 3 | `archive-2.0.sh` | Build the old site as a static archive at `/old/` (basename + deep-link fallbacks). Local only. | trivially |
| 4 | `deploy.sh` | **The cutover.** Build → snapshot bucket versions → sync 3.0 + `/old/` → two-tier cache headers → invalidate `/*` on **both** dists → verify **both** hostnames. With `DEPLOY_IS_CUTOVER=1` stamps `.cutover-at`. | `./deploy/rollback.sh` |
| 5 | `verify-live.sh` | 9 post-cutover checks (content, cache + security headers, 404 page, canonical, www mode, `/old/`, direct-S3 403). | — (read-only) |

Then, **after the soak period** (default 7+ days, checked against
`.cutover-at`):

| Script | What it does |
|---|---|
| `decommission.sh` | Delete the **orphaned 2.0 bucket** `alexander-wang.net` + retire the CircleCI project. **The legacy dist STAYS** — it now serves the apex. Typed confirm per step; `SOAK_DAYS=0` / `FORCE=1` overrides. |

### Rollback (any time before decommission)

```
./deploy/rollback.sh
```

Restores the bucket to the exact state captured in
`deploy/.pre-cutover-versions.json` (written by `deploy.sh` before every
sync), re-invalidates both edges, sanity-checks that the old content is
back. Re-cutover afterwards: `./deploy/deploy.sh`.

Note: step 2's origin repoint does **not** need undoing for a content
rollback — the apex dist serves the 3.0 bucket, so once the bucket holds
the old content again, the apex shows the old site too.

## Environment overrides

`DEPLOY_BUCKET`, `DEPLOY_DIST_IDS` (space-separated; default: both dists),
`DEPLOY_DIST_ID`, `DEPLOY_APEX_DIST_ID`, `DEPLOY_APEX_HOST`,
`DEPLOY_WWW_HOST`, `DEPLOY_WWW_MODE` (canonical\|redirect),
`DEPLOY_ORIGIN_DOMAIN`, `AWS_PROFILE`, `HSTS_MAX_AGE` /
`HSTS_INCLUDE_SUBDOMAINS` / `HSTS_PRELOAD`, `CFN_WAIT_TIMEOUT`,
`DEPLOY_INVAL_TIMEOUT`, `OLD_ARCHIVE_DIR`, `DEPLOY_IS_CUTOVER`,
`SOAK_DAYS`, `FORCE`, `CIRCLE_TOKEN`.

## Decisions recorded here

- **No www→apex 301 (Option A, owner 2026-11-21).** Both hostnames return
  200; `<link rel=canonical>` in the HTML handles SEO. A static 301 on www
  is not possible with plain CloudFront (behaviors branch on path, not
  host) — it would need Lambda@Edge, which contradicts the no-runtime-JS /
  minimal-infra decision (D9). `WWW_MODE=redirect` is kept in `deploy.sh` /
  `verify-live.sh` for the future if that changes.
- **Apex stays on the legacy dist** (2026-11-22). `CNAMEAlreadyExists`
  proves the alias can't be shared between dists; moving it would require a
  1–2 h downtime window (remove from legacy → add to main → wait both
  propagations). Repointing the origin instead: zero downtime, zero DNS
  change, same cert (43e7d0e9 already covers apex + wildcard).
- **Bucket reuse**: `www.alexander-wang.net` remains the single content
  bucket. The old `alexander-wang.net` bucket is orphaned at cutover and
  deleted by `decommission.sh`.
- **HSTS at cutover** via the CloudFront response-headers policy (step 2).
- **`/old/` archive** stays live until the owner says to remove it
  (TODOS 4.7): delete `old-archive/`, unset `OLD_ARCHIVE_DIR`, redeploy.

## AWS CLI v2.34 quirks hit (kept working around them)

- `create-response-headers-policy` takes one `--response-headers-policy-config`
  structure; HSTS/nosniff/referrer must go in the *structured*
  `SecurityHeadersConfig` (they're managed headers, not custom ones).
- Response-headers-policy list items nest under `ResponseHeadersPolicy`,
  name in `…PolicyConfig.Name`, expose `Id` (not `Arn`).
- `get-distribution`: `ETag` is a top-level sibling of `Distribution`.
- OAI commands renamed: `list-cloud-FRONT-origin-access-identities`,
  `create-cloud-FRONT-origin-access-identity` (+ `--cloud-FRONT-…-config`).
- Custom error responses use `ResponsePagePath` (not `ResponsePage`).
- `get-bucket-policy --output json` wraps the document as
  `{"Policy": "<json string>"}`.
- S3 object ARNs: three colons (`arn:aws:s3:::bucket/*`).
