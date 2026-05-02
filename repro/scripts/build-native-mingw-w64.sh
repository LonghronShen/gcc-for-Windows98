#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# build-native-mingw-w64.sh - Build mingw-w64 for Native Toolset (Canadian Cross)
# ============================================================================

source "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"

REPO_ROOT="$ROOT_DIR"
SRC_DIR="$REPO_ROOT/src/mingw-w64"
NATIVE_TOOLSET_DIR="$REPO_ROOT/out/native-toolset"
LOG_DIR="$REPO_ROOT/logs"
BUILD_DIR="$REPO_ROOT/build/native-mingw-w64"
PREFIX="$NATIVE_TOOLSET_DIR/$TARGET"

# Cross compiler for Canadian Cross (Host compiler for this build)
CROSS_BIN_DIR="$REPO_ROOT/out/toolchain/bin"
export PATH="$CROSS_BIN_DIR:$PATH"

mkdir -p "$LOG_DIR"
mkdir -p "$BUILD_DIR"

log "building mingw-w64 headers for native toolset"
mkdir -p "$BUILD_DIR/headers"
pushd "$BUILD_DIR/headers"
run_logged native-mingw-headers.log "$SRC_DIR/mingw-w64-headers/configure" \
    --host=$TARGET \
    --prefix="$PREFIX" \
    --enable-sdk=all

run_logged native-mingw-headers.log make install
popd

log "building mingw-w64 CRT for native toolset"
mkdir -p "$BUILD_DIR/crt"
pushd "$BUILD_DIR/crt"

# Note: We need to explicitly specify CC because we use Linux Cross GCC
# to build libraries that run on Windows (Host) for Windows (Target).
# Here build=Linux, host=i686-w64-mingw32, target=i686-w64-mingw32

run_logged native-mingw-crt.log "$SRC_DIR/mingw-w64-crt/configure" \
    --host=$TARGET \
    --prefix="$PREFIX" \
    --with-sysroot="$PREFIX" \
    --with-default-msvcrt=msvcrt-os \
    CC="$CROSS_BIN_DIR/i686-w64-mingw32-gcc" \
    AR="$CROSS_BIN_DIR/i686-w64-mingw32-ar" \
    RANLIB="$CROSS_BIN_DIR/i686-w64-mingw32-ranlib"

run_logged native-mingw-crt.log make -j"$(nproc)"
run_logged native-mingw-crt.log make install
popd

mark_done build-native-mingw-w64
log "mingw-w64 (headers & crt) build for native toolset completed"
