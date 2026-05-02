#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# build-cross-pthread9x.sh - Build pthread9x for cross toolchain
# ============================================================================

source "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"

PTHREAD9X_SRC="$SRC_DIR/pthread9x"

require_dir "$PTHREAD9X_SRC" "missing pthread9x sources"
require_step prepare-pthread9x "run prepare-pthread9x.sh first"

log "Building pthread9x..."

cd "$PTHREAD9X_SRC"

# Use stage1 toolchain
export PATH="$PREFIX/bin:$PATH"

# Build pthread9x without NEW_ALLOC to avoid malloc/realloc/calloc/free conflicts with msvcrt
# Also strip memory.c.o from libpthread.a to prevent multiple definition errors
make clean
make -j"$JOBS" CC="${TARGET}-gcc" AR="${TARGET}-ar" # Do NOT pass NEW_ALLOC at all
# Remove memory.c.o which defines realloc/calloc/free in non-NEW_ALLOC mode and conflicts with msvcrt
${TARGET}-ar d libpthread.a extra/memory.c.o 2>/dev/null || true

log "Installing pthread9x headers and libs..."

# Install headers
mkdir -p "$PREFIX/$TARGET/include"
cp -v include/*.h "$PREFIX/$TARGET/include/"

# Install library and crtfix.o
mkdir -p "$PREFIX/$TARGET/lib"
cp -v libpthread.a crtfix.o "$PREFIX/$TARGET/lib/"

# Also build and install DLL version for __imp__* symbols
log "Building pthread9x DLL for import symbols..."
make clean
make -j"$JOBS" CC="${TARGET}-gcc" AR="${TARGET}-ar" DLL=1
if [ -f libpthread.dll ]; then
    cp -v libpthread.dll "$PREFIX/$TARGET/lib/"
    # Generate import library
    ${TARGET}-dlltool -D libpthread.dll -d libpthread.def -l libpthread.dll.a
    cp -v libpthread.dll.a "$PREFIX/$TARGET/lib/"
fi

mark_done build-pthread9x
log "pthread9x build and installation complete"
