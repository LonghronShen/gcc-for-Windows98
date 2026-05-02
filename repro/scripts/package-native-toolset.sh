#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# package-native-toolset.sh - Package native toolset
# ============================================================================
# Replaces the old confusing flow:
#   build-native-toolset-stage.sh (copy from non-existent paths)
#   -> package-native-toolset.sh (package from yet another path)
# New simplified flow: just package out/native-toolset directly.

source "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"

require_step verify-native-compiler-features "run verify-compiler-features.sh native first"

REPO_ROOT="$ROOT_DIR"
SOURCE_DIR="$REPO_ROOT/out/native-toolset"
PACKAGE_DIR="$REPO_ROOT/out/package"
PACKAGE_NAME="gcc-win98-native-toolset.tar.xz"
PACKAGE_PATH="$PACKAGE_DIR/$PACKAGE_NAME"

# === Ensure libgcc.a and libgcc_s_dw2-1.dll are in target lib dir ===
LIBGCC_A_SRC="$SOURCE_DIR/lib/gcc/${TARGET}/11.1.0/libgcc.a"
LIBGCC_A_DST="$SOURCE_DIR/${TARGET}/lib/libgcc.a"
if [ -f "$LIBGCC_A_SRC" ] && [ ! -f "$LIBGCC_A_DST" ]; then
  cp -v "$LIBGCC_A_SRC" "$LIBGCC_A_DST"
fi
# Copy shared libgcc from cross toolchain if missing (same version, same platform)
SHARED_DLL_SRC="$REPO_ROOT/out/toolchain/${TARGET}/lib/libgcc_s_dw2-1.dll"
SHARED_DLL_DST="$SOURCE_DIR/${TARGET}/lib/libgcc_s_dw2-1.dll"
if [ -f "$SHARED_DLL_SRC" ] && [ ! -f "$SHARED_DLL_DST" ]; then
  cp -v "$SHARED_DLL_SRC" "$SHARED_DLL_DST"
  cp -v "$SHARED_DLL_SRC" "$SOURCE_DIR/lib/gcc/${TARGET}/11.1.0/"
fi
SHARED_A_SRC="$REPO_ROOT/out/toolchain/${TARGET}/lib/libgcc_s.a"
SHARED_A_DST="$SOURCE_DIR/${TARGET}/lib/libgcc_s.a"
if [ -f "$SHARED_A_SRC" ] && [ ! -f "$SHARED_A_DST" ]; then
  cp -v "$SHARED_A_SRC" "$SHARED_A_DST"
fi

# === Verify source exists ===
require_dir "$SOURCE_DIR/bin" "Native toolset not found at $SOURCE_DIR. Run build-native-host-gcc.sh first."

# === Create package ===
mkdir -p "$PACKAGE_DIR"
rm -f "$PACKAGE_PATH"

echo "Packaging native toolset..."
echo "  Source: $SOURCE_DIR"
echo "  Output: $PACKAGE_PATH"

# Use xz -1 (fast, low memory) to avoid OOM issues on large toolsets
XZ_OPT=-1 tar -C "$REPO_ROOT/out" \
    --transform 's,^native-toolset,gcc_win98,' \
    -cJf "$PACKAGE_PATH" \
    native-toolset

echo ""
echo "Package created successfully!"
echo ""
stat --printf='Path: %n\nSize: %s bytes\n' "$PACKAGE_PATH"
sha256sum "$PACKAGE_PATH"
mark_done package-native-toolset
