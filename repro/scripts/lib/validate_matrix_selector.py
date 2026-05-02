#!/usr/bin/env python3
"""CLI validation for --matrix selector against config.json."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from matrix_config import validate_matrix_selector

def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("config", type=Path, help="Path to config.json")
    parser.add_argument("selector", help="Matrix index or version label")
    return parser.parse_args(argv)

def main(argv: list[str]) -> int:
    args = parse_args(argv)
    try:
        validate_matrix_selector(args.config, args.selector)
    except ValueError as exc:
        print(str(exc), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
