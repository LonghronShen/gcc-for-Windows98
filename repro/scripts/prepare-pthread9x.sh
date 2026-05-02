#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# prepare-pthread9x.sh - Prepare pthread9x sources
# ============================================================================

source "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"

require_dir "$SRC_DIR/pthread9x/.git" "missing pthread9x sources; run fetch-sources.sh first"
skip_if_done prepare-pthread9x

cd "$SRC_DIR/pthread9x"
run_logged prepare-pthread9x.log git reset --hard HEAD
run_logged prepare-pthread9x.log git clean -fd

# Apply versioned patch series for pthread9x.
run_logged prepare-pthread9x.log "$ROOT_DIR/scripts/apply-patches.sh" pthread9x "$PTHREAD9X_COMPONENT_VERSION"

mark_done prepare-pthread9x
log "prepare pthread9x complete"
