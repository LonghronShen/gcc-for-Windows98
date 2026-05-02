#!/usr/bin/env python3
"""Reusable helpers for reading and validating build matrix selectors."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Dict, List


def load_config(path: Path) -> Dict[str, Any]:
    """Load and return config JSON data from disk."""
    try:
        with path.open("r", encoding="utf-8") as f:
            loaded = json.load(f)
    except OSError as exc:
        raise ValueError(f"ERROR: cannot read config file: {path}: {exc}") from exc
    except json.JSONDecodeError as exc:
        raise ValueError(f"ERROR: invalid JSON in config file: {path}: {exc}") from exc

    if not isinstance(loaded, dict):
        raise ValueError(f"ERROR: config file must contain a JSON object: {path}")

    return loaded


def get_matrix_entries(config: Dict[str, Any]) -> List[Dict[str, Any]]:
    """Return matrix entries, validating shape and emptiness."""
    matrix = config.get("matrix") or []
    if not isinstance(matrix, list) or not matrix:
        raise ValueError("ERROR: config.json has no matrix entries")

    entries: List[Dict[str, Any]] = []
    for entry in matrix:
        if isinstance(entry, dict):
            entries.append(entry)
    if not entries:
        raise ValueError("ERROR: config.json has no usable matrix entries")
    return entries


def available_labels(matrix: List[Dict[str, Any]]) -> List[str]:
    """Return non-empty matrix.version labels as strings."""
    labels: List[str] = []
    for entry in matrix:
        version = entry.get("version")
        if version:
            labels.append(str(version))
    return labels


def select_matrix_entry(config: Dict[str, Any], selector: str) -> Dict[str, Any]:
    """Select one matrix entry by index or version label, or raise ValueError."""
    matrix = get_matrix_entries(config)

    if selector.isdigit():
        idx = int(selector)
        if idx < 0 or idx >= len(matrix):
            raise ValueError(
                f"ERROR: --matrix index {selector} out of range (0..{len(matrix)-1})"
            )
        return matrix[idx]

    for entry in matrix:
        if str(entry.get("version", "")) == selector:
            return entry

    labels = ", ".join(available_labels(matrix))
    raise ValueError(
        f"ERROR: --matrix '{selector}' not found. Available labels: {labels or '<none>'}"
    )


def validate_matrix_selector(config_path: Path, selector: str) -> Dict[str, Any]:
    """Load config file and validate a matrix selector, returning selected entry."""
    config = load_config(config_path)
    return select_matrix_entry(config, selector)
