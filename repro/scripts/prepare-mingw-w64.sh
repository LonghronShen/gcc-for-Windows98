#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# prepare-mingw-w64.sh - Prepare mingw-w64 sources
# ============================================================================

source "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"

require_dir "$SRC_DIR/mingw-w64/.git" "missing mingw-w64 sources; run fetch-sources.sh first"
skip_if_done prepare-mingw-w64

cd "$SRC_DIR/mingw-w64"
run_logged prepare-mingw-w64.log git reset --hard HEAD
run_logged prepare-mingw-w64.log git clean -fd

# Apply versioned patch series for mingw-w64.
run_logged prepare-mingw-w64.log "$ROOT_DIR/scripts/apply-patches.sh" mingw-w64 "$MINGW_W64_COMPONENT_VERSION"

mkdir -p "$BUILD_DIR/mingw-w64"
cat > "$BUILD_DIR/mingw-w64/configure-command.sh" <<EOF
# Top-level recursive configure is intentionally skipped.
# Real headers/CRT configuration is performed in scripts/build-cross-mingw-w64.sh.
EOF
chmod +x "$BUILD_DIR/mingw-w64/configure-command.sh"

mark_done prepare-mingw-w64
log "prepare mingw-w64 complete"
