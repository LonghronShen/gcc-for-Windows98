#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# fetch-sources.sh - Fetch source trees for gcc-for-Windows98
# ============================================================================

source "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"

require_file "$ROOT_DIR/config.json" "missing config.json; expected at $ROOT_DIR/config.json"

verify_checkout_ref() {
	local repo_dir="$1"
	local expected_ref="$2"
	local label="$3"
	local head
	head="$(git -C "$repo_dir" rev-parse HEAD)"

	if [[ "$expected_ref" =~ ^[0-9a-fA-F]{7,40}$ ]]; then
		if [[ "$head" != "$expected_ref"* ]]; then
			die "$label revision mismatch: expected commit prefix $expected_ref, got $head"
		fi
	else
		local resolved
		# Dereference annotated tags to get the commit, not the tag object
		resolved="$(git -C "$repo_dir" rev-parse "$expected_ref^{commit}" 2>/dev/null || git -C "$repo_dir" rev-parse "$expected_ref")"
		if [[ "$head" != "$resolved" ]]; then
			die "$label revision mismatch: expected $expected_ref -> $resolved, got $head"
		fi
	fi

	log "$label verified at $head"
}

log "fetching source trees"
log "gcc: source=$GCC_FETCH_SOURCE ref=$GCC_FETCH_REF"
ensure_shallow_git_checkout "$GCC_FETCH_SOURCE" "$GCC_FETCH_REF" "$SRC_DIR/gcc"
verify_checkout_ref "$SRC_DIR/gcc" "$GCC_FETCH_REF" "gcc"

log "binutils: source=$BINUTILS_FETCH_SOURCE ref=$BINUTILS_FETCH_REF"
ensure_shallow_git_checkout "$BINUTILS_FETCH_SOURCE" "$BINUTILS_FETCH_REF" "$SRC_DIR/binutils-gdb"
verify_checkout_ref "$SRC_DIR/binutils-gdb" "$BINUTILS_FETCH_REF" "binutils"

log "mingw-w64: source=$MINGW_W64_FETCH_SOURCE ref=$MINGW_W64_FETCH_REF"
ensure_shallow_git_checkout "$MINGW_W64_FETCH_SOURCE" "$MINGW_W64_FETCH_REF" "$SRC_DIR/mingw-w64"
verify_checkout_ref "$SRC_DIR/mingw-w64" "$MINGW_W64_FETCH_REF" "mingw-w64"

log "pthread9x: source=$PTHREAD9X_FETCH_SOURCE ref=$PTHREAD9X_FETCH_REF"
ensure_shallow_git_checkout "$PTHREAD9X_FETCH_SOURCE" "$PTHREAD9X_FETCH_REF" "$SRC_DIR/pthread9x"
verify_checkout_ref "$SRC_DIR/pthread9x" "$PTHREAD9X_FETCH_REF" "pthread9x"

log "using container-provided dev packages for gmp/mpfr/mpc in the first reproduction pass"
mark_done fetch-sources
log "fetch complete"
