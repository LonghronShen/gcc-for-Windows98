#!/usr/bin/env bash

set -euo pipefail

ROOT="$NATIVE_PREFIX"

export WINEPREFIX="${WINEPREFIX:-$HOME/.wine}"
export WINEARCH=win32
export WINEPATH="Z:${ROOT//\//\\}\\bin"

exec wine "${ROOT}/bin/g++.exe" "$@"
