#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# build-native-mingw-deps.sh - Build GMP/MPFR/MPC for native-host GCC
# ============================================================================

source "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"

REPO_ROOT="$ROOT_DIR"
GCC_SRC="$REPO_ROOT/src/gcc"
BUILD_ROOT="$REPO_ROOT/build/native-mingw-deps"
INSTALL_DIR="$REPO_ROOT/out/mingw-deps"
CROSS_BIN_DIR="$REPO_ROOT/out/toolchain/bin"

skip_if_done build-native-mingw-deps
require_dir "$GCC_SRC" "Missing GCC sources at $GCC_SRC"
require_dir "$CROSS_BIN_DIR" "Cross-toolchain not found at $CROSS_BIN_DIR"
require_file "$GCC_SRC/contrib/download_prerequisites" "Missing GCC contrib/download_prerequisites helper"

export PATH="$CROSS_BIN_DIR:$PATH"
mkdir -p "$BUILD_ROOT" "$INSTALL_DIR"

ensure_prereq_sources() {
  if [[ -d "$GCC_SRC/gmp" && -d "$GCC_SRC/mpfr" && -d "$GCC_SRC/mpc" ]]; then
    return 0
  fi

  log "populating GCC prerequisite sources via contrib/download_prerequisites"
  run_logged build-native-mingw-deps.log bash "$GCC_SRC/contrib/download_prerequisites" --directory="$GCC_SRC" --no-isl

  require_dir "$GCC_SRC/gmp" "Missing GCC prerequisite source: $GCC_SRC/gmp"
  require_dir "$GCC_SRC/mpfr" "Missing GCC prerequisite source: $GCC_SRC/mpfr"
  require_dir "$GCC_SRC/mpc" "Missing GCC prerequisite source: $GCC_SRC/mpc"
}

configure_make_install() {
  local name="$1"
  local source_dir="$2"
  local build_dir="$3"
  shift 3

  rm -rf "$build_dir"
  mkdir -p "$build_dir"
  pushd "$build_dir" >/dev/null

  run_logged build-native-mingw-deps.log \
    env \
      CC="$TARGET-gcc" \
      CXX="$TARGET-g++" \
      AR="$TARGET-ar" \
      RANLIB="$TARGET-ranlib" \
      "$source_dir/configure" \
      --build=x86_64-pc-linux-gnu \
      --host="$TARGET" \
      --prefix="$INSTALL_DIR" \
      --disable-shared \
      --enable-static \
      "$@"

  run_logged build-native-mingw-deps.log make -j"$JOBS"
  run_logged build-native-mingw-deps.log make install

  popd >/dev/null
}

ensure_prereq_sources

log "building native GMP into $INSTALL_DIR"
configure_make_install \
  gmp \
  "$GCC_SRC/gmp" \
  "$BUILD_ROOT/gmp" \
  --disable-assembly

log "building native MPFR into $INSTALL_DIR"
configure_make_install \
  mpfr \
  "$GCC_SRC/mpfr" \
  "$BUILD_ROOT/mpfr" \
  --with-gmp="$INSTALL_DIR"

log "building native MPC into $INSTALL_DIR"
configure_make_install \
  mpc \
  "$GCC_SRC/mpc" \
  "$BUILD_ROOT/mpc" \
  --with-gmp="$INSTALL_DIR" \
  --with-mpfr="$INSTALL_DIR"

require_file "$INSTALL_DIR/lib/libgmp.a" "Missing native GMP static library"
require_file "$INSTALL_DIR/lib/libmpfr.a" "Missing native MPFR static library"
require_file "$INSTALL_DIR/lib/libmpc.a" "Missing native MPC static library"

mark_done build-native-mingw-deps
log "native mingw dependency build completed"
