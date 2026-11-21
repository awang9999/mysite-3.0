#!/usr/bin/env bash
# =============================================================================
# deploy/cfn-configure.sh — CloudFront cutover config (TODOS 4.2, HOSTING §3/§6)
#
# Configures the MAIN distribution (E91NPMQZ9M9NQ) for the apex cutover:
#   1. Creates a response-headers policy (HSTS, X-Content-Type-Options,
#      Referrer-Policy) — idempotent by name.
#   2. Adds the apex alias (alexander-wang.net) — cert 43e7d0e9 already covers
#      apex + wildcard, so no cert change is needed.
#   3. Attaches the headers policy to the default behavior.
#   4. Adds a custom error response: 404 -> /404.html (serves our 404 page
#      with a real 404 status — the CloudFront-native mechanism for a private
#      S3 origin; an S3 *website* error document does not apply here).
#   5. Waits for the new deployment to reach "Deployed".
#
# Idempotent: safe to re-run (checks before mutating). Does NOT change DNS —
# the site stays on the legacy dist until dns-flip.sh runs.
#
# NOTE on the www 301 (HOSTING §6 step 2): CloudFront cannot branch on the
# Host header with static config, so this script implements Option A —
# apex + www both served (200) by this one distribution; canonical tags in
# the HTML handle SEO. If Option B is ever chosen, add a viewer-request
# Lambda@Edge here (deploy.sh's WWW_MODE=redirect already verifies it).
#
# Usage:  ./deploy/cfn-configure.sh
# =============================================================================
set -Eeuo pipefail

DIST_ID="${DEPLOY_DIST_ID:-E91NPMQZ9M9NQ}"
APEX_HOST="${DEPLOY_APEX_HOST:-alexander-wang.net}"
PROFILE="${AWS_PROFILE:-awang}"
POLICY_NAME="mysite-3-sec-headers"
HSTS_VALUE="${HSTS_VALUE:-max-age=31536000; includeSubDomains}"
WAIT_TIMEOUT_S="${CFN_WAIT_TIMEOUT:-2700}"
export AWS_PAGER="" DIST_ID APEX_HOST PROFILE POLICY_NAME HSTS_VALUE

command -v aws >/dev/null || { echo "[cfn] aws cli not found" >&2; exit 10; }
command -v python3 >/dev/null || { echo "[cfn] python3 not found" >&2; exit 11; }

echo "[cfn] distribution: $DIST_ID (profile: $PROFILE)"

# --- 1. Response-headers policy (idempotent by name) --------------------------
echo "[cfn] Ensuring response-headers policy '$POLICY_NAME'…"
POLICY_ARN="$(aws cloudfront list-response-headers-policies --region us-east-1 --profile "$PROFILE" \
  --query "ResponseHeadersPolicyList.Items[?Name=='$POLICY_NAME'].Arn | [0]" --output text 2>/dev/null || true)"

if [ -z "$POLICY_ARN" ] || [ "$POLICY_ARN" = "None" ]; then
  echo "[cfn] Policy not found — creating…"
  POLICY_ARN="$(aws cloudfront create-response-headers-policy \
    --name "$POLICY_NAME" \
    --region us-east-1 \
    --profile "$PROFILE" \
    --items "{
      \"SecurityHeadersConfig\": {\"SecurityHeadersEnabled\": false},
      \"CustomHeadersConfig\": {
        \"Quantity\": 3,
        \"Items\": [
          {\"Field\": \"Strict-Transport-Security\", \"Override\": true, \"Value\": \"$HSTS_VALUE\"},
          {\"Field\": \"X-Content-Type-Options\", \"Override\": true, \"Value\": \"nosniff\"},
          {\"Field\": \"Referrer-Policy\", \"Override\": true, \"Value\": \"strict-origin-when-cross-origin\"}
        ]
      }
    }" --query 'ResponseHeadersPolicy.Arn' --output text)" || { echo "[cfn] policy creation failed" >&2; exit 12; }
  echo "[cfn] Created: $POLICY_ARN"
else
  echo "[cfn] Already exists: $POLICY_ARN"
fi
POLICY_ID="${POLICY_ARN##*/}"
export POLICY_ID

# --- 2-4. Update distribution (python handles the AWS JSON quirks) ------------
echo "[cfn] Updating distribution: apex alias + headers policy + 404 error response…"
python3 - <<'PYEOF' || exit 13
import json, os, subprocess, sys, tempfile

def die(msg, code=13):
    print(f"[cfn][ERROR] {msg}", file=sys.stderr)
    sys.exit(code)

dist_id  = os.environ["DIST_ID"]
profile  = os.environ.get("PROFILE", "awang")
apex     = os.environ["APEX_HOST"]
policy_id = os.environ["POLICY_ID"]

def aws(*args):
    out = subprocess.run(["aws", *args, "--profile", profile, "--output", "json"],
                         capture_output=True, text=True)
    if out.returncode != 0:
        die(f"aws {' '.join(args[:3])}… failed: {out.stderr.strip()[:400]}")
    return json.loads(out.stdout)

dist = aws("cloudfront", "get-distribution", "--id", dist_id)["Distribution"]
etag = dist["ETag"]
cfg  = dist["DistributionConfig"]

def as_list(node, key):
    """AWS quirk: single-item collections may be bare strings."""
    items = (node or {}).get(key) or []
    if isinstance(items, str):
        items = [items]
    return items

changed = []

# 2. Apex alias
aliases = cfg.get("Aliases") or {"Quantity": 0, "Items": []}
alias_items = as_list(aliases, "Items")
if apex not in alias_items:
    alias_items.append(apex)
    changed.append(f"alias +{apex}")
cfg["Aliases"] = {"Quantity": len(alias_items), "Items": alias_items}

# 3. Response-headers policy on the default behavior
dcb = cfg["DefaultCacheBehavior"]
if dcb.get("ResponseHeadersPolicyId") != policy_id:
    dcb["ResponseHeadersPolicyId"] = policy_id
    changed.append(f"headers policy -> {policy_id}")

# 4. 404 -> /404.html custom error response (only if not already identical)
cer = cfg.get("CustomErrorResponses") or {"Quantity": 0, "Items": []}
cer_items = as_list(cer, "Items")
WANT_CER = {"ErrorCode": 404, "ResponsePage": "/404.html",
            "ResponseCode": "404", "ErrorCachingMinTTL": 10}
existing_404 = next((c for c in cer_items if str(c.get("ErrorCode")) == "404"), None)
if existing_404 is None or {
        "ErrorCode": existing_404.get("ErrorCode"),
        "ResponsePage": existing_404.get("ResponsePage"),
        "ResponseCode": str(existing_404.get("ResponseCode")),
        "ErrorCachingMinTTL": existing_404.get("ErrorCachingMinTTL"),
    } != WANT_CER:
    cer_items = [c for c in cer_items if str(c.get("ErrorCode")) != "404"]
    cer_items.append(dict(WANT_CER))
    cfg["CustomErrorResponses"] = {"Quantity": len(cer_items), "Items": cer_items}
    changed.append("404 error response")

if not any(c != "404 error response" for c in changed):
    print("[cfn] Distribution already configured — nothing to update.")
    sys.exit(0)

fd, cfgfile = tempfile.mkstemp(suffix=".json")
with os.fdopen(fd, "w") as f:
    json.dump(cfg, f)

out = subprocess.run(
    ["aws", "cloudfront", "update-distribution", "--id", dist_id,
     "--if-match", etag, "--distribution-config", f"file://{cfgfile}",
     "--profile", profile, "--output", "json"],
    capture_output=True, text=True)
os.unlink(cfgfile)
if out.returncode != 0:
    die(f"update-distribution failed: {out.stderr.strip()[:400]}", 14)

print(f"[cfn] Updated (etag {etag}): " + ", ".join(changed))
PYEOF

# --- 5. Wait for deployment ----------------------------------------------------
echo "[cfn] Waiting for distribution to reach 'Deployed' (timeout ${WAIT_TIMEOUT_S}s)…"
STATUS=""
for _ in $(seq 1 "$((WAIT_TIMEOUT_S / 30))"); do
  STATUS="$(aws cloudfront get-distribution --id "$DIST_ID" --profile "$PROFILE" \
    --query 'Distribution.Status' --output text)"
  [ "$STATUS" = "Deployed" ] && break
  sleep 30
done
[ "$STATUS" = "Deployed" ] || { echo "[cfn][ERROR] distribution not Deployed (status=$STATUS)" >&2; exit 15; }
echo "[cfn] OK — distribution Deployed with apex alias, headers policy, 404 response."
