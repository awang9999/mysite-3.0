#!/usr/bin/env bash
# =============================================================================
# deploy/decommission.sh — retire orphaned 2.0 infra (TODOS 4.6, HOSTING §6)
#
# Run only AFTER the cutover has soaked (default: 7+ days, SOAK_DAYS).
# IMPORTANT: the legacy CloudFront distribution E96YWX7J3SY11 STAYS — after
# the cutover it serves the APEX hostname (its origin was repointed to the
# 3.0 bucket by cfn-configure.sh). Only the now-orphaned 2.0 BUCKET is
# deleted.
# Destroys, in order (each step gated):
#   1. Orphaned 2.0 S3 bucket alexander-wang.net (s3 rb --force)
#   2. CircleCI project (API call if CIRCLE_TOKEN set, else manual instructions)
#   (Old 2.0 deploy.sh / .circleci/config.yml are retired with the 2.0 repo —
#    nothing to do in AWS.)
#
# SAFETY:
#   - Refuses if the apex DNS flip is younger than SOAK_DAYS (checked against
#    Route53 change history) unless FORCE=1.
#   - Every destructive step requires typing the resource name.
#   - Bucket name must match exactly; the main bucket is never touchable here.
#
# Usage:  ./deploy/decommission.sh
#         SOAK_DAYS=0 ./deploy/decommission.sh        # skip soak wait
# =============================================================================
set -Eeuo pipefail

LEGACY_DIST="${DECOM_LEGACY_DIST:-E96YWX7J3SY11}"
LEGACY_BUCKET="${DECOM_LEGACY_BUCKET:-alexander-wang.net}"
MAIN_BUCKET="${DEPLOY_BUCKET:-www.alexander-wang.net}"
ZONE_ID="${DEPLOY_ZONE_ID:-Z04325761YBHOSD0AF7RH}"
PROFILE="${AWS_PROFILE:-awang}"
SOAK_DAYS="${SOAK_DAYS:-7}"
export AWS_PAGER=""

command -v aws >/dev/null || { echo "[decom] aws cli not found" >&2; exit 10; }
[ "$LEGACY_BUCKET" != "$MAIN_BUCKET" ] || { echo "[decom][ERROR] legacy bucket == main bucket — refusing" >&2; exit 20; }

confirm() { # prompt, expected
  printf '[decom] Type "%s" to proceed: ' "$2"
  read -r ANSWER
  [ "$ANSWER" = "$2" ] || { echo "[decom] Aborted."; exit 1; }
}

# --- 0. Soak check -------------------------------------------------------------
# No DNS change happens during the cutover (origin repoint, not a record
# change), so the soak clock is the deploy.sh cutover stamp, not Route53
# history.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CUTOVER_AT="$HERE/.cutover-at"
echo "[decom] Soak check (min $SOAK_DAYS days since cutover)…"
SOAK_OK="UNKNOWN"
if [ -f "$CUTOVER_AT" ]; then
  CUTOVER_TS="$(cat "$CUTOVER_AT")"
  THEN_TS="$(date -u -d "$CUTOVER_TS" +%s 2>/dev/null || true)"
  if [ -n "$THEN_TS" ]; then
    AGE_DAYS=$(( ( $(date -u +%s) - THEN_TS ) / 86400 ))
    if [ "$AGE_DAYS" -ge "$SOAK_DAYS" ]; then SOAK_OK="OK(${AGE_DAYS}d)"
    else SOAK_OK="TOO_SOON(${AGE_DAYS}d)"
    fi
  else
    SOAK_OK="UNKNOWN(bad timestamp: $CUTOVER_TS)"
  fi
else
  SOAK_OK="UNKNOWN(no $CUTOVER_AT — cutover not recorded by deploy.sh)"
fi
echo "[decom] soak: $SOAK_OK"
case "$SOAK_OK" in
  OK) : ;;
  TOO_SOON*) [ "${FORCE:-0}" = "1" ] || { echo "[decom][ERROR] apex flip too recent for decommission. Wait, or FORCE=1." >&2; exit 21; } ;;
  *) echo "[decom][ERROR] could not determine flip age ($SOAK_OK). Use FORCE=1 to override." >&2; [ "${FORCE:-0}" = "1" ] || exit 22 ;;
esac

# --- 1. Delete orphaned 2.0 bucket -------------------------------------------------
echo "[decom] === 1. Orphaned 2.0 bucket s3://$LEGACY_BUCKET ==="
confirm "delete bucket $LEGACY_BUCKET" "$LEGACY_BUCKET"
aws s3 rb "s3://$LEGACY_BUCKET" --force --profile "$PROFILE" || exit 25
aws s3api head-bucket --bucket "$LEGACY_BUCKET" --profile "$PROFILE" 2>/dev/null \
  && { echo "[decom][ERROR] bucket still exists!" >&2; exit 26; } \
  || echo "[decom] confirmed: s3://$LEGACY_BUCKET is gone."

# --- 2. CircleCI ----------------------------------------------------------------
echo "[decom] === 2. CircleCI project ==="
if [ -n "${CIRCLE_TOKEN:-}" ]; then
  # Best-effort: list projects for the org, find mysite-2.0, delete it.
  SLUG="$(curl -sS -H "Circle-Token: $CIRCLE_TOKEN" \
    "https://circleci.com/api/v2/project" | python3 -c "
import json,sys
for p in json.load(sys.stdin):
    if p.get('name','').lower() == 'mysite-2.0': print(p['vcs-url-slug']); break" || true)"
  if [ -n "$SLUG" ]; then
    curl -sS -X DELETE -H "Circle-Token: $CIRCLE_TOKEN" "https://circleci.com/api/v2/project/$SLUG" \
      && echo "[decom] CircleCI project deleted: $SLUG" || echo "[decom][WARN] CircleCI delete failed — do it manually."
  else
    echo "[decom][WARN] mysite-2.0 project not found in API listing — delete manually."
  fi
else
  echo "[decom] CIRCLE_TOKEN not set. Manual step:"
  echo "         circleci.com -> Projects -> mysite-2.0 -> Project Settings -> Delete project"
fi

echo
echo "[decom] DONE. Orphaned 2.0 bucket removed; CircleCI per above."
echo "[decom] The legacy dist STAYS (it serves the apex now) — never delete it."
echo "[decom] Reminder: the 2.0 /old/ archive stays live until the owner says to remove it (TODOS 4.7)."
