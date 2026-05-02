#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
source "$SCRIPT_DIR/../lib/status-common.sh"

status_section "smoke status markers"
status_step_line "smoke-layout"
status_step_line "smoke-native-pe"
status_step_line "smoke-cmake-cross"
status_step_line "smoke-cmake-native"

status_section "smoke outputs"
status_exists_line "$OUT_DIR/smoke-cross/out"
status_exists_line "$OUT_DIR/smoke-native/out"

CROSS_EXE_COUNT=0
NATIVE_EXE_COUNT=0
if [[ -d "$OUT_DIR/smoke-cross/out" ]]; then
	CROSS_EXE_COUNT="$(find "$OUT_DIR/smoke-cross/out" -type f -iname '*.exe' 2>/dev/null | wc -l | tr -d ' ')"
fi
if [[ -d "$OUT_DIR/smoke-native/out" ]]; then
	NATIVE_EXE_COUNT="$(find "$OUT_DIR/smoke-native/out" -type f -iname '*.exe' 2>/dev/null | wc -l | tr -d ' ')"
fi
status_say "cross_exe_count=$CROSS_EXE_COUNT"
status_say "native_exe_count=$NATIVE_EXE_COUNT"

status_section "smoke pipeline logs"
status_tail_latest "$LOG_DIR" "run-smoke-pipeline-*.log" 40

