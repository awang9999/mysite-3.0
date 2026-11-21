#!/usr/bin/env bash
# =============================================================================
# deploy/verify-live.sh — full post-cutover verification (TODOS 4.5, HOSTING §9)
#
# Run AFTER the DNS flip (and after deploy.sh has populated the bucket).
# Checks, through the public edge (never via direct S3):
#
#   [3.0 on apex]
#   1.  apex /                200, text/html, no-cache, 3.0 title
#   2.  apex hashed asset     200, immutable cache-control
#   3.  apex unknown path     404, serves the 3.0 404 page
#   4.  apex security headers HSTS + X-Content-Type-Options + Referrer-Policy
#   5.  apex canonical        <link rel=canonical> points at apex
#
#   [www behavior]  (WWW_MODE=canonical: 200 · redirect: 301 -> apex)
#   6.  www /                 expected status per WWW_MODE
#
#   [2.0 archive]
#   7.  /old/                 200, 2.0 title (deep-link index fallback)
#   8.  /old/blog/            200 (SPA route served)
#
#   [containment]
#   9.  direct S3 URL         403 (bucket stays private/OAI-only)
#
# Usage:  ./deploy/verify-live.sh            # WWW_MODE defaults to canonical
#         WWW_MODE=redirect ./deploy/verify-live.sh
# =============================================================================
set -Eeuo pipefail

APEX_HOST="${DEPLOY_APEX_HOST:-alexander-wang.net}"
WWW_HOST="${DEPLOY_WWW_HOST:-www.alexander-wang.net}"
BUCKET="${DEPLOY_BUCKET:-www.alexander-wang.net}"
PROFILE="${AWS_PROFILE:-awang}"
WWW_MODE="${WWW_MODE:-canonical}"
export AWS_PAGER=""

PASS=0; FAIL=0
ok()   { printf '  \033[1;32m[ok]\033[0m   %s\n' "$*"; PASS=$((PASS+1)); }
bad()  { printf '  \033[1;31m[FAIL]\033[0m %s\n' "$*"; FAIL=$((FAIL+1)); }
hdrs() { curl -sS -D - -o /tmp/verify-body.$$ --max-time 20 "$1" 2>/dev/null || true; }
body() { cat /tmp/verify-body.$$ 2>/dev/null || true; }
trap 'rm -f /tmp/verify-body.$$' EXIT

status_of() { printf '%s' "$1" | head -1 | awk '{print $2}'; }
hdr_of()    { printf '%s' "$1" | grep -i "^$2:" | tail -1 | tr -d '\r' | sed -E "s/^$2:[[:space:]]*//I"; }

echo "verify-live: apex=$APEX_HOST www=$WWW_HOST mode=$WWW_MODE"

# --- 1. apex homepage ---------------------------------------------------------
echo "1) apex homepage"
H="$(hdrs "https://$APEX_HOST/")"; B="$(body)"
[ "$(status_of "$H")" = "200" ] && ok "status 200" || bad "status '$(status_of "$H")' (want 200)"
[ "$(hdr_of "$H" content-type)" = "text/html" ] && ok "content-type text/html" || bad "content-type '$(hdr_of "$H" content-type)'"
printf '%s' "$(hdr_of "$H" cache-control)" | grep -qi "no-cache" && ok "no-cache header" || bad "cache-control '$(hdr_of "$H" cache-control)'"
printf '%s' "$B" | grep -q "<title>Alexander Wang</title>" && ok "3.0 title present" || bad "3.0 title missing (old content?)"

# --- 2. apex hashed asset -----------------------------------------------------
echo "2) apex hashed asset"
ASSET="$(find dist/_astro -maxdepth 1 -type f 2>/dev/null | head -1)"
if [ -n "$ASSET" ]; then
  H="$(hdrs "https://$APEX_HOST/$ASSET")"
  [ "$(status_of "$H")" = "200" ] && ok "status 200 ($ASSET)" || bad "status '$(status_of "$H")' for /$ASSET"
  printf '%s' "$(hdr_of "$H" cache-control)" | grep -qi "immutable" && ok "immutable header" || bad "asset cache-control '$(hdr_of "$H" cache-control)'"
else
  bad "no _astro asset found locally (run npm run build first)"
fi

# --- 3. apex 404 --------------------------------------------------------------
echo "3) apex unknown path"
H="$(hdrs "https://$APEX_HOST/nope-$(date +%s)")"; B="$(body)"
[ "$(status_of "$H")" = "404" ] && ok "status 404" || bad "status '$(status_of "$H")' (want 404)"
printf '%s' "$B" | grep -q "404" && ok "serves 3.0 404 page" || bad "404 body is not the 3.0 404 page"

# --- 4. security headers ------------------------------------------------------
echo "4) apex security headers"
H="$(hdrs "https://$APEX_HOST/")"
for h in "strict-transport-security" "x-content-type-options" "referrer-policy"; do
  V="$(hdr_of "$H" "$h")"
  [ -n "$V" ] && ok "$h: $V" || bad "missing header: $h"
done

# --- 5. canonical -------------------------------------------------------------
echo "5) canonical URL"
B="$(body)"
printf '%s' "$B" | grep -o 'rel="canonical"[^>]*href="https://alexander-wang.net[^"]*"' >/dev/null \
  || printf '%s' "$B" | grep -o 'href="https://alexander-wang.net[^"]*"[^>]*rel="canonical"' >/dev/null \
  && ok "canonical points at apex" || bad "apex canonical link missing"

# --- 6. www behavior ----------------------------------------------------------
echo "6) www behavior (mode: $WWW_MODE)"
H="$(hdrs "https://$WWW_HOST/")"
S="$(status_of "$H")"
if [ "$WWW_MODE" = "redirect" ]; then
  [ "$S" = "301" ] && ok "301" || bad "status '$S' (want 301)"
  LOC="$(hdr_of "$H" location)"
  printf '%s' "$LOC" | grep -q "^https://$APEX_HOST/" && ok "Location -> apex" || bad "Location '$LOC'"
else
  [ "$S" = "200" ] && ok "200 (canonical mode)" || bad "status '$S' (want 200)"
fi

# --- 7-8. 2.0 archive ---------------------------------------------------------
echo "7) /old/ (2.0 archive)"
H="$(hdrs "https://$APEX_HOST/old/")"; B="$(body)"
[ "$(status_of "$H")" = "200" ] && ok "status 200" || bad "status '$(status_of "$H")'"
printf '%s' "$B" | grep -q "Alexander Wang's Portfolio" && ok "2.0 title present" || bad "2.0 title missing (archive not deployed?)"
echo "8) /old/blog/ (SPA deep link)"
H="$(hdrs "https://$APEX_HOST/old/blog/")"
[ "$(status_of "$H")" = "200" ] && ok "status 200" || bad "status '$(status_of "$H")'"

# --- 9. containment: direct S3 must be 403 ------------------------------------
echo "9) direct S3 access (must be 403)"
S3_REGION="$(aws s3api get-bucket-location --bucket "$BUCKET" --profile "$PROFILE" --query 'LocationConstraint' --output text 2>/dev/null || true)"
S3_REGION="${S3_REGION:-us-west-1}"   # us-east-1 returns empty
S3URL="https://$BUCKET.s3.$S3_REGION.amazonaws.com/"
CODE="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 15 "$S3URL" 2>/dev/null || echo 000)"
[ "$CODE" = "403" ] && ok "403 (bucket private)" || bad "status '$CODE' (want 403) for $S3URL"

# --- Summary -------------------------------------------------------------------
echo
echo "verify-live: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
echo "verify-live: ALL GREEN"
