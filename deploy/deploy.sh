#!/usr/bin/env bash
# =============================================================================
# deploy/deploy.sh — one-command deploy for mysite-3.0
#
#   build -> s3 sync (two-tier cache headers) -> cloudfront invalidate -> verify
#
# CI-ready by design (HOSTING D4): non-interactive, idempotent, meaningful
# exit codes, standard AWS auth (AWS_PROFILE / env creds). If a GitHub Actions
# job is added later it simply runs this same script with OIDC credentials —
# no rewrite. See docs/HOSTING.md §5 (mechanics) and §9 (verification).
#
# Usage:
#   ./deploy/deploy.sh
#   DEPLOY_WWW_MODE=redirect ./deploy/deploy.sh   # hard www->apex 301
#
# All config is overridable via env (defaults below) so CI can point it at a
# staging bucket/dist without editing the file.
# =============================================================================
set -Eeuo pipefail

# --- Config (env-overridable) ------------------------------------------------
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT/dist"
BUCKET="${DEPLOY_BUCKET:-www.alexander-wang.net}"
DIST_ID="${DEPLOY_DIST_ID:-E91NPMQZ9M9NQ}"
APEX_HOST="${DEPLOY_APEX_HOST:-alexander-wang.net}"
WWW_HOST="${DEPLOY_WWW_HOST:-www.alexander-wang.net}"
# www handling: "canonical" = both hostnames 200 (recommended, static);
#               "redirect"  = www 301s to apex (requires a Lambda@Edge, D9).
WWW_MODE="${DEPLOY_WWW_MODE:-canonical}"
PROFILE="${AWS_PROFILE:-awang}"
INVAL_TIMEOUT_S="${DEPLOY_INVAL_TIMEOUT:-300}"

# Where the pre-built 2.0 archive lives (copied into dist/old/ before sync).
# Built once by the archive step (TODOS 4.4); gitignored; removed later.
OLD_ARCHIVE_DIR="${OLD_ARCHIVE_DIR:-$ROOT/old-archive}"
# --- Exit codes --------------------------------------------------------------
# 10-12 missing tools · 20-22 build · 30-32 s3 · 40-41 invalidation · 50 verify
log()  { printf '\033[1;34m[deploy]\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m[deploy][ERROR]\033[0m %s\n' "$*" >&2; exit "${2:-1}"; }

export AWS_PAGER=""
command -v aws   >/dev/null 2>&1 || fail "aws cli not found on PATH" 10
command -v node  >/dev/null 2>&1 || fail "node not found on PATH" 11
command -v npm   >/dev/null 2>&1 || fail "npm not found on PATH" 12
command -v curl  >/dev/null 2>&1 || fail "curl not found on PATH" 12

log "target: s3://$BUCKET via dist $DIST_ID (apex=$APEX_HOST, www mode=$WWW_MODE, profile=$PROFILE)"

# --- 1. Build ----------------------------------------------------------------
log "Building (npm ci && npm run build)…"
( cd "$ROOT" && npm ci && npm run build ) || fail "build failed" 20
[ -f "$DIST_DIR/index.html" ] || fail "dist/index.html missing — build produced nothing" 21
[ -f "$DIST_DIR/404.html"  ] || fail "dist/404.html missing (need a 404 page)" 22

# --- 1b. Fold in the 2.0 archive (D10) ---------------------------------------
# The bucket must always be an exact mirror of dist/ so `--delete` prunes
# correctly. If an archive build exists, stage it at dist/old/ first.
if [ -n "$OLD_ARCHIVE_DIR" ] && [ -d "$OLD_ARCHIVE_DIR" ]; then
  log "Staging 2.0 archive -> dist/old/ (from $OLD_ARCHIVE_DIR)…"
  rm -rf "$DIST_DIR/old"
  cp -R "$OLD_ARCHIVE_DIR" "$DIST_DIR/old"
  [ -f "$DIST_DIR/old/index.html" ] || fail "archive missing old/index.html" 23
else
  log "No archive dir at $OLD_ARCHIVE_DIR — deploying without /old/."
fi

# --- 2. Sync (single full mirror, prune stale) --------------------------------
log "Syncing dist/ -> s3://$BUCKET/ (--delete prunes stale)…"
aws s3 sync "$DIST_DIR/" "s3://$BUCKET/" \
  --delete --exact-timestamps --only-show-errors --profile "$PROFILE" \
  || fail "s3 sync failed" 30

# --- 3. Two-tier cache headers (self-copy passes) ----------------------------
# S3 already set correct content-types on upload (extension detection). These
# passes rewrite only Cache-Control, per tier, by copying each object onto
# itself. Entry points always revalidate; hashed assets cache for a year.
NO_CACHE="no-cache, no-store, must-revalidate"
IMMUTABLE="public, max-age=31536000, immutable"

log "Tier 2 (no-cache): *.html, manifest.json, robots.txt, favicon*"
aws s3 cp "s3://$BUCKET/" "s3://$BUCKET/" --recursive --profile "$PROFILE" \
  --exclude "*" \
  --include "*.html" --include "manifest.json" --include "robots.txt" --include "favicon*" \
  --cache-control "$NO_CACHE" --content-type-detect --metadata-directive REPLACE \
  --only-show-errors || fail "no-cache header pass failed" 31

log "Tier 1 (immutable): everything else (content-hashed assets)"
aws s3 cp "s3://$BUCKET/" "s3://$BUCKET/" --recursive --profile "$PROFILE" \
  --exclude "*.html" --exclude "manifest.json" --exclude "robots.txt" --exclude "favicon*" \
  --cache-control "$IMMUTABLE" --content-type-detect --metadata-directive REPLACE \
  --only-show-errors || fail "immutable header pass failed" 32

# --- 4. Invalidate CloudFront -------------------------------------------------
log "Invalidating CloudFront /* on $DIST_ID …"
INVAL_ID="$(aws cloudfront create-invalidation --distribution-id "$DIST_ID" \
  --paths "/*" --profile "$PROFILE" --query 'Invalidation.Id' --output text)" \
  || fail "create-invalidation failed" 40
log "Waiting for invalidation $INVAL_ID (timeout ${INVAL_TIMEOUT_S}s)…"
STATUS="InProgress"
for _ in $(seq 1 "$((INVAL_TIMEOUT_S / 5))"); do
  STATUS="$(aws cloudfront get-invalidation --distribution-id "$DIST_ID" --id "$INVAL_ID" \
    --profile "$PROFILE" --query 'Invalidation.Status' --output text)"
  [ "$STATUS" = "Completed" ] && break
  sleep 5
done
[ "$STATUS" = "Completed" ] || fail "invalidation not Completed in ${INVAL_TIMEOUT_S}s (status=$STATUS)" 41

# --- 5. Verify through the edge (HOSTING §9) ---------------------------------
log "Verifying through the edge…"
rc=0
hdrs() { curl -sS -D - -o /dev/null --max-time 20 "https://$1$2" 2>/dev/null || true; }

check() { # host path want_status [want_cache_substr]
  local host="$1" path="$2" want_status="$3" want_cache="${4:-}"
  local h status cache ct
  h="$(hdrs "$host" "$path")"
  [ -n "$h" ] || { echo "  [FAIL] $host$path: no response"; rc=1; return; }
  status="$(printf '%s' "$h" | head -1 | awk '{print $2}')"
  cache="$(printf '%s' "$h" | grep -i '^cache-control:' | tail -1 | tr -d '\r' | sed 's/^[Cc]ache-[Cc]ontrol: //')"
  ct="$(printf '%s' "$h" | grep -i '^content-type:' | tail -1 | tr -d '\r' | sed 's/^[Cc]ontent-[Tt]ype: //')"
  if [ "$status" != "$want_status" ]; then
    echo "  [FAIL] $host$path -> $status (want $want_status)"; rc=1; return
  fi
  if [ -n "$want_cache" ]; then
    printf '%s' "$cache" | grep -qi -- "$want_cache" \
      || { echo "  [FAIL] $host$path cache='$cache' (want ~$want_cache)"; rc=1; return; }
  fi
  echo "  [ok] $host$path -> $status | cache: ${cache:-<none>} | type: ${ct:-<none>}"
}

# 5a. Homepage: 200, no-cache, text/html
h="$(hdrs "$APEX_HOST" "/")"
check "$APEX_HOST" "/" "200" "no-cache"
printf '%s' "$h" | grep -qi '^content-type: *text/html' \
  || { echo "  [FAIL] homepage content-type not text/html"; rc=1; }

# 5b. A hashed asset: 200, immutable (regular file only — _astro/ has a katex/ subdir)
asset_rel="$(cd "$DIST_DIR" && find _astro -maxdepth 1 -type f 2>/dev/null | head -1)"
if [ -n "$asset_rel" ]; then
  check "$APEX_HOST" "/$asset_rel" "200" "immutable"
else
  echo "  [warn] no _astro/* asset found to check"; rc=1
fi

# 5c. www behavior (depends on WWW_MODE)
if [ "$WWW_MODE" = "redirect" ]; then
  check "$WWW_HOST" "/" "301" ""
else
  check "$WWW_HOST" "/" "200" "no-cache"
fi

# 5d. Unknown path: 404 (custom 404.html via CloudFront custom error response)
check "$APEX_HOST" "/nope-$(date +%s)" "404" ""

# 5e. Security headers on the homepage
for hdr in "strict-transport-security" "x-content-type-options" "referrer-policy"; do
  printf '%s' "$h" | grep -qi "^${hdr}:" \
    || { echo "  [FAIL] homepage missing header: $hdr"; rc=1; }
done

[ "$rc" -eq 0 ] || fail "edge verification FAILED" 50
log "Deploy complete — live at https://$APEX_HOST/  (www mode: $WWW_MODE)"
