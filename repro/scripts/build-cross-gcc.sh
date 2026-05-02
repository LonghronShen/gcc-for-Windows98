#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# build-cross-gcc.sh - Build GCC final (stage2)
# ============================================================================

source "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"

require_file "$BUILD_DIR/gcc/configure-command.sh" "missing gcc configure script; run prepare-gcc.sh first"
require_executable "$PREFIX/bin/${TARGET}-gcc" "missing stage1 target gcc; run build-cross-gcc-stage1.sh first"

rm -rf "$BUILD_DIR/gcc-final-run"
mkdir -p "$BUILD_DIR/gcc-final-run"
cd "$BUILD_DIR/gcc-final-run"
export PATH="$PREFIX/bin:$PATH"
run_logged build-gcc.log bash "$BUILD_DIR/gcc/configure-command.sh"

  # Pre-create .deps directories to avoid parallel make race condition
  log "Pre-creating dependency directories for parallel build..."
  if [[ -d "$BUILD_DIR/gcc-final-run/gcc" ]]; then
    (cd "$BUILD_DIR/gcc-final-run/gcc" && find . -type d | while read -r dir; do mkdir -p "$dir/.deps"; done) 2>/dev/null || true
  fi

run_logged build-gcc.log make -j"$JOBS"
run_logged build-gcc.log make install
mark_done build-gcc
log "build gcc final complete"
