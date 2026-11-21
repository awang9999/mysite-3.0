#!/usr/bin/env bash
# =============================================================================
# deploy/dns-flip.sh — APEX CUTOVER (TODOS 4.5)
#
# Flips the apex A record:
#   alexander-wang.net  d30bl45vk665e7 (legacy dist)  ->  d1oevywpg7h4uc (main dist)
#
# This is THE cutover moment: after this (plus Route53 propagation, usually
# seconds-to-minutes), the apex serves the 3.0 site. Until then the legacy
# dist keeps serving the old site — nothing is broken if we stop here.
#
# Safety:
#   - Interactive confirmation unless --yes (the cutover orchestrator asks once
#     and passes --yes).
#   - Idempotent: if the record already targets the main dist, it exits 0.
#   - Refuses to run unless the main distribution is "Deployed".
#   - Waits for the Route53 change to reach SUCCESS.
#
# Rollback: re-run with REVERT=1 (flips back to the legacy target). The legacy
# dist/bucket stay in place until decommission.sh, so rollback is instant.
#
# Usage:  ./deploy/dns-flip.sh            # prompts
#         ./deploy/dns-flip.sh --yes      # no prompt (orchestrated)
#         REVERT=1 ./deploy/dns-flip.sh --yes   # roll back the cutover
# =============================================================================
set -Eeuo pipefail

ZONE_ID="${DEPLOY_ZONE_ID:-Z04325761YBHOSD0AF7RH}"
RECORD_NAME="${DEPLOY_APEX_HOST:-alexander-wang.net}."
PROFILE="${AWS_PROFILE:-awang}"
CF_ALIAS_HOSTED_ZONE="Z2FDTNDATAQYW2"          # CloudFront's hosted zone (constant)
NEW_TARGET="${DEPLOY_MAIN_CF:-d1oevywpg7h4uc.cloudfront.net}"   # main dist
OLD_TARGET="${DEPLOY_LEGACY_CF:-d30bl45vk665e7.cloudfront.net}" # legacy dist
WAIT_TIMEOUT_S="${DNS_WAIT_TIMEOUT:-900}"
export AWS_PAGER=""

AUTO_YES=0
[ "${1:-}" = "--yes" ] && AUTO_YES=1

command -v aws >/dev/null || { echo "[dns] aws cli not found" >&2; exit 10; }

if [ "${REVERT:-0}" = "1" ]; then
  TARGET="$OLD_TARGET"; FROM="$NEW_TARGET"; DIRECTION="ROLLBACK (-> legacy)"
else
  TARGET="$NEW_TARGET"; FROM="$OLD_TARGET"; DIRECTION="CUTOVER (-> main)"
fi

echo "[dns] direction: $DIRECTION"
echo "[dns] record:  $RECORD_NAME (zone $ZONE_ID)"
echo "[dns] target:  $FROM  ->  $TARGET"

# --- Pre-flight: main dist must be Deployed (only for forward cutover) --------
if [ "${REVERT:-0}" != "1" ]; then
  STATUS="$(aws cloudfront get-distribution --id "${DEPLOY_DIST_ID:-E91NPMQZ9M9NQ}" \
    --profile "$PROFILE" --query 'Distribution.Status' --output text)"
  [ "$STATUS" = "Deployed" ] || { echo "[dns][ERROR] main dist not Deployed (status=$STATUS) — run cfn-configure.sh first" >&2; exit 11; }
fi

# --- Idempotency: read the current alias target -------------------------------
CURRENT="$(aws route53 list-resource-record-sets \
  --hosted-zone-id "$ZONE_ID" --profile "$PROFILE" \
  --query "ResourceRecordSets[?Name=='$RECORD_NAME' && Type=='A'].AliasTarget.DNSName | [0]" \
  --output text 2>/dev/null || true)"
CURRENT="${CURRENT#None}"
CURRENT="${CURRENT%.}"   # Route53 returns a trailing dot; targets don't carry one

if [ -n "$CURRENT" ] && [ "$CURRENT" = "$TARGET" ]; then
  echo "[dns] Record already points at $TARGET — nothing to do."
  exit 0
fi
echo "[dns] current: ${CURRENT:-<not found>}"

# --- Confirmation gate ---------------------------------------------------------
if [ "$AUTO_YES" != "1" ]; then
  printf '[dns] THIS FLIPS PRODUCTION DNS. Continue? (type "yes" to proceed): '
  read -r ANSWER
  [ "$ANSWER" = "yes" ] || { echo "[dns] Aborted."; exit 1; }
fi

# --- Issue the change ----------------------------------------------------------
CHANGE_FILE="$(mktemp)"
trap 'rm -f "$CHANGE_FILE"' EXIT
cat > "$CHANGE_FILE" <<EOF
{
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "$RECORD_NAME",
        "Type": "A",
        "SetIdentifier": "apex-cloudfront",
        "AliasTarget": {
          "HostedZoneId": "$CF_ALIAS_HOSTED_ZONE",
          "DNSName": "$TARGET.",
          "EvaluateTargetHealth": false
        }
      }
    }
  ]
}
EOF

CHANGE_ID="$(aws route53 change-resource-record-sets \
  --hosted-zone-id "$ZONE_ID" \
  --change-batch "file://$CHANGE_FILE" \
  --profile "$PROFILE" \
  --query 'ChangeInfo.Id' --output text)" || { echo "[dns][ERROR] change-resource-record-sets failed" >&2; exit 12; }
echo "[dns] Change $CHANGE_ID submitted. Waiting for SUCCESS (timeout ${WAIT_TIMEOUT_S}s)…"

STATUS=""
for _ in $(seq 1 "$((WAIT_TIMEOUT_S / 10))"); do
  STATUS="$(aws route53 get-change --id "$CHANGE_ID" --profile "$PROFILE" \
    --query 'ChangeInfo.Status' --output text)"
  [ "$STATUS" = "SUCCESS" ] && break
  sleep 10
done
[ "$STATUS" = "SUCCESS" ] || { echo "[dns][ERROR] change not SUCCESS (status=$STATUS)" >&2; exit 13; }

echo "[dns] OK — $RECORD_NAME now points at $TARGET ($DIRECTION)."
echo "[dns] DNS propagation is typically seconds-to-minutes. Verify with verify-live.sh."
