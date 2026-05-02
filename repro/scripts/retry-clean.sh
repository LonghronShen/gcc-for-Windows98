#!/usr/bin/env bash
set -euo pipefail
# retry-clean.sh — smart retry: git-reset sources, keep clones intact
# Only cleans build artifacts (out/, build/, logs/), NEVER deletes src/

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "=== retry-clean: git-reset sources, keep clones ==="

# Reset source repos (preserve cloned repos, just undo modifications)
for repo in gcc binutils-gdb mingw-w64 pthread9x; do
  if [[ -d "$PROJECT_DIR/src/$repo/.git" ]]; then
    echo "  git reset $repo..."
    git -C "$PROJECT_DIR/src/$repo" reset --hard HEAD 2>/dev/null || true
    git -C "$PROJECT_DIR/src/$repo" clean -fd 2>/dev/null || true
  fi
done

# Clean only build artifacts
echo "  cleaning out/ build/ logs/"
rm -rf "$PROJECT_DIR/out" "$PROJECT_DIR/build" "$PROJECT_DIR/logs" 2>/dev/null || true
mkdir -p "$PROJECT_DIR/out" "$PROJECT_DIR/logs"
touch "$PROJECT_DIR/out/.gitkeep"

echo "=== retry-clean done ==="
