#!/usr/bin/env bash
# =============================================================================
# deploy/s3-versioning.sh — enable S3 bucket versioning (TODOS 4.3)
#
# Run BEFORE the first cutover deploy so every object uploaded during the
# cutover gets a version — that's the rollback lever if anything goes wrong
# (restore prior versions via the console or aws s3api).
#
# Idempotent: re-running keeps versioning enabled.
# Reversible: aws s3api put-bucket-versioning ... Status=Suspended
#
# Usage:  ./deploy/s3-versioning.sh
# =============================================================================
set -Eeuo pipefail

BUCKET="${DEPLOY_BUCKET:-www.alexander-wang.net}"
PROFILE="${AWS_PROFILE:-awang}"
export AWS_PAGER=""

command -v aws >/dev/null || { echo "[error] aws cli not found" >&2; exit 10; }

echo "[versioning] bucket: $BUCKET (profile: $PROFILE)"

# Safety: never touch the legacy or an unexpected bucket name.
case "$BUCKET" in
  www.alexander-wang.net) : ;;
  *) echo "[error] refusing to enable versioning on unexpected bucket: $BUCKET" >&2; exit 11 ;;
esac

aws s3api put-bucket-versioning \
  --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled \
  --profile "$PROFILE" || exit 12

# Verify
STATUS="$(aws s3api get-bucket-versioning --bucket "$BUCKET" --profile "$PROFILE" --query 'Status' --output text)"
[ "$STATUS" = "Enabled" ] || { echo "[error] versioning not enabled (status=$STATUS)" >&2; exit 13; }
echo "[versioning] OK — $BUCKET versioning is Enabled."
