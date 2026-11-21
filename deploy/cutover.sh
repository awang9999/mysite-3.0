#!/usr/bin/env bash
# =============================================================================
# deploy/cutover.sh — Phase 4 orchestrator (ordered, gated, resumable)
#
# Runs the safe half of the cutover, in order, then STOPS at the DNS flip
# and asks for explicit confirmation before the one irreversible step:
#
#   1. s3-versioning.sh    rollback safety (idempotent)
#   2. cfn-configure.sh    apex alias + headers policy + 404 (idempotent)
#   3. archive-2.0.sh      build the /old/ archive (local)
#   4. deploy.sh           3.0 goes live on www (verify per HOSTING §9)
#   ── GATE: type "cutover" to flip apex DNS ──
#   5. dns-flip.sh --yes   APEX CUTOVER (rollback: REVERT=1 dns-flip.sh)
#   6. verify-live.sh      full post-cutover verification
#
# Then prints the follow-up: decommission.sh after the soak period (7+ days),
# and /old/ removal later at the owner's word (TODOS 4.7).
#
# Every step is idempotent, so if the run dies midway, just run this again —
# it picks up where it left off.
#
# Usage:
#   ./deploy/cutover.sh             # run with the gate
#   ./deploy/cutover.sh --dry-run   # print the steps, run nothing
# =============================================================================
set -Eeuo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1

step() { # label, script, [extra args...]
  echo
  echo "════════════════════════════════════════════════════════════"
  echo "  STEP: $1"
  echo "════════════════════════════════════════════════════════════"
  if [ "$DRY" = "1" ]; then
    echo "  (dry-run) would run: $HERE/$2 ${*:3}"
  else
    "$HERE/$2" "${@:3}"
  fi
}

if [ "$DRY" = "1" ]; then
  echo "[cutover] DRY RUN — nothing will be executed."
fi

step "1/6  S3 versioning (rollback safety)"                s3-versioning.sh
step "2/6  CloudFront: apex alias + headers + 404"        cfn-configure.sh
step "3/6  Build 2.0 archive -> old-archive/"             archive-2.0.sh
step "4/6  Deploy 3.0 + /old/ to S3, invalidate, verify"  deploy.sh

# --- GATE: DNS flip ------------------------------------------------------------
echo
echo "════════════════════════════════════════════════════════════"
echo "  GATE — DNS FLIP (the cutover moment)"
echo "════════════════════════════════════════════════════════════"
echo "  The 3.0 site is live on https://www.alexander-wang.net."
echo "  Flipping apex DNS makes https://alexander-wang.net serve 3.0."
echo "  Until you flip, the apex keeps serving the old site (legacy dist)."
echo "  Rollback after the flip:  REVERT=1 $HERE/dns-flip.sh --yes"
if [ "$DRY" = "1" ]; then
  echo "  (dry-run) would wait for confirmation, then run: $HERE/dns-flip.sh --yes"
  echo "  (dry-run) would run: $HERE/verify-live.sh"
  echo "[cutover] dry-run complete."
  exit 0
fi

printf '  Type "cutover" to flip apex DNS now (or "later" to stop here): '
read -r GATE
case "$GATE" in
  cutover)
    step "5/6  DNS flip: apex -> main distribution"       dns-flip.sh --yes
    sleep 30  # let propagation settle; verify-live has retries via curl
    step "6/6  Post-cutover verification"                 verify-live.sh
    echo
    echo "════════════════════════════════════════════════════════════"
    echo "  CUTOVER COMPLETE ✅"
    echo "════════════════════════════════════════════════════════════"
    echo "  Follow-ups (NOT run automatically):"
    echo "   • Soak: give it at least 7 days, then run: $HERE/decommission.sh"
    echo "     (removes legacy dist E96YWX7J3SY11 + legacy bucket + CircleCI)"
    echo "   • /old/ archive removal: only when the owner says so (TODOS 4.7) —"
    echo "     delete old-archive/, set OLD_ARCHIVE_DIR to nothing, redeploy."
    ;;
  *)
    echo "  Stopping before the DNS flip. Everything deployed so far is safe:"
    echo "    - www is serving 3.0; apex still serves the old site."
    echo "    - To finish the cutover later: run $HERE/dns-flip.sh then verify-live.sh"
    ;;
esac
