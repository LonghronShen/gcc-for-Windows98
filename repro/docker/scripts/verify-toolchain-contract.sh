#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <artifact.tar.xz> <install-prefix>" >&2
    exit 2
fi

ARTIFACT="$1"
PREFIX="$2"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
INSTALL_SCRIPT="$ROOT/docker/scripts/install-toolchain-artifact.sh"

echo "Verifying toolchain contract at $ARTIFACT -> $PREFIX..."

[[ -f "$ARTIFACT" ]] || { echo "Error: Artifact not found: $ARTIFACT" >&2; exit 1; }
[[ -x "$INSTALL_SCRIPT" ]] || { echo "Error: Install script not executable: $INSTALL_SCRIPT" >&2; exit 1; }

bash "$INSTALL_SCRIPT" "$ARTIFACT" "$PREFIX"

REQUIRED_TOOLS=(
    "i686-w64-mingw32-gcc"
    "i686-w64-mingw32-g++"
    "i686-w64-mingw32-objdump"
    "i686-w64-mingw32-windres"
    "i686-w64-mingw32-ar"
    "i686-w64-mingw32-nm"
)

for tool in "${REQUIRED_TOOLS[@]}"; do
    if [[ ! -x "$PREFIX/bin/$tool" ]]; then
        echo "Error: Required tool $tool not found or not executable in $PREFIX/bin"
        exit 1
    fi
done

echo "Basic tool existence check passed."
"$PREFIX/bin/i686-w64-mingw32-gcc" --version | head -n 1

SMOKE_DIR="$(mktemp -d)"
trap 'rm -rf "$SMOKE_DIR"' EXIT
cat > "$SMOKE_DIR/contract-smoke.c" <<'EOF'
int main(void) { return 0; }
EOF
"$PREFIX/bin/i686-w64-mingw32-gcc" -c "$SMOKE_DIR/contract-smoke.c" -o "$SMOKE_DIR/contract-smoke.o"
[[ -f "$SMOKE_DIR/contract-smoke.o" ]] || { echo "Error: Minimal C compile did not produce object file" >&2; exit 1; }

echo "Minimal C compile check passed."
echo "Toolchain contract verification passed."
