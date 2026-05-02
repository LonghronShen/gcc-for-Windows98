#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# build-native-pthread9x.sh - Build pthread9x for Native Toolset
# ============================================================================

source "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"

REPO_ROOT="$ROOT_DIR"
PTHREAD9X_SRC="$SRC_DIR/pthread9x"
INSTALL_DIR="$REPO_ROOT/out/native-toolset/i686-w64-mingw32"
CROSS_BIN_DIR="$REPO_ROOT/out/toolchain/bin"

require_dir "$PTHREAD9X_SRC" "missing pthread9x sources"
require_step prepare-pthread9x "run prepare-pthread9x.sh first"

echo "=== Building pthread9x for Native Toolset ==="

cd "$PTHREAD9X_SRC"

# Use cross-compiler to build for the target
export PATH="$CROSS_BIN_DIR:$PATH"

# Build pthread9x without NEW_ALLOC to avoid malloc/realloc/calloc/free conflicts with msvcrt
make clean
make -j"$(nproc)" CC="${TARGET}-gcc" AR="${TARGET}-ar"
# Remove memory.c.o to prevent multiple definition errors with msvcrt
${TARGET}-ar d libpthread.a extra/memory.c.o 2>/dev/null || true

echo "=== Installing pthread9x into Native Toolset sysroot ==="
mkdir -p "$INSTALL_DIR/include"
mkdir -p "$INSTALL_DIR/lib"

cp -v include/*.h "$INSTALL_DIR/include/"
cp -v libpthread.a crtfix.o "$INSTALL_DIR/lib/"

echo "pthread9x build and installation for Native Toolset complete."
mark_done build-native-pthread9x
