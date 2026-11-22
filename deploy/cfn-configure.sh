#!/usr/bin/env bash
# =============================================================================
# deploy/cfn-configure.sh — CloudFront cutover config (TODOS 4.2, HOSTING §3/§6)
#
# Architecture (zero-downtime, NO DNS change):
#   The apex hostname's CNAME alias lives on the LEGACY dist
#   (E96YWX7J3SY11), and CloudFront forbids the same CNAME on two
#   distributions (CNAMEAlreadyExists) — so we do NOT move the alias.
#   Instead we repoint the apex dist's ORIGIN from the old 2.0 bucket
#   (s3-website endpoint) to the main 3.0 bucket (private, OAI-locked).
#   After that, the moment 3.0 content is deployed and the edges
#   invalidated (deploy.sh), BOTH hostnames serve 3.0. Route53 is never
#   touched; the apex A record keeps pointing at the legacy dist domain.
#
# Steps (all idempotent — safe to re-run):
#   1. Response-headers policy (HSTS / X-Content-Type-Options /
#      Referrer-Policy as structured security headers) — idempotent by name.
#   2. OAI for the apex dist (idempotent by comment) + S3 bucket-policy
#      grant for it (idempotent by Sid).
#   3. MAIN dist (E91NPMQZ9M9NQ, serves www): headers policy + 404 CER.
#   4. APEX dist (E96YWX7J3SY11, serves apex): origin repoint to the main
#      bucket + new OAI, headers policy + 404 CER.
#   5. Wait for BOTH distributions to reach "Deployed".
#
# Until deploy.sh runs, nothing visible changes: the apex dist's edge cache
# still holds 2.0 objects and the bucket still contains 2.0.
#
# NOTE on the www 301 (HOSTING §6 step 2): CloudFront cannot branch on the
# Host header with static config, so this implements Option A — apex + www
# both served (200); canonical tags in the HTML handle SEO. If Option B is
# ever chosen, add a viewer-request Lambda@Edge (deploy.sh's
# WWW_MODE=redirect already verifies it).
#
# Usage:  ./deploy/cfn-configure.sh
# =============================================================================
set -Eeuo pipefail

MAIN_DIST="${DEPLOY_DIST_ID:-E91NPMQZ9M9NQ}"
APEX_DIST="${DEPLOY_APEX_DIST_ID:-E96YWX7J3SY11}"
BUCKET="${DEPLOY_BUCKET:-www.alexander-wang.net}"
ORIGIN_DOMAIN="${DEPLOY_ORIGIN_DOMAIN:-www.alexander-wang.net.s3.us-west-1.amazonaws.com}"
PROFILE="${AWS_PROFILE:-awang}"
POLICY_NAME="mysite-3-sec-headers"
OAI_COMMENT="mysite-3 apex dist OAI (deploy/cfn-configure.sh)"
OAI_CALLER_REF="mysite-3-apex-dist"
# HSTS as structured security-header components (CloudFront will not
# accept HSTS/nosniff/referrer as free-form custom headers).
HSTS_MAX_AGE="${HSTS_MAX_AGE:-31536000}"
HSTS_INCLUDE_SUBDOMAINS="${HSTS_INCLUDE_SUBDOMAINS:-true}"
HSTS_PRELOAD="${HSTS_PRELOAD:-false}"
WAIT_TIMEOUT_S="${CFN_WAIT_TIMEOUT:-2700}"
export AWS_PAGER="" MAIN_DIST APEX_DIST BUCKET ORIGIN_DOMAIN PROFILE \
       POLICY_NAME OAI_COMMENT OAI_CALLER_REF HSTS_MAX_AGE \
       HSTS_INCLUDE_SUBDOMAINS HSTS_PRELOAD

command -v aws >/dev/null || { echo "[cfn] aws cli not found" >&2; exit 10; }
command -v python3 >/dev/null || { echo "[cfn] python3 not found" >&2; exit 11; }

echo "[cfn] main dist: $MAIN_DIST · apex dist: $APEX_DIST · bucket: $BUCKET (profile: $PROFILE)"

# --- 1. Response-headers policy (idempotent by name) --------------------------
echo "[cfn] Ensuring response-headers policy '$POLICY_NAME'…"
# CLI v2.34: list items nest under ResponseHeadersPolicy, the name lives in
# ResponseHeadersPolicyConfig.Name, and list items expose Id (not Arn).
# The distribution's ResponseHeadersPolicyId field wants exactly that Id.
POLICY_ID="$(aws cloudfront list-response-headers-policies --region us-east-1 --profile "$PROFILE" \
  --query "ResponseHeadersPolicyList.Items[].ResponseHeadersPolicy | [?ResponseHeadersPolicyConfig.Name=='$POLICY_NAME'].Id | [0]" --output text 2>/dev/null || true)"

if [ -z "$POLICY_ID" ] || [ "$POLICY_ID" = "None" ]; then
  echo "[cfn] Policy not found — creating…"
  POLICY_ID="$(aws cloudfront create-response-headers-policy \
    --region us-east-1 \
    --profile "$PROFILE" \
    --response-headers-policy-config "{
      \"Name\": \"$POLICY_NAME\",
      \"Comment\": \"Security headers for mysite-3.0 (created by deploy/cfn-configure.sh)\",
      \"SecurityHeadersConfig\": {
        \"StrictTransportSecurity\": {
          \"Override\": true,
          \"IncludeSubdomains\": $HSTS_INCLUDE_SUBDOMAINS,
          \"Preload\": $HSTS_PRELOAD,
          \"AccessControlMaxAgeSec\": $HSTS_MAX_AGE
        },
        \"ContentTypeOptions\": {
          \"Override\": true
        },
        \"ReferrerPolicy\": {
          \"Override\": true,
          \"ReferrerPolicy\": \"strict-origin-when-cross-origin\"
        }
      }
    }" --query 'ResponseHeadersPolicy.Id' --output text)" || { echo "[cfn] policy creation failed" >&2; exit 12; }
  echo "[cfn] Created policy id: $POLICY_ID"
else
  echo "[cfn] Already exists: id $POLICY_ID"
fi
export POLICY_ID

# --- 2. OAI for the apex dist + bucket-policy grant (idempotent) --------------
echo "[cfn] Ensuring origin-access identity + bucket policy for the apex dist…"
OAI_ID="$(python3 - <<'PYEOF' || exit 12
import json, os, subprocess, sys, tempfile

def die(msg, code=12):
    print(f"[cfn][ERROR] {msg}", file=sys.stderr)
    sys.exit(code)

profile     = os.environ["PROFILE"]
bucket      = os.environ["BUCKET"]
oai_comment = os.environ["OAI_COMMENT"]
oai_ref     = os.environ["OAI_CALLER_REF"]

def aws(*args, raw=False):
    out = subprocess.run(["aws", *args, "--profile", profile, "--output", "json"],
                         capture_output=True, text=True)
    if out.returncode != 0:
        die(f"aws {' '.join(args[:3])}… failed: {out.stderr.strip()[:400]}")
    return out.stdout if raw else json.loads(out.stdout)

# CLI v2.34 renamed the OAI commands: list-cloud-FRONT-origin-access-identities
lst = aws("cloudfront", "list-cloud-front-origin-access-identities")
items = (lst.get("CloudFrontOriginAccessIdentityList") or {}).get("Items") or []
if isinstance(items, dict):
    items = [items]
oai = next((i for i in items if i.get("Comment") == oai_comment), None)
if oai is None:
    print("[cfn] OAI not found — creating…", file=sys.stderr)
    cr = aws("cloudfront", "create-cloud-front-origin-access-identity",
             "--cloud-front-origin-access-identity-config",
             json.dumps({"CallerReference": oai_ref, "Comment": oai_comment}))
    oai_id = cr["CloudFrontOriginAccessIdentity"]["Id"]
else:
    oai_id = oai["Id"]

# Bucket policy: ensure a grant for this OAI (idempotent by Sid).
pol_raw = aws("s3api", "get-bucket-policy", "--bucket", bucket, raw=True)
# get-bucket-policy wraps the document: {"Policy": "<json string>"}
outer = json.loads(pol_raw) if pol_raw.strip() else {}
policy = json.loads(outer["Policy"]) if outer.get("Policy") else {"Version": "2012-10-17"}
stmts = policy.get("Statement") or []
if isinstance(stmts, dict):
    stmts = [stmts]
want_sid = "allow-apex-dist-oai"
want_principal = (f"arn:aws:iam::cloudfront:user/"
                  f"CloudFront Origin Access Identity {oai_id}")
existing = next((s for s in stmts if s.get("Sid") == want_sid), None)
if existing is None:
    stmts.append({
        "Sid": want_sid,
        "Effect": "Allow",
        "Principal": {"AWS": want_principal},
        "Action": "s3:GetObject",
        "Resource": f"arn:aws:s3:::{bucket}/*",
    })
    policy["Statement"] = stmts
    fd, f = tempfile.mkstemp(suffix=".json")
    with os.fdopen(fd, "w") as fh:
        json.dump(policy, fh)
    aws("s3api", "put-bucket-policy", "--bucket", bucket, "--policy", f"file://{f}", raw=True)
    os.unlink(f)
    print(f"[cfn] Bucket policy: added grant for OAI {oai_id}", file=sys.stderr)
elif existing.get("Principal", {}).get("AWS") != want_principal:
    existing["Principal"] = {"AWS": want_principal}
    policy["Statement"] = stmts
    fd, f = tempfile.mkstemp(suffix=".json")
    with os.fdopen(fd, "w") as fh:
        json.dump(policy, fh)
    aws("s3api", "put-bucket-policy", "--bucket", bucket, "--policy", f"file://{f}", raw=True)
    os.unlink(f)
    print(f"[cfn] Bucket policy: updated grant to OAI {oai_id}", file=sys.stderr)
else:
    print(f"[cfn] Bucket policy: grant already present (OAI {oai_id})", file=sys.stderr)

print(oai_id)
PYEOF
)"
echo "[cfn] OAI id: $OAI_ID"
export OAI_ID

# --- 3+4. Update both distributions -------------------------------------------
echo "[cfn] Updating distributions (main: headers+404 · apex: origin repoint + headers+404)…"
python3 - <<'PYEOF' || exit 13
import json, os, subprocess, sys, tempfile

def die(msg, code=13):
    print(f"[cfn][ERROR] {msg}", file=sys.stderr)
    sys.exit(code)

main_id   = os.environ["MAIN_DIST"]
apex_id   = os.environ["APEX_DIST"]
profile   = os.environ["PROFILE"]
policy_id = os.environ["POLICY_ID"]
oai_id    = os.environ["OAI_ID"]
origin    = os.environ["ORIGIN_DOMAIN"]

def aws(*args):
    out = subprocess.run(["aws", *args, "--profile", profile, "--output", "json"],
                         capture_output=True, text=True)
    if out.returncode != 0:
        die(f"aws {' '.join(args[:3])}… failed: {out.stderr.strip()[:400]}")
    return json.loads(out.stdout)

def as_list(node, key):
    """AWS quirk: single-item collections may be bare strings."""
    items = (node or {}).get(key) or []
    if isinstance(items, str):
        items = [items]
    return items

WANT_CER = {"ErrorCode": 404, "ResponsePagePath": "/404.html",
            "ResponseCode": "404", "ErrorCachingMinTTL": 10}

def apply_headers_and_404(cfg, changed):
    dcb = cfg["DefaultCacheBehavior"]
    if dcb.get("ResponseHeadersPolicyId") != policy_id:
        dcb["ResponseHeadersPolicyId"] = policy_id
        changed.append(f"headers policy -> {policy_id[:8]}")
    items = as_list(cfg.get("CustomErrorResponses"), "Items")
    existing = next((c for c in items if str(c.get("ErrorCode")) == "404"), None)
    if existing is None or {
        "ErrorCode": existing.get("ErrorCode"),
        "ResponsePagePath": existing.get("ResponsePagePath"),
        "ResponseCode": str(existing.get("ResponseCode")),
        "ErrorCachingMinTTL": existing.get("ErrorCachingMinTTL"),
    } != WANT_CER:
        items = [c for c in items if str(c.get("ErrorCode")) != "404"] + [dict(WANT_CER)]
        cfg["CustomErrorResponses"] = {"Quantity": len(items), "Items": items}
        changed.append("404 error response")

def update(dist_id, repoint):
    # CLI v2.34: ETag is a top-level sibling of Distribution, not inside it.
    resp = aws("cloudfront", "get-distribution", "--id", dist_id)
    etag = resp["ETag"]
    cfg = resp["Distribution"]["DistributionConfig"]
    changed = []

    if repoint:
        oitems = as_list(cfg.get("Origins"), "Items")
        want_oai = f"origin-access-identity/cloudfront/{oai_id}"
        match = next((o for o in oitems if o.get("DomainName") == origin), None)
        oai_ok = (match is not None
                  and (match.get("S3OriginConfig") or {}).get("OriginAccessIdentity") == want_oai)
        target_ok = cfg["DefaultCacheBehavior"].get("TargetOriginId") == origin
        if not (oai_ok and target_ok):
            cfg["Origins"] = {"Quantity": 1, "Items": [{
                "Id": origin,
                "DomainName": origin,
                "OriginPath": "",
                "CustomHeaders": {"Quantity": 0},
                "S3OriginConfig": {
                    "OriginAccessIdentity": want_oai,
                    "OriginReadTimeout": 30,
                },
                "ConnectionAttempts": 3,
                "ConnectionTimeout": 10,
                "OriginShield": {"Enabled": False},
            }]}
            cfg["DefaultCacheBehavior"]["TargetOriginId"] = origin
            changed.append(f"origin -> {origin} (oai {oai_id})")

    apply_headers_and_404(cfg, changed)

    if not changed:
        print(f"[cfn] {dist_id}: already configured — nothing to update.")
        return
    fd, f = tempfile.mkstemp(suffix=".json")
    with os.fdopen(fd, "w") as fh:
        json.dump(cfg, fh)
    out = subprocess.run(
        ["aws", "cloudfront", "update-distribution", "--id", dist_id,
         "--if-match", etag, "--distribution-config", f"file://{f}",
         "--profile", profile, "--output", "json"],
        capture_output=True, text=True)
    os.unlink(f)
    if out.returncode != 0:
        die(f"update-distribution {dist_id} failed: {out.stderr.strip()[:400]}", 14)
    print(f"[cfn] {dist_id} updated (etag {etag}): " + ", ".join(changed))

update(main_id, repoint=False)
update(apex_id, repoint=True)
PYEOF

# --- 5. Wait for both deployments ----------------------------------------------
echo "[cfn] Waiting for BOTH distributions to reach 'Deployed' (timeout ${WAIT_TIMEOUT_S}s)…"
STATUS_M=""; STATUS_A=""
for _ in $(seq 1 "$((WAIT_TIMEOUT_S / 30))"); do
  [ "$STATUS_M" = "Deployed" ] || STATUS_M="$(aws cloudfront get-distribution --id "$MAIN_DIST" --profile "$PROFILE" --query 'Distribution.Status' --output text)"
  [ "$STATUS_A" = "Deployed" ] || STATUS_A="$(aws cloudfront get-distribution --id "$APEX_DIST" --profile "$PROFILE" --query 'Distribution.Status' --output text)"
  [ "$STATUS_M" = "Deployed" ] && [ "$STATUS_A" = "Deployed" ] && break
  echo "[cfn] Waiting… (main=$STATUS_M apex=$STATUS_A)"
  sleep 30
done
[ "$STATUS_M" = "Deployed" ] || { echo "[cfn][ERROR] main dist not Deployed (status=$STATUS_M)" >&2; exit 15; }
[ "$STATUS_A" = "Deployed" ] || { echo "[cfn][ERROR] apex dist not Deployed (status=$STATUS_A)" >&2; exit 15; }
echo "[cfn] OK — both distributions Deployed (headers policy, 404 response, apex origin repointed)."
echo "[cfn] Nothing visible has changed yet: run deploy.sh to swap the content."
