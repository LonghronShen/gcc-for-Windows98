#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# generate-patches.sh - Regenerate versioned patch folders from clean sources
# ============================================================================

source "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"

if [[ "${GENERATE_PATCHES:-0}" != "1" ]]; then
  log "generate-patches disabled; skipping (enable via --generate-patches)"
  exit 0
fi

require_executable python3
require_dir "$SRC_DIR/gcc" "missing gcc sources; run fetch-sources.sh first"
require_dir "$SRC_DIR/mingw-w64" "missing mingw-w64 sources; run fetch-sources.sh first"
require_dir "$SRC_DIR/pthread9x" "missing pthread9x sources; run fetch-sources.sh first"

# Normalize GCC component version to the CLI format expected by generate-patches.py.
GCC_PATCH_VERSION="${GCC_COMPONENT_VERSION#gcc-}"
MINGW_PATCH_SELECTOR="${MINGW_W64_COMPONENT_VERSION:-${MINGW_W64_FETCH_REF}}"
PTHREAD_PATCH_SELECTOR="${PTHREAD9X_COMPONENT_VERSION:-${PTHREAD9X_FETCH_REF}}"

run_logged generate-patches.log \
  python3 "$PATCH_DIR/generate-patches.py" \
  --gcc-version "$GCC_PATCH_VERSION" \
  --source-dir "$SRC_DIR/gcc"

run_logged generate-patches.log \
  python3 "$PATCH_DIR/generate-patches.py" \
  --mingw-w64-version "$MINGW_PATCH_SELECTOR" \
  --source-dir "$SRC_DIR/mingw-w64"

run_logged generate-patches.log \
  python3 "$PATCH_DIR/generate-patches.py" \
  --pthread9x-version "$PTHREAD_PATCH_SELECTOR" \
  --source-dir "$SRC_DIR/pthread9x"

mark_done generate-patches
log "generate patches complete"
