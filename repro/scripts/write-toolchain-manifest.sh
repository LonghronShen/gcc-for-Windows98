#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

PACKAGE_DIR="$OUT_DIR/package"
COMPILER_FEATURES_DIR="$OUT_DIR/compiler-features"
MANIFEST_SCRIPT="$ROOT_DIR/scripts/lib/toolchain_manifest.py"
GCC_VERSION="${GCC_COMPONENT_VERSION:?missing GCC_COMPONENT_VERSION from config.json}"

write_manifest() {
  local artifact_filename="$1"
  local manifest_filename="$2"
  local package_kind="$3"
  local status_name="$4"
  local compiler_features_path="$5"
  local artifact_path="$PACKAGE_DIR/$artifact_filename"
  local manifest_path="$PACKAGE_DIR/$manifest_filename"
  local sha256

  if [[ ! -f "$artifact_path" ]]; then
    return 0
  fi

  require_file "$compiler_features_path" "missing compiler feature results: $compiler_features_path"

  sha256=$(sha256sum "$artifact_path" | awk '{print $1}')

  python3 "$MANIFEST_SCRIPT" \
    --artifact-path "$artifact_path" \
    --artifact-filename "$artifact_filename" \
    --sha256 "$sha256" \
    --gcc-version "$GCC_VERSION" \
    --target "$TARGET" \
    --package-kind "$package_kind" \
    --compiler-features-path "$compiler_features_path" \
    --output "$manifest_path"

  mark_done "$status_name"
}

write_manifest \
  "gcc-win98-toolchain.tar.xz" \
  "gcc-win98-toolchain.json" \
  "cross-toolchain" \
  "write-toolchain-manifest-v2" \
  "$COMPILER_FEATURES_DIR/cross.json"

write_manifest \
  "gcc-win98-native-toolset.tar.xz" \
  "gcc-win98-native-toolset.json" \
  "native-toolset" \
  "write-native-toolchain-manifest-v2" \
  "$COMPILER_FEATURES_DIR/native.json"

if [[ ! -f "$PACKAGE_DIR/gcc-win98-toolchain.tar.xz" && ! -f "$PACKAGE_DIR/gcc-win98-native-toolset.tar.xz" ]]; then
  echo "Error: No packaged toolchain artifacts found in $PACKAGE_DIR"
  exit 1
fi
