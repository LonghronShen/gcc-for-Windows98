#!/usr/bin/env bash
# smoke-verify-layout.sh — Phase 1 smoke test: verify cross and native toolchain layout.
# Runs inside the consumer container (/workspace = repro/).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

PASS=0
FAIL=0

check_file() {
    local path="$1"
    local label="${2:-$path}"
    if [[ -f "$path" ]]; then
        log "[OK]      $label"
        (( PASS++ )) || true
    else
        log "[MISSING] $label"
        (( FAIL++ )) || true
    fi
}

check_dir() {
    local path="$1"
    local label="${2:-$path}"
    if [[ -d "$path" ]]; then
        log "[OK]      $label/"
        (( PASS++ )) || true
    else
        log "[MISSING] $label/"
        (( FAIL++ )) || true
    fi
}

check_cmd() {
    local cmd="$1"
    if command -v "$cmd" &>/dev/null; then
        log "[OK]      command: $cmd  →  $(command -v "$cmd")"
        (( PASS++ )) || true
    else
        log "[MISSING] command: $cmd"
        (( FAIL++ )) || true
    fi
}

# ── Phase 1a: cross toolchain ────────────────────────────────────────────────
log "=== Cross toolchain layout ==="

CROSS_BINS=(
    i686-w64-mingw32-gcc
    i686-w64-mingw32-g++
    i686-w64-mingw32-ar
    i686-w64-mingw32-ld
    i686-w64-mingw32-nm
    i686-w64-mingw32-objdump
    i686-w64-mingw32-strip
    i686-w64-mingw32-windres
)
for cmd in "${CROSS_BINS[@]}"; do
    check_cmd "$cmd"
done

# Sysroot: headers and libraries for the target
CROSS_SYSROOT="${CROSS_PREFIX:-/opt/cross-toolchain}/i686-w64-mingw32"
check_dir  "$CROSS_SYSROOT/include"         "cross sysroot include"
check_dir  "$CROSS_SYSROOT/lib"             "cross sysroot lib"
check_file "$CROSS_SYSROOT/include/stdio.h" "cross sysroot stdio.h"
check_file "$CROSS_SYSROOT/lib/libpthread.a" "cross sysroot libpthread.a"
check_file "$CROSS_SYSROOT/lib/libmsvcrt.a"  "cross sysroot libmsvcrt.a"

# CMake toolchain file for cross
check_file "/opt/cmake-toolchain/cross-toolchain.cmake" "cross CMake toolchain file"

# ── Phase 1b: native toolchain (Win32 executables run via Wine) ──────────────
log "=== Native toolchain layout ==="

NATIVE="${NATIVE_PREFIX:-/opt/native-toolset}"

NATIVE_BINS=(
    gcc.exe
    g++.exe
    ar.exe
    ld.exe
    nm.exe
    objdump.exe
    windres.exe
)
for exe in "${NATIVE_BINS[@]}"; do
    check_file "$NATIVE/bin/$exe" "native $exe"
done

# Native sysroot
NATIVE_SYSROOT="$NATIVE/i686-w64-mingw32"
check_dir  "$NATIVE_SYSROOT/include"         "native sysroot include"
check_dir  "$NATIVE_SYSROOT/lib"             "native sysroot lib"
check_file "$NATIVE_SYSROOT/include/stdio.h" "native sysroot stdio.h"

# Wine wrapper scripts used by native-toolchain.cmake
for sh in wine-gcc.sh wine-gxx.sh wine-windres.sh; do
    check_file "/opt/cmake-toolchain/$sh" "native cmake wrapper $sh"
done

# CMake toolchain file for native
check_file "/opt/cmake-toolchain/native-toolchain.cmake" "native CMake toolchain file"

# ── Summary ──────────────────────────────────────────────────────────────────
log "=== Layout verification: $PASS passed, $FAIL failed ==="

if [[ "$FAIL" -gt 0 ]]; then
    die "Toolchain layout verification FAILED ($FAIL missing items)"
fi
