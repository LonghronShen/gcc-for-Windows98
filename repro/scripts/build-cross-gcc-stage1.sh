#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# build-cross-gcc-stage1.sh - Build GCC stage1 (bootstrap compiler)
# ============================================================================

source "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"

require_file "$BUILD_DIR/gcc/configure-command.sh" "missing gcc configure script; run prepare-gcc.sh first"
require_executable "$PREFIX/bin/${TARGET}-as" "missing cross binutils; run build-cross-binutils.sh first"

rm -rf "$BUILD_DIR/gcc-stage1-run"
mkdir -p "$BUILD_DIR/gcc-stage1-run"
cd "$BUILD_DIR/gcc-stage1-run"
export PATH="$PREFIX/bin:$PATH"
run_logged build-gcc-stage1.log bash "$BUILD_DIR/gcc/configure-command.sh" --without-headers --with-newlib --disable-shared --disable-threads --disable-libstdcxx --enable-languages=c

  # Pre-create .deps directories to avoid parallel make race condition
  log "Pre-creating dependency directories for parallel build..."
  find "$BUILD_DIR/gcc-stage1-run/gcc" -type d -name .deps 2>/dev/null || true
  if [[ -d "$BUILD_DIR/gcc-stage1-run/gcc" ]]; then
    (cd "$BUILD_DIR/gcc-stage1-run/gcc" && find . -type d | while read -r dir; do mkdir -p "$dir/.deps"; done) 2>/dev/null || true
  fi

run_logged build-gcc-stage1.log make all-gcc -j"$JOBS"
run_logged build-gcc-stage1.log make install-gcc
mark_done build-gcc-stage1
log "build gcc stage1 complete"
