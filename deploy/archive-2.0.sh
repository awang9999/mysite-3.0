#!/usr/bin/env bash
# =============================================================================
# deploy/archive-2.0.sh — build the mysite-2.0 archive (TODOS 4.4, HOSTING D10)
#
# Produces a static, self-contained copy of the old site under /old/ so it
# stays reachable after cutover. The 3.0 deploy script stages this dir into
# dist/old/ before syncing, so the bucket stays an exact mirror of dist/.
#
# What it does:
#   1. Ensure the 2.0 deps are installed.
#   2. Temporarily add router basename="/old" to 2.0's <Router> (reverted after).
#   3. Build 2.0 with PUBLIC_URL=/old so every asset reference is /old/...
#   4. Copy build/ -> $OUT (default: mysite-3.0/old-archive/).
#   5. Copy index.html to each SPA route path (static deep-link fallback).
#   6. Optionally drop the 26 MB hero video (ARCHIVE_EXCLUDE_VIDEO=1).
#
# Idempotent + re-runnable. Does NOT touch 2.0's committed source (the basename
# edit is reverted), so the only 2.0 diffs stay the pre-existing ones.
#
# Usage:  ./deploy/archive-2.0.sh
# =============================================================================
set -Eeuo pipefail

REPO2_DIR="${REPO2_DIR:-/home/zander/projects/mysite-2.0}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${ARCHIVE_OUT:-$ROOT/old-archive}"
BASENAME_PATH="/old"

log()  { printf '\033[1;34m[archive]\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m[archive][ERROR]\033[0m %s\n' "$*" >&2; exit "${2:-1}"; }

[ -d "$REPO2_DIR" ] || fail "2.0 repo not found at $REPO2_DIR" 10
command -v node >/dev/null || fail "node not found" 11
command -v npm  >/dev/null || fail "npm not found" 12

log "2.0 repo: $REPO2_DIR"
log "output:   $OUT"

# --- 1. Deps ------------------------------------------------------------------
if [ ! -d "$REPO2_DIR/node_modules" ]; then
  log "Installing 2.0 deps (npm ci)…"
  ( cd "$REPO2_DIR" && npm ci ) || fail "2.0 npm ci failed" 13
else
  log "2.0 node_modules present — skipping install."
fi

APP_JS="$REPO2_DIR/src/App.js"
[ -f "$APP_JS" ] || fail "src/App.js not found in 2.0" 14

# --- 2. Apply basename (reverted in EXIT) -------------------------------------
cleanup() {
  if [ "${APPLIED:-0}" = "1" ]; then
    log "Reverting basename edit in 2.0 src/App.js…"
    ( cd "$REPO2_DIR" && git checkout -- src/App.js ) || log "WARN: could not revert src/App.js (leaving basename in place)"
  fi
}
trap cleanup EXIT

if grep -q "basename=\"$BASENAME_PATH\"" "$APP_JS"; then
  log "basename already present in App.js — leaving as-is."
  APPLIED=0
else
  # Replace the single bare <Router> with <Router basename="/old">.
  sed -i.bak "s#<Router>#<Router basename=\"$BASENAME_PATH\">#" "$APP_JS"
  rm -f "$APP_JS.bak"
  grep -q "basename=\"$BASENAME_PATH\"" "$APP_JS" || fail "failed to inject basename into App.js" 15
  APPLIED=1
  log "Injected basename=\"$BASENAME_PATH\" into 2.0 <Router>."
fi

# --- 3. Build 2.0 with /old asset prefix --------------------------------------
log "Building 2.0 (PUBLIC_URL=$BASENAME_PATH)…"
( cd "$REPO2_DIR" && PUBLIC_URL="$BASENAME_PATH" npm run build ) \
  || fail "2.0 build failed" 16
[ -f "$REPO2_DIR/build/index.html" ] || fail "2.0 build/index.html missing" 17

# --- 4. Copy build -> output --------------------------------------------------
log "Copying build/ -> $OUT"
rm -rf "$OUT"
mkdir -p "$OUT"
cp -R "$REPO2_DIR/build/." "$OUT/"

# --- 5. SPA deep-link fallback: index.html at each route path ------------------
# Static S3 has no rewrites, so each route path needs an index.html for the
# client router (basename=/old) to take over.
ROUTES=(
  "blog"
  "todo"
  "changelog"
  "blog/matrix-calculus-preface"
  "blog/matrix-calculus-part-1"
  "blog/matrix-calculus-part-2"
)
for r in "${ROUTES[@]}"; do
  dest="$OUT/$r"
  mkdir -p "$dest"
  cp "$OUT/index.html" "$dest/index.html"
  log "  deep-link: /old/$r/ -> index.html"
done

# --- 6. Optional: drop the hero video -----------------------------------------
if [ "${ARCHIVE_EXCLUDE_VIDEO:-0}" = "1" ] && [ -d "$OUT/videos" ]; then
  log "ARCHIVE_EXCLUDE_VIDEO=1 — removing videos/ ($(du -sh "$OUT/videos" | cut -f1))"
  rm -rf "$OUT/videos"
fi

log "Archive ready: $OUT"
log "Size: $(du -sh "$OUT" | cut -f1) · files: $(find "$OUT" -type f | wc -l)"
log "Done. The 3.0 deploy will stage this into dist/old/."
