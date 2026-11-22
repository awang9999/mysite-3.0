#!/usr/bin/env bash
# =============================================================================
# deploy/cutover.sh — Phase 4 orchestrator (ordered, gated, resumable)
#
# Runs the safe half of the cutover in order, then STOPS at the gate and asks
# for explicit confirmation before the cutover moment.
#
# Architecture (zero DNS change — see docs/HOSTING.md §3):
#   The apex keeps its CNAME on the legacy dist (CloudFront forbids the same
#   CNAME on two dists); instead cfn-configure.sh repoints that dist's ORIGIN
#   to the 3.0 bucket. So the cutover is a CONTENT swap: deploy to the bucket
#   + invalidate both edges. Route53 is never touched.
#
# Steps:
#   1. s3-versioning.sh    rollback safety (idempotent)
#   2. cfn-configure.sh    headers+404 on both dists; apex origin repoint
#   3. archive-2.0.sh      build the /old/ archive (local)
#   ── GATE: type "cutover" to swap the live content ──
#   4. deploy.sh           3.0 + /old/ -> bucket, invalidate both edges,
#                          verify apex AND www   (DEPLOY_IS_CUTOVER=1 stamps
#                          deploy/.cutover-at)
#   5. verify-live.sh      full post-cutover verification
#
# Before the gate, nothing visible has changed (both hostnames still serve
# the old site). After step 4, both serve 3.0.
#
# Rollback (any time before decommission):  ./deploy/rollback.sh
#
# Every step is idempotent, so if the run dies midway, just run this again —
# it picks up where it left off.
#
# Then prints the follow-up: decommission.sh after the soak period (7+ days),
# and /old/ removal later at the owner's word (TODOS 4.7).
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

step "1/5  S3 versioning (rollback safety)"                 s3-versioning.sh
step "2/5  CloudFront: headers+404 both dists, repoint apex origin"  cfn-configure.sh
step "3/5  Build 2.0 archive -> old-archive/"               archive-2.0.sh

# --- GATE: the cutover moment (content swap, not a DNS change) -----------------
echo
echo "════════════════════════════════════════════════════════════"
echo "  GATE — CUTOVER (content swap)"
echo "════════════════════════════════════════════════════════════"
echo "  Nothing visible has changed yet: BOTH hostnames still serve the"
echo "  old site. The next step deploys 3.0 + /old/ to the live bucket and"
echo "  invalidates both CloudFront edges — after ~1-15 min BOTH"
echo "  https://alexander-wang.net and https://www.alexander-wang.net serve"
echo "  3.0. No DNS change is involved (the apex origin was already repointed)."
echo "  Rollback any time before decommission:  ./deploy/rollback.sh"
if [ "$DRY" = "1" ]; then
  echo "  (dry-run) would wait for confirmation, then run:"
  echo "             DEPLOY_IS_CUTOVER=1 $HERE/deploy.sh"
  echo "             $HERE/verify-live.sh"
  echo "[cutover] dry-run complete."
  exit 0
fi

printf '  Type "cutover" to swap the live content now (or "later" to stop here): '
read -r GATE
case "$GATE" in
  cutover)
    export DEPLOY_IS_CUTOVER=1
    step "4/5  Deploy 3.0 + /old/, invalidate both edges, verify" deploy.sh
    step "5/5  Post-cutover verification"                 verify-live.sh
    echo
    echo "════════════════════════════════════════════════════════════"
    echo "  CUTOVER COMPLETE ✅"
    echo "════════════════════════════════════════════════════════════"
    echo "  Follow-ups (NOT run automatically):"
    echo "   • Soak: give it at least 7 days, then run: $HERE/decommission.sh"
    echo "     (deletes the orphaned 2.0 bucket + retires CircleCI;"
    echo "      the legacy dist STAYS — it now serves the apex)"
    echo "   • /old/ archive removal: only when the owner says so (TODOS 4.7) —"
    echo "     delete old-archive/, unset OLD_ARCHIVE_DIR, redeploy."
    ;;
  *)
    echo "  Stopping before the cutover. Nothing visible has changed:"
    echo "    - Both hostnames still serve the old site."
    echo "    - To finish later: run $HERE/cutover.sh again (resumable)."
    ;;
esac
