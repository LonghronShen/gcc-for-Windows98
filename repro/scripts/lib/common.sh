#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# common.sh - Shared utilities for gcc-for-Windows98 build scripts
# ============================================================================
# Usage: source "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"
# ============================================================================

# --- Directory Layout -------------------------------------------------------
COMMON_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${COMMON_LIB_DIR}/../.." && pwd)"
SRC_DIR="$ROOT_DIR/src"
BUILD_DIR="$ROOT_DIR/build"
LOG_DIR="$ROOT_DIR/logs"
OUT_DIR="$ROOT_DIR/out"
PATCH_DIR="$ROOT_DIR/patches"

# --- Build Configuration ----------------------------------------------------
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 2)}"
TARGET="${TARGET:-i686-w64-mingw32}"
PREFIX="${PREFIX:-$OUT_DIR/toolchain}"
MATRIX="${MATRIX:-0}"

# Status sentinel scope prevents false resume/skip across different build
# configurations (e.g., matrix/target changes).
STATUS_SCOPE="${STATUS_SCOPE:-${TARGET}__m${MATRIX}}"

# --- Dependency Version Configuration (populated from config.json) ---------
GMP_VERSION=""
MPFR_VERSION=""
MPC_VERSION=""

# --- Source Fetch Configuration (populated from config.json) ----------------
# These are intentionally empty here; load_fetch_config_from_json fills them
# in from config.json, which is the single source of truth for component
# sources and revisions.
GCC_FETCH_SOURCE=""
GCC_FETCH_REF=""

BINUTILS_FETCH_SOURCE=""
BINUTILS_FETCH_REF=""

MINGW_W64_FETCH_SOURCE=""
MINGW_W64_FETCH_REF=""

PTHREAD9X_FETCH_SOURCE=""
PTHREAD9X_FETCH_REF=""

# Component release/version values from config.json matrix (distinct from fetch refs).
GCC_COMPONENT_VERSION=""
BINUTILS_COMPONENT_VERSION=""
MINGW_W64_COMPONENT_VERSION=""
PTHREAD9X_COMPONENT_VERSION=""
MATRIX_SELECTED_LABEL=""

load_fetch_config_from_json() {
  local config_file="$ROOT_DIR/config.json"
  [[ -f "$config_file" ]] || return 0
  command -v python3 >/dev/null 2>&1 || {
  printf '[%s] %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "WARN: python3 not found; using built-in fetch defaults" >&2
  return 0
  }

  local parser_script="$COMMON_LIB_DIR/config_matrix_exports.py"
  [[ -f "$parser_script" ]] || {
  printf '[%s] %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "WARN: parser not found: $parser_script; using built-in fetch defaults" >&2
  return 0
  }

  local parsed
  parsed="$({
  python3 "$parser_script" "$config_file" "$MATRIX"
  } 2>/dev/null || true)"

  if [[ -n "$parsed" ]]; then
  eval "$parsed"
  fi
}

load_fetch_config_from_json

# --- Ensure directories exist -----------------------------------------------
mkdir -p "$SRC_DIR" "$BUILD_DIR" "$LOG_DIR" "$OUT_DIR"

# --- Logging ----------------------------------------------------------------
log() {
  printf '[%s] %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$*"
}

die() {
  log "FATAL: $*" >&2
  exit 1
}

warn() {
  log "WARN: $*" >&2
}

# --- Command Execution with Logging -----------------------------------------
run_logged() {
  local log_name="$1"
  shift
  log "running: $*"
  "$@" 2>&1 | tee -a "$LOG_DIR/$log_name"
}

# --- Step / Resume Support --------------------------------------------------
# Usage:
#   require_step <name> <message>     # exits if previous step not done
#   skip_if_done <name> <message>     # exits 0 if this step already done
#   mark_step_done <name>             # mark current step complete
#
# Steps are tracked via $OUT_DIR/.status-<name> sentinel files.

status_file() {
  echo "$OUT_DIR/.status-${STATUS_SCOPE}-$1"
}

status_file_in_builder() {
  echo "/work/out/.status-${STATUS_SCOPE}-$1"
}

mark_done() {
  touch "$(status_file "$1")"
}

is_done() {
  [[ -f "$(status_file "$1")" ]]
}

require_step() {
  local step_name="$1"
  local message="${2:-run $step_name first}"
  if ! is_done "$step_name"; then
    die "$message"
  fi
}

skip_if_done() {
  local step_name="$1"
  local message="${2:-$step_name already done, skipping}"
  if is_done "$step_name"; then
    log "$message"
    exit 0
  fi
}

# --- Directory Guards -------------------------------------------------------
require_dir() {
  local dir="$1"
  local message="${2:-missing directory: $dir}"
  [[ -d "$dir" ]] || die "$message"
}

require_file() {
  local file="$1"
  local message="${2:-missing file: $file}"
  [[ -f "$file" ]] || die "$message"
}

require_executable() {
  local cmd="$1"
  local message="${2:-missing executable: $cmd}"
  command -v "$cmd" >/dev/null 2>&1 || die "$message"
}

# --- Git Helpers ------------------------------------------------------------
ensure_shallow_git_checkout() {
  local repo="$1"
  local ref="$2"
  local dest="$3"

  # If dest already has a valid git repo, try to reuse it (avoid re-clone on retry)
  if [[ -d "$dest/.git" ]]; then
    log "existing clone at $dest, reusing..."
    git -C "$dest" remote set-url origin "$repo" 2>/dev/null || true
    if git -C "$dest" fetch --depth 1 origin "$ref" 2>/dev/null; then
      git -C "$dest" checkout --detach FETCH_HEAD 2>/dev/null && return
    fi
    log "reuse failed, re-cloning..."
    rm -rf "$dest"
  fi

  # If ref looks like a commit SHA, clone and then checkout that exact commit.
  if [[ "$ref" =~ ^[0-9a-fA-F]{7,40}$ ]]; then
    git clone --depth 1 "$repo" "$dest"
    git -C "$dest" fetch --depth 1 origin "$ref"
    git -C "$dest" checkout --detach FETCH_HEAD
    return
  fi

  # Try branch first (ref could be a branch or a tag)
  if git clone --depth 1 --branch "$ref" "$repo" "$dest" 2>/dev/null; then
    return
  fi

  # Fallback: ref is likely a tag — clone default branch, then fetch the tag
  log "clone --branch failed for $ref, trying tag fetch..."
  rm -rf "$dest"
  git clone --depth 1 "$repo" "$dest"
  # Fetch dereferenced tag to get commit objects (not just annotated tag object)
  git -C "$dest" fetch --depth 1 origin "refs/tags/$ref:refs/tags/$ref" 2>/dev/null || \
    git -C "$dest" fetch --depth 1 origin "refs/tags/$ref"
  git -C "$dest" checkout --detach FETCH_HEAD
}

patch_url_for_commit() {
  local repo="$1"
  local sha="$2"
  repo="${repo%.git}"
  printf '%s/commit/%s.patch\n' "$repo" "$sha"
}

apply_remote_commit_patch() {
  local repo="$1"
  local sha="$2"
  local dest="$3"
  local patch_file
  patch_file="$(mktemp)"
  curl -L "$(patch_url_for_commit "$repo" "$sha")" -o "$patch_file"
  git -C "$dest" apply "$patch_file"
  rm -f "$patch_file"
}

revert_remote_commit_patch() {
  local repo="$1"
  local sha="$2"
  local dest="$3"
  local patch_file
  patch_file="$(mktemp)"
  curl -L "$(patch_url_for_commit "$repo" "$sha")" -o "$patch_file"
  git -C "$dest" apply -R "$patch_file"
  rm -f "$patch_file"
}

# --- Header -----------------------------------------------------------------
log "common.sh loaded — ROOT_DIR=$ROOT_DIR, JOBS=$JOBS, TARGET=$TARGET"

# --- Docker Compose Helpers -------------------------------------------------
# These require PROJECT_DIR (the repro/ folder) to be set so that
# docker compose can locate the docker-compose.yml file.
PROJECT_DIR="${PROJECT_DIR:-$(cd "${COMMON_LIB_DIR}/../.." && pwd)}"

# Run a command inside the toolchain-builder container.
builder_exec() {
  docker compose -f "$PROJECT_DIR/docker-compose.yml" exec -T toolchain-builder bash -c "$*"
}

# Run a named script inside the toolchain-builder container.
builder_script() {
  local script_rel="$1"
  shift
  local full_path="/work/scripts/$script_rel"
  docker compose -f "$PROJECT_DIR/docker-compose.yml" exec -T toolchain-builder \
    env JOBS="$JOBS" TARGET="$TARGET" MATRIX="$MATRIX" GENERATE_PATCHES="${GENERATE_PATCHES:-0}" \
    bash "$full_path" "$@"
}

# Create a status file inside the toolchain-builder container (shared /work/out volume).
mark_done_in_builder() {
  local status_name="$1"
  builder_exec "touch $(status_file_in_builder "$status_name")"
}

# Check if a status file exists inside the toolchain-builder container.
is_done_in_builder() {
  local status_name="$1"
  builder_exec "test -f $(status_file_in_builder "$status_name")" 2>/dev/null && return 0 || return 1
}

# Run a command inside the consumer container.
consumer_exec() {
  docker compose -f "$PROJECT_DIR/docker-compose.yml" exec -T consumer bash -c "$*"
}

# Run a named script inside the consumer container.
consumer_script() {
  local script_rel="$1"
  shift
  local full_path="/workspace/scripts/$script_rel"
  docker compose -f "$PROJECT_DIR/docker-compose.yml" exec -T consumer bash "$full_path" "$@"
}
