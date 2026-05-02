#!/usr/bin/env python3
"""
generate-patches.py - Dynamically generate Win98 compatibility patches.

Usage:
    python3 patches/generate-patches.py --gcc-version=11.1.0 --source-dir=src/gcc
    python3 patches/generate-patches.py --mingw-w64-version=master --source-dir=src/mingw-w64
    python3 patches/generate-patches.py --pthread9x-version=master --source-dir=src/pthread9x

Output:
    patches/{component}/{version}/0001-*.patch ... + series.txt
"""

import argparse
import importlib.util
import shutil
import sys
from pathlib import Path
from types import ModuleType
from typing import Callable, Type

from base import PatchSet


SCRIPT_DIR = Path(__file__).resolve().parent


def load_module(module_name: str, module_path: Path) -> ModuleType:
    """Load a Python module directly from file path."""
    spec = importlib.util.spec_from_file_location(module_name, module_path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Failed to load module: {module_path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def load_gcc_patchset_class():
    module_path = SCRIPT_DIR / "gcc" / "patch.py"
    module = load_module("patches_gcc_patch", module_path)
    return module.GCCPatchSet


def load_mingw_patchset_class():
    module_path = SCRIPT_DIR / "mingw-w64" / "patch.py"
    module = load_module("patches_mingw_w64_patch", module_path)
    return module.MinGW_W64PatchSet


def load_pthread9x_patchset_class():
    module_path = SCRIPT_DIR / "pthread9x" / "patch.py"
    module = load_module("patches_pthread9x_patch", module_path)
    return module.Pthread9xPatchSet


def clean_output_dir(patches_dir: Path) -> None:
    """Ensure patch output directory starts from a clean state."""
    if patches_dir.exists():
        print(f"INFO: Existing patch output detected, cleaning: {patches_dir}")
        shutil.rmtree(patches_dir)
    patches_dir.mkdir(parents=True, exist_ok=True)


def resolve_existing_version_dir(component: str, selector: str, default_version: str) -> str:
    """Pick a patch version folder for a component using a selector string."""
    component_root = SCRIPT_DIR / component

    selected = selector.strip() if selector else ""
    if selected and (component_root / selected).is_dir():
        return selected

    preferred = component_root / default_version
    if preferred.is_dir():
        if selected and selected != default_version:
            print(
                f"INFO: Selector '{selected}' has no matching {component} patch folder; "
                f"using '{default_version}'"
            )
        return default_version

    for candidate in ("master", "main"):
        if (component_root / candidate).is_dir():
            if selected and selected != candidate:
                print(
                    f"INFO: Selector '{selected}' has no matching {component} patch folder; "
                    f"using existing '{candidate}'"
                )
            else:
                print(
                    f"INFO: Using existing {component} patch folder '{candidate}' "
                    f"instead of default '{default_version}'"
                )
            return candidate

    fallback = selected or default_version
    print(f"INFO: No existing {component} version folder found; using '{fallback}'")
    return fallback


def generate_component_patches(
    component: str,
    version_selector: str,
    source_dir: Path,
    patches_dir: Path | None,
    patchset_loader: Callable[[], Type[PatchSet]],
    default_version: str,
    validate: bool,
) -> int:
    """Generate patches for a component with clean-state output handling."""
    patch_version = version_selector.strip()
    if component == "gcc" and patch_version.startswith("gcc-"):
        patch_version = patch_version[4:]

    patch_dir_label = resolve_existing_version_dir(component, patch_version, default_version)
    output_dir = patches_dir or Path(f"patches/{component}/{patch_dir_label}")

    clean_output_dir(output_dir)
    patchset_class = patchset_loader()
    patchset = patchset_class(component, patch_version, source_dir, output_dir)
    patches = patchset.generate()
    if validate and patches:
        ok = patchset.validate()
        return 0 if ok else 1
    return 0 if patches else 1


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate Win98 compatibility patches")
    parser.add_argument("--gcc-version", help="GCC version, e.g., 11.1.0")
    parser.add_argument(
        "--mingw-w64-version",
        metavar="VERSION_OR_COMMIT",
        help="Generate mingw-w64 patches for version/commit selector (e.g., master)",
    )
    parser.add_argument(
        "--pthread9x-version",
        metavar="VERSION_OR_COMMIT",
        help="Generate pthread9x patches for version/commit selector (e.g., master)",
    )
    parser.add_argument("--source-dir", type=Path, help="Path to source tree (auto-detected if omitted)")
    parser.add_argument("--patches-dir", type=Path, help="Override output directory")
    parser.add_argument("--validate", action="store_true", help="Validate patches after generation")
    args = parser.parse_args()

    selected_options = [
        bool(args.gcc_version),
        bool(args.mingw_w64_version),
        bool(args.pthread9x_version),
    ]
    if sum(selected_options) != 1:
        parser.error("Specify exactly one of --gcc-version, --mingw-w64-version, --pthread9x-version")

    if args.gcc_version:
        source_dir = args.source_dir or Path("src/gcc")
        exit_code = generate_component_patches(
            component="gcc",
            version_selector=args.gcc_version,
            source_dir=source_dir,
            patches_dir=args.patches_dir,
            patchset_loader=load_gcc_patchset_class,
            default_version="11.1.0",
            validate=args.validate,
        )
        sys.exit(exit_code)

    if args.mingw_w64_version:
        source_dir = args.source_dir or Path("src/mingw-w64")
        exit_code = generate_component_patches(
            component="mingw-w64",
            version_selector=args.mingw_w64_version,
            source_dir=source_dir,
            patches_dir=args.patches_dir,
            patchset_loader=load_mingw_patchset_class,
            default_version="master",
            validate=args.validate,
        )
        sys.exit(exit_code)

    if args.pthread9x_version:
        source_dir = args.source_dir or Path("src/pthread9x")
        exit_code = generate_component_patches(
            component="pthread9x",
            version_selector=args.pthread9x_version,
            source_dir=source_dir,
            patches_dir=args.patches_dir,
            patchset_loader=load_pthread9x_patchset_class,
            default_version="master",
            validate=args.validate,
        )
        sys.exit(exit_code)

    parser.print_help()
    sys.exit(1)


if __name__ == "__main__":
    main()
