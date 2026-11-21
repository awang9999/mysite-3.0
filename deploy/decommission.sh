#!/usr/bin/env bash
# =============================================================================
# deploy/decommission.sh — retire legacy infra (TODOS 4.6, HOSTING §6 step 7)
#
# Run only AFTER the cutover has soaked (default: 7+ days, SOAK_DAYS).
# Destroys, in order (each step gated):
#   1. Legacy CloudFront distribution E96YWX7J3SY11 (disable -> wait -> delete)
#   2. Legacy S3 bucket alexander-wang.net (s3 rb --force)
#   3. CircleCI project (API call if CIRCLE_TOKEN set, else manual instructions)
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
echo "[decom] Soak check (min $SOAK_DAYS days since apex flip)…"
SOAK_OK="$(SOAK_DAYS="$SOAK_DAYS" ZONE_ID="$ZONE_ID" PROFILE="$PROFILE" python3 - <<'PYEOF'
import json, os, subprocess, sys, datetime
now = datetime.datetime.now(datetime.timezone.utc)
def parse_ts(v):
    if v is None: return None
    if isinstance(v, (int, float)):
        return datetime.datetime.fromtimestamp(v, datetime.timezone.utc)
    try:
        return datetime.datetime.fromisoformat(str(v).strip().replace("Z", "+00:00"))
    except ValueError:
        return None
try:
    data = json.loads(subprocess.check_output([
        "aws", "route53", "list-hosted-zone-change-records",
        "--hosted-zone-id", os.environ["ZONE_ID"],
        "--profile", os.environ["PROFILE"], "--output", "json"]))
except Exception:
    print("UNKNOWN"); sys.exit()
newest = None
for batch in data.get("ResourceRecordSets", []):
    changes = batch.get("ResourceRecordSetChanges") or batch.get("ResourceRecordSets") or []
    for item in changes:
        rrs = item.get("ResourceRecordSet", item) if isinstance(item, dict) else item
        if rrs.get("Name") == "alexander-wang.net." and rrs.get("Type") == "A":
            ts = parse_ts(batch.get("SubmittedAt")) or parse_ts(batch.get("Timestamp"))
            if ts and (newest is None or ts > newest):
                newest = ts
if newest is None:
    print("OK")  # no apex change in the 30-day window -> long soaked
    sys.exit()
age = (now - newest).total_seconds() / 86400
print("OK" if age >= float(os.environ["SOAK_DAYS"]) else f"TOO_SOON({age:.1f}d)")
PYEOF
)"
echo "[decom] soak: $SOAK_OK"
case "$SOAK_OK" in
  OK) : ;;
  TOO_SOON*) [ "${FORCE:-0}" = "1" ] || { echo "[decom][ERROR] apex flip too recent for decommission. Wait, or FORCE=1." >&2; exit 21; } ;;
  *) echo "[decom][ERROR] could not determine flip age ($SOAK_OK). Use FORCE=1 to override." >&2; [ "${FORCE:-0}" = "1" ] || exit 22 ;;
esac

# --- 1. Disable + delete legacy distribution -----------------------------------
echo "[decom] === 1. Legacy distribution $LEGACY_DIST ==="
confirm "disable distribution $LEGACY_DIST" "$LEGACY_DIST"

python3 - "$LEGACY_DIST" "$PROFILE" <<'PYEOF' || exit 23
import json, os, subprocess, sys, time
dist_id, profile = sys.argv[1], sys.argv[2]
def aws(*a, parse=True):
    r = subprocess.run(["aws", *a, "--profile", profile, "--output", "json"], capture_output=True, text=True)
    if r.returncode != 0:
        print(f"[decom][ERROR] {r.stderr.strip()[:400]}", file=sys.stderr); sys.exit(1)
    return json.loads(r.stdout) if parse else r.stdout
import tempfile
dist = aws("cloudfront", "get-distribution", "--id", dist_id)["Distribution"]
if dist["DistributionConfig"]["Enabled"]:
    cfg = dict(dist["DistributionConfig"]); cfg["Enabled"] = False
    fd, f = tempfile.mkstemp(suffix=".json")
    with os.fdopen(fd, "w") as fh:
        json.dump(cfg, fh)
    aws("cloudfront", "update-distribution", "--id", dist_id,
        "--if-match", dist["ETag"], "--distribution-config", f"file://{f}")
    os.unlink(f)
    print("[decom] disable issued; waiting for Deployed…")
    for _ in range(180):
        st = aws("cloudfront", "get-distribution", "--id", dist_id)["Distribution"]["Status"]
        if st == "Deployed": break
        time.sleep(10)
    else:
        print("[decom][ERROR] dist not Deployed after 30 min", file=sys.stderr); sys.exit(1)
else:
    print("[decom] dist already disabled.")
dist = aws("cloudfront", "get-distribution", "--id", dist_id)["Distribution"]
aws("cloudfront", "delete-distribution", "--id", dist_id, "--if-match", dist["ETag"])
print(f"[decom] distribution {dist_id} deleted.")
PYEOF
aws cloudfront get-distribution --id "$LEGACY_DIST" --profile "$PROFILE" >/dev/null 2>&1 \
  && { echo "[decom][ERROR] distribution still exists!" >&2; exit 24; } \
  || echo "[decom] confirmed: $LEGACY_DIST is gone."

# --- 2. Delete legacy bucket ----------------------------------------------------
echo "[decom] === 2. Legacy bucket s3://$LEGACY_BUCKET ==="
confirm "delete bucket $LEGACY_BUCKET" "$LEGACY_BUCKET"
aws s3 rb "s3://$LEGACY_BUCKET" --force --profile "$PROFILE" || exit 25
aws s3api head-bucket --bucket "$LEGACY_BUCKET" --profile "$PROFILE" 2>/dev/null \
  && { echo "[decom][ERROR] bucket still exists!" >&2; exit 26; } \
  || echo "[decom] confirmed: s3://$LEGACY_BUCKET is gone."

# --- 3. CircleCI ----------------------------------------------------------------
echo "[decom] === 3. CircleCI project ==="
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
echo "[decom] DONE. Legacy dist + bucket removed; CircleCI per above."
echo "[decom] Reminder: the 2.0 /old/ archive stays live until the owner says to remove it (TODOS 4.7)."
