# deploy/ — Phase 4 scripts (S3 + CloudFront cutover)

One-command deploy + a full, gated cutover for the apex domain. All scripts
are **non-interactive by default, idempotent (safe to re-run), and exit with
meaningful codes**. Live AWS changes happen only in the scripts marked (AWS).

## Quick start

```bash
./deploy/cutover.sh --dry-run   # see the plan, run nothing
./deploy/cutover.sh             # run the safe half, STOP at the DNS gate,
                                # type "cutover" to flip apex DNS
```

## Scripts

| Script | Does | AWS? | Notes |
|---|---|---|---|
| `cutover.sh` | Orchestrates the sequence below; **gates the DNS flip** behind typed confirmation; supports `--dry-run` | — | Idempotent: re-run to resume after a failure |
| `s3-versioning.sh` | Enables bucket versioning (rollback lever) | ✅ | Run once, before first deploy; idempotent |
| `cfn-configure.sh` | Creates the security-headers policy (HSTS, nosniff, referrer); adds apex alias; attaches policy; adds 404 → `/404.html` custom error response; waits for `Deployed` | ✅ | Idempotent. Cert `43e7d0e9` already covers apex + wildcard |
| `archive-2.0.sh` | Builds the mysite-2.0 site into `old-archive/` (adds router `basename="/old"` temporarily, `PUBLIC_URL=/old`, SPA deep-link `index.html` copies, reverts the source edit) | — | Local only; 2.0 repo left clean; `ARCHIVE_EXCLUDE_VIDEO=1` drops the 26 MB hero video |
| `deploy.sh` | Build 3.0 → stage `old-archive/` into `dist/old/` → `s3 sync --delete` → two-tier cache headers (no-cache entry files / immutable hashed assets) → CloudFront invalidate → edge verify | ✅ | `WWW_MODE=canonical` (default) or `redirect` |
| `dns-flip.sh` | **The cutover**: flips apex A record → main distribution. Prompts unless `--yes`. Waits for Route53 `SUCCESS`. `REVERT=1` rolls back | ✅ | Idempotent; refuses if main dist not `Deployed` |
| `verify-live.sh` | Full post-cutover verification: 3.0 on apex, headers, 404, www mode, `/old/` archive, direct-S3 403 | (read-only) | Exit 0 = all green |
| `decommission.sh` | After the soak (default 7+ days, checked against Route53 history): delete legacy dist `E96YWX7J3SY11`, legacy bucket `alexander-wang.net`, CircleCI project | ✅ | Destructive: type-to-confirm per step, `SOAK_DAYS`/`FORCE` knobs |

## Sequence & reversibility

```
s3-versioning ──> cfn-configure ──> archive-2.0 ──> deploy  ──┐
                                                               │  (www is now 3.0)
                    ┌────────── GATE: type "cutover" ──────────┘
                    ▼
                 dns-flip ──> verify-live        ← apex is now 3.0
                    │
        (soak ≥ 7 days)
                    ▼
               decommission                     ← legacy dist/bucket/CircleCI gone
                    │
        (owner's word)
                    ▼
              remove /old/ (TODOS 4.7)
```

- **Before the gate:** everything is reversible (the legacy dist still serves
  the apex; the bucket has versions).
- **After the flip, before decommission:** rollback is `REVERT=1 dns-flip.sh --yes`
  (instant — the legacy stack is still in place).
- **After decommission:** the legacy stack is gone (the 3.0 site is unaffected;
  only the old-site rollback is lost).

## Env overrides (for CI / staging)

`DEPLOY_BUCKET`, `DEPLOY_DIST_ID`, `DEPLOY_APEX_HOST`, `DEPLOY_WWW_HOST`,
`DEPLOY_WWW_MODE`, `AWS_PROFILE`, `HSTS_VALUE`, `SOAK_DAYS`, `REPO2_DIR`,
`ARCHIVE_OUT`, `ARCHIVE_EXCLUDE_VIDEO`.

## www → apex 301: decision record

CloudFront cannot branch on the Host header with static config, so there is no
pure-static www→apex 301. Chosen: **Option A — no HTTP 301.** Both hostnames
serve 200 from the single distribution; every page's `<link rel="canonical">`
points at the apex (SEO). Option B (a viewer-request Lambda@Edge 301) remains
possible: set `DEPLOY_WWW_MODE=redirect` and add the association in
`cfn-configure.sh` — `deploy.sh`/`verify-live.sh` already verify that mode.
