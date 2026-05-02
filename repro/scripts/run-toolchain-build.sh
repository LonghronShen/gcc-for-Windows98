#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# run-toolchain-build.sh - Master orchestration script for gcc-for-Windows98 toolchain build
# ============================================================================
# Description: Builds the complete cross and native Win98 toolchain from source
#
# Environment: Steps execute inside the appropriate Docker container:
#   [host]    – orchestration only (argument parsing, logging, dispatch)
#   [builder] – cross/native toolchain build (docker compose exec toolchain-builder)
#
# Usage: ./scripts/run-toolchain-build.sh [--jobs N] [--target TARGET] [--resume [STEP]] [--generate-patches] [--help|-h]
#   --jobs N      Parallel build jobs (default: auto-detect)
#   --target T    Target triplet (default: i686-w64-mingw32)
#   --resume [S]  Resume from step S (or auto-detect last completed step)
#   --generate-patches  Regenerate patch folders before prepare steps
#   --help, -h    Show this help and exit
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Source common utilities (also loads docker helpers: builder_exec, builder_script,
# is_done_in_builder, mark_done_in_builder)
source "$SCRIPT_DIR/lib/common.sh"

# --- Argument Parsing ---------------------------------------------------------
RESUME_MODE=""
RESUME_FROM=""
GENERATE_PATCHES="${GENERATE_PATCHES:-0}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --jobs)
      JOBS="$2"
      export JOBS
      shift 2
      ;;
    --target)
      TARGET="$2"
      export TARGET
      shift 2
      ;;
    --resume)
      RESUME_MODE="yes"
      if [[ $# -gt 1 && ! "$2" =~ ^-- ]]; then
        RESUME_FROM="$2"
        shift 2
      else
        shift
      fi
      ;;
    --generate-patches)
      GENERATE_PATCHES="1"
      export GENERATE_PATCHES
      shift
      ;;
    --help|-h)
      sed -n '/^# ===/,/^# ===/p' "$0" | sed 's/^# //'
      exit 0
      ;;
    *)
      die "Unknown option: $1 (try --help)"
      ;;
  esac
done

# --- Pre-flight Check --------------------------------------------------------
check_containers() {
  if ! docker compose -f "$PROJECT_DIR/docker-compose.yml" ps --services --filter "status=running" 2>/dev/null | grep -q .; then
    echo "ERROR: No containers are running. Start them with:"
    echo "  docker compose up -d toolchain-builder"
    exit 1
  fi
  if ! docker compose -f "$PROJECT_DIR/docker-compose.yml" ps --services --filter "status=running" 2>/dev/null | grep -q "toolchain-builder"; then
    echo "ERROR: toolchain-builder container is not running. Start it with:"
    echo "  docker compose up -d toolchain-builder"
    exit 1
  fi
}

# --- Step Definitions --------------------------------------------------------
# Each step: "status_name|script_name|description|env"
#   env = builder
declare -a CROSS_STEPS=(
  "fetch-sources|fetch-sources.sh|Fetch source trees|builder"
  "generate-patches|generate-patches.sh|Generate versioned patch series|builder"
  "prepare-mingw-w64|prepare-mingw-w64.sh|Prepare mingw-w64 sources|builder"
  "build-binutils|build-cross-binutils.sh|Build cross binutils|builder"
  "build-mingw-w64|build-cross-mingw-w64.sh|Build mingw-w64 headers & CRT|builder"
  "prepare-gcc|prepare-gcc.sh|Prepare GCC sources|builder"
  "build-gcc-stage1|build-cross-gcc-stage1.sh|Build GCC stage1 (bootstrap)|builder"
  "prepare-pthread9x|prepare-pthread9x.sh|Prepare pthread9x sources|builder"
  "build-pthread9x|build-cross-pthread9x.sh|Build pthread9x|builder"
  "build-gcc|build-cross-gcc.sh|Build GCC final|builder"
  "verify-cross-compiler-features|verify-cross-compiler-features.sh|Verify cross compiler features|builder"
  "package|package-cross-toolset.sh|Package cross toolchain|builder"
  "write-toolchain-manifest-v2|write-toolchain-manifest.sh|Write toolchain manifest|builder"
)

declare -a NATIVE_STEPS=(
  "build-native-mingw-deps|build-native-mingw-deps.sh|Build native mingw dependency libraries|builder"
  "build-native-mingw-w64|build-native-mingw-w64.sh|Build native-host mingw-w64|builder"
  "build-native-host-gcc|build-native-host-gcc.sh|Build native-host GCC|builder"
  "build-native-binutils|build-native-binutils.sh|Build native-host binutils|builder"
  "build-native-pthread9x|build-native-pthread9x.sh|Build native-host pthread9x|builder"
  "verify-native-compiler-features|verify-native-compiler-features.sh|Verify native compiler features|builder"
  "verify-native-win98-capability|verifiers/verify-native-package.sh|Verify native toolset Win98 capability|builder"
  "package-native-toolset|package-native-toolset.sh|Package native toolset|builder"
  "write-native-toolchain-manifest-v2|write-toolchain-manifest.sh|Write native toolchain manifest|builder"
)

# --- Resume Logic -----------------------------------------------------------
find_last_completed_step() {
  local last_completed=""
  for step_def in "${CROSS_STEPS[@]}" "${NATIVE_STEPS[@]}"; do
    IFS='|' read -r status_name _ _ _ <<< "$step_def"
    if is_done_in_builder "$status_name"; then
      last_completed="$status_name"
    fi
  done
  echo "$last_completed"
}

if [[ "$RESUME_MODE" == "yes" ]]; then
  if [[ -z "$RESUME_FROM" ]]; then
    RESUME_FROM="$(find_last_completed_step)"
    if [[ -z "$RESUME_FROM" ]]; then
      log "No completed steps found; starting from beginning"
      RESUME_FROM=""
    else
      log "Auto-resuming after last completed step: $RESUME_FROM"
    fi
  fi
fi

# --- Logging Setup ----------------------------------------------------------
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
MASTER_LOG="$LOG_DIR/run-toolchain-build-${TIMESTAMP}.log"
mkdir -p "$LOG_DIR"

tee -a "$MASTER_LOG" <<EOF
========================================
gcc-for-Windows98 Toolchain Build
Started: $(date -Iseconds)
Project: $PROJECT_DIR
Jobs: $JOBS
Target: $TARGET
Resume: ${RESUME_MODE:-no} ${RESUME_FROM:+($RESUME_FROM)}
========================================
EOF

# --- Step Runner ------------------------------------------------------------
run_step() {
    local status_name="$1"
    local script_name="$2"
    local description="$3"
    local env="$4"
    local step_log="$LOG_DIR/${script_name%.sh}-${TIMESTAMP}.log"

    mkdir -p "$(dirname "$step_log")"

    # Skip steps already done
    if is_done_in_builder "$status_name"; then
      echo "[$(date +%H:%M:%S)] [host] === SKIP (done): $description ===" | tee -a "$MASTER_LOG"
      return 0
    fi

    # Resume: skip steps before the resume point
    if [[ -n "$RESUME_FROM" && "$status_name" != "$RESUME_FROM" ]]; then
        for step_def in "${CROSS_STEPS[@]}" "${NATIVE_STEPS[@]}"; do
            IFS='|' read -r sn _ _ _ <<< "$step_def"
            if [[ "$sn" == "$RESUME_FROM" ]]; then
                break
            fi
            if [[ "$sn" == "$status_name" ]]; then
                echo "[$(date +%H:%M:%S)] [host] === SKIP (resume): $description ===" | tee -a "$MASTER_LOG"
                return 0
            fi
        done
    fi

    echo "" | tee -a "$MASTER_LOG"
    echo "[$(date +%H:%M:%S)] [${env}] === STEP: $description ($script_name) ===" | tee -a "$MASTER_LOG"
    echo "[$(date +%H:%M:%S)] [host] Executing in container: toolchain-builder" | tee -a "$MASTER_LOG"

    if builder_script "$script_name" > >(tee "$step_log") 2>&1; then
      echo "[$(date +%H:%M:%S)] [builder] === OK: $description ===" | tee -a "$MASTER_LOG"
      return 0
    else
      local exit_code=$?
      echo "[$(date +%H:%M:%S)] [builder] === FAILED: $description (exit=$exit_code) ===" | tee -a "$MASTER_LOG"
      echo "See log: $step_log" | tee -a "$MASTER_LOG"
      return $exit_code
    fi
}

# --- Pre-flight Checks -------------------------------------------------------
echo "=== Pre-flight checks ===" | tee -a "$MASTER_LOG"
check_containers

# --- Build Execution ---------------------------------------------------------
FAILED=0
FAILED_STEP=""

# Cross toolchain
echo "" | tee -a "$MASTER_LOG"
echo "[$(date +%H:%M:%S)] [host] === PHASE: CROSS toolchain ===" | tee -a "$MASTER_LOG"
for step_def in "${CROSS_STEPS[@]}"; do
    IFS='|' read -r status_name script_name description env <<< "$step_def"
    if ! run_step "$status_name" "$script_name" "$description" "$env"; then
        FAILED=1
        FAILED_STEP="$description ($script_name)"
        break
    fi
done

# Native toolchain (only if cross succeeded)
if [[ $FAILED -eq 0 ]]; then
    echo "" | tee -a "$MASTER_LOG"
    echo "[$(date +%H:%M:%S)] [host] === PHASE: NATIVE toolchain ===" | tee -a "$MASTER_LOG"
    for step_def in "${NATIVE_STEPS[@]}"; do
        IFS='|' read -r status_name script_name description env <<< "$step_def"
        if ! run_step "$status_name" "$script_name" "$description" "$env"; then
            FAILED=1
            FAILED_STEP="$description ($script_name)"
            break
        fi
    done
fi

# --- Summary ----------------------------------------------------------------
echo "" | tee -a "$MASTER_LOG"
if [[ $FAILED -eq 0 ]]; then
    echo "[$(date +%H:%M:%S)] [host] === TOOLCHAIN BUILD COMPLETED ===" | tee -a "$MASTER_LOG"
    echo "Artifacts in: $PROJECT_DIR/out/package/" | tee -a "$MASTER_LOG"
    echo "Master log: $MASTER_LOG" | tee -a "$MASTER_LOG"
    exit 0
else
    echo "[$(date +%H:%M:%S)] [host] === TOOLCHAIN BUILD FAILED ===" | tee -a "$MASTER_LOG"
    echo "Failed at: $FAILED_STEP" | tee -a "$MASTER_LOG"
    echo "To resume: ./scripts/run-toolchain-build.sh --resume" | tee -a "$MASTER_LOG"
    echo "Master log: $MASTER_LOG" | tee -a "$MASTER_LOG"
    exit 1
fi
