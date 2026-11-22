#!/usr/bin/env bash
# =============================================================================
# deploy/rollback.sh — restore the bucket to its pre-deploy state (TODOS 4.1)
#
# Uses the S3 versioning lever: deploy.sh snapshots the bucket state (key ->
# latest version id) to deploy/.pre-cutover-versions.json BEFORE every sync.
# This script restores that exact state:
#
#   1. For every live key in the manifest: copy the captured version back to
#      current (with its original metadata).
#   2. Delete any current objects the manifest doesn't contain (prunes the
#      newer deploy).
#   3. Invalidate /* on BOTH distributions and wait.
#   4. Sanity-check that the old content is back on both hostnames.
#
# Re-cutover afterwards is just:  ./deploy/deploy.sh
# (The apex dist's repointed origin needs no undo — it serves this bucket;
#  once the bucket is restored, the apex serves the old content too.)
#
# Typed confirmation required (this overwrites the current 3.0 state).
#
# Usage:  ./deploy/rollback.sh
# =============================================================================
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUCKET="${DEPLOY_BUCKET:-www.alexander-wang.net}"
DIST_IDS="${DEPLOY_DIST_IDS:-E91NPMQZ9M9NQ E96YWX7J3SY11}"
APEX_HOST="${DEPLOY_APEX_HOST:-alexander-wang.net}"
WWW_HOST="${DEPLOY_WWW_HOST:-www.alexander-wang.net}"
PROFILE="${AWS_PROFILE:-awang}"
MANIFEST="$ROOT/deploy/.pre-cutover-versions.json"
INVAL_TIMEOUT_S="${DEPLOY_INVAL_TIMEOUT:-300}"
export AWS_PAGER=""

command -v aws   >/dev/null 2>&1 || { echo "[rollback] aws cli not found" >&2; exit 10; }
command -v curl  >/dev/null 2>&1 || { echo "[rollback] curl not found" >&2; exit 10; }
[ -f "$MANIFEST" ] || { echo "[rollback][ERROR] no manifest at $MANIFEST — run deploy.sh first (it writes the snapshot)" >&2; exit 11; }

echo "[rollback] bucket: $BUCKET (profile: $PROFILE)"
echo "[rollback] manifest: $MANIFEST"
LIVE_KEYS="$(python3 -c "import json;print(sum(1 for e in json.load(open('$MANIFEST')) if not e['DeleteMarker']))")"
echo "[rollback] will restore $LIVE_KEYS objects to their captured versions, then prune newer objects"
printf '[rollback] THIS OVERWRITES THE CURRENT SITE STATE. Type "%s" to proceed: ' "$BUCKET"
read -r ANSWER
[ "$ANSWER" = "$BUCKET" ] || { echo "[rollback] Aborted."; exit 1; }

# --- 1+2. Restore state from the manifest ------------------------------------
MANIFEST="$MANIFEST" BUCKET="$BUCKET" PROFILE="$PROFILE" python3 - <<'PYEOF' || exit 20
import json, os, subprocess, sys

bucket  = os.environ["BUCKET"]
profile = os.environ["PROFILE"]
manifest = json.load(open(os.environ["MANIFEST"]))

def aws(*args, check=True):
    r = subprocess.run(["aws", *args, "--profile", profile, "--output", "json"],
                       capture_output=True, text=True)
    if r.returncode != 0 and check:
        print(f"[rollback][ERROR] aws {' '.join(args[:3])}…: {r.stderr.strip()[:300]}", file=sys.stderr)
        sys.exit(1)
    return r

restored = pruned = 0

# 1. Copy each captured version back to current.
for e in manifest:
    if e["DeleteMarker"]:
        continue
    r = aws("s3api", "copy-object",
            "--copy-source", f"{bucket}/{e['Key']}",
            "--copy-source-version-id", e["VersionId"],
            "--bucket", bucket, "--key", e["Key"],
            "--metadata-directive", "COPY")
    restored += 1

# 2. Prune current objects the manifest doesn't contain (as live keys).
live = {e["Key"] for e in manifest if not e["DeleteMarker"]}
marker = ""
while True:
    args = ["s3api", "list-objects-v2", "--bucket", bucket, "--prefix", ""]
    if marker:
        args += ["--continuation-token", marker]
    page = json.loads(aws(*args).stdout or "{}")
    for obj in page.get("Contents", []):
        if obj["Key"] not in live:
            aws("s3api", "delete-object", "--bucket", bucket, "--key", obj["Key"])
            pruned += 1
    if page.get("IsTruncated"):
        marker = page.get("NextContinuationToken", "")
    else:
        break

print(f"[rollback] restored {restored} objects, pruned {pruned} newer objects")
PYEOF

# --- 3. Invalidate both distributions ------------------------------------------
for D in $DIST_IDS; do
  echo "[rollback] Invalidating /* on $D …"
  INVAL_ID="$(aws cloudfront create-invalidation --distribution-id "$D" \
    --paths "/*" --profile "$PROFILE" --query 'Invalidation.Id' --output text)" \
    || { echo "[rollback][ERROR] create-invalidation failed on $D" >&2; exit 30; }
  STATUS="InProgress"
  for _ in $(seq 1 "$((INVAL_TIMEOUT_S / 5))"); do
    STATUS="$(aws cloudfront get-invalidation --distribution-id "$D" --id "$INVAL_ID" \
      --profile "$PROFILE" --query 'Invalidation.Status' --output text)"
    [ "$STATUS" = "Completed" ] && break
    sleep 5
  done
  [ "$STATUS" = "Completed" ] || { echo "[rollback][ERROR] invalidation not Completed on $D (status=$STATUS)" >&2; exit 31; }
done

# --- 4. Sanity check: old content back on both hostnames ------------------------
rc=0
for HOST in "$APEX_HOST" "$WWW_HOST"; do
  CODE="$(curl -sS -o /tmp/rollback-body.$$ -w '%{http_code}' --max-time 20 "https://$HOST/" 2>/dev/null || echo 000)"
  TITLE="$(grep -o "<title>[^<]*</title>" /tmp/rollback-body.$$ 2>/dev/null | head -1 || true)"
  if [ "$CODE" = "200" ] && printf '%s' "$TITLE" | grep -q "Alexander Wang's Portfolio"; then
    echo "  [ok] $HOST -> 200 | $TITLE"
  else
    echo "  [FAIL] $HOST -> $CODE | ${TITLE:-<no title>} (want 2.0 'Alexander Wang's Portfolio')"
    rc=1
  fi
done
rm -f /tmp/rollback-body.$$

[ "$rc" -eq 0 ] || { echo "[rollback] ROLLBACK INCOMPLETE — check the site" >&2; exit 40; }
echo "[rollback] DONE — old content is live again on both hostnames."
echo "[rollback] To re-cutover:  ./deploy/deploy.sh"
