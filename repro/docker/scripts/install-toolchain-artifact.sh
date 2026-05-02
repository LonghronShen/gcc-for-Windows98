#!/usr/bin/env bash

set -euo pipefail

ARTIFACT="$1"
PREFIX="$2"

echo "Installing $ARTIFACT to $PREFIX..."

rm -rf "$PREFIX"
mkdir -p "$PREFIX"

tar -C "$PREFIX" --strip-components=1 -xJf "$ARTIFACT"

echo "Installation complete."
