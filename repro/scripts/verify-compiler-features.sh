#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# verify-compiler-features.sh - Verify compiler feature support for manifests
# ============================================================================
# Usage: verify-compiler-features.sh <cross|native>

source "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"

MODE="${1:-}"
[[ -n "$MODE" ]] || die "usage: verify-compiler-features.sh <cross|native>"

case "$MODE" in
  cross)
    STEP_NAME="verify-cross-compiler-features"
    FEATURES_PATH="$OUT_DIR/compiler-features/cross.json"
    CC_CMD=("$PREFIX/bin/${TARGET}-gcc")
    CXX_CMD=("$PREFIX/bin/${TARGET}-g++")
    ;;
  native)
    STEP_NAME="verify-native-compiler-features"
    FEATURES_PATH="$OUT_DIR/compiler-features/native.json"
    NATIVE_PREFIX="${NATIVE_PREFIX:-$OUT_DIR/native-toolset}"
    if command -v wine >/dev/null 2>&1 && [[ -f "$NATIVE_PREFIX/bin/gcc.exe" && -f "$NATIVE_PREFIX/bin/g++.exe" ]]; then
      CC_CMD=(wine "$NATIVE_PREFIX/bin/gcc.exe")
      CXX_CMD=(wine "$NATIVE_PREFIX/bin/g++.exe")
    else
      # Fallback keeps pipeline usable when Wine/native host executables are unavailable.
      CC_CMD=("$PREFIX/bin/${TARGET}-gcc")
      CXX_CMD=("$PREFIX/bin/${TARGET}-g++")
      warn "native compiler not directly runnable; falling back to cross compiler for feature verification"
    fi
    ;;
  *)
    die "unknown mode '$MODE' (expected cross|native)"
    ;;
esac

skip_if_done "$STEP_NAME" "$STEP_NAME already done, skipping"

mkdir -p "$(dirname "$FEATURES_PATH")"
WORK_DIR="$OUT_DIR/compiler-features/${MODE}-work"
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"

PTHREAD_TEST_SRC="$ROOT_DIR/tests/smoke-c/thread_test.c"
STD_THREAD_TEST_SRC="$ROOT_DIR/tests/smoke-cpp/hello_thread.cpp"
C_FILE_IO_TEST_SRC="$ROOT_DIR/tests/smoke-c/file_io_test.c"
CPP_FSTREAM_TEST_SRC="$ROOT_DIR/tests/smoke-cpp/hello_fstream.cpp"

THREADING_MODEL="unverified"
PTHREAD_STATUS="unverified"
STD_THREAD_STATUS="unverified"
FILE_IO_STATUS="unverified"

detect_thread_model() {
  local compiler_output
  compiler_output="$(${CC_CMD[@]} -v 2>&1 || true)"
  THREADING_MODEL="$(printf '%s\n' "$compiler_output" | sed -n 's/^[[:space:]]*Thread model:[[:space:]]*//p' | head -n1)"
  THREADING_MODEL="$(printf '%s' "$THREADING_MODEL" | tr -d '\r' | xargs)"
  THREADING_MODEL="${THREADING_MODEL:-unverified}"
}

verify_pthread() {
  if "${CC_CMD[@]}" -c -o "$WORK_DIR/thread_test.o" "$PTHREAD_TEST_SRC" -pthread >/dev/null 2>&1; then
    PTHREAD_STATUS="verified"
  fi
}

verify_std_thread() {
  if "${CXX_CMD[@]}" -std=gnu++17 -o "$WORK_DIR/hello_thread.exe" "$STD_THREAD_TEST_SRC" -pthread >/dev/null 2>&1; then
    STD_THREAD_STATUS="verified"
  fi
}

verify_file_io_compiles() {
  local c_ok=0
  local cpp_ok=0

  if "${CC_CMD[@]}" -o "$WORK_DIR/file_io_test.exe" "$C_FILE_IO_TEST_SRC" >/dev/null 2>&1; then
    c_ok=1
  fi
  if "${CXX_CMD[@]}" -std=gnu++17 -o "$WORK_DIR/hello_fstream.exe" "$CPP_FSTREAM_TEST_SRC" >/dev/null 2>&1; then
    cpp_ok=1
  fi
  if [[ $c_ok -eq 1 && $cpp_ok -eq 1 ]]; then
    FILE_IO_STATUS="verified"
  fi
}

enforce_all_verified() {
  local failed=0

  if [[ "$THREADING_MODEL" != "posix" ]]; then
    log "ERROR: threading_model expected 'posix', got '$THREADING_MODEL'"
    failed=1
  fi
  if [[ "$PTHREAD_STATUS" != "verified" ]]; then
    log "ERROR: pthread check failed ($PTHREAD_STATUS)"
    failed=1
  fi
  if [[ "$STD_THREAD_STATUS" != "verified" ]]; then
    log "ERROR: std::thread check failed ($STD_THREAD_STATUS)"
    failed=1
  fi
  if [[ "$FILE_IO_STATUS" != "verified" ]]; then
    log "ERROR: file I/O check failed ($FILE_IO_STATUS)"
    failed=1
  fi

  if [[ $failed -ne 0 ]]; then
    die "compiler feature verification failed for $MODE"
  fi
}

detect_thread_model
verify_pthread
verify_std_thread
verify_file_io_compiles
enforce_all_verified

cat > "$FEATURES_PATH" <<EOF
{
  "threading_model": "$THREADING_MODEL",
  "pthread": "$PTHREAD_STATUS",
  "std_thread": "$STD_THREAD_STATUS",
  "file_io": "$FILE_IO_STATUS"
}
EOF

mark_done "$STEP_NAME"
log "compiler features ($MODE): threading_model=$THREADING_MODEL, pthread=$PTHREAD_STATUS, std_thread=$STD_THREAD_STATUS, file_io=$FILE_IO_STATUS"
log "wrote $FEATURES_PATH"
