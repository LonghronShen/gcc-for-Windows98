"""
When a consumer (e.g. libstdc++-v3) builds with -DDLL_EXPORT -DPIC
(as shared library PIC flags) but links against the static libpthread.a,
the __declspec(dllimport) generates __imp__pthread_mutex_* references
that cannot be resolved because no pthread9x DLL is present at link time.

Fix: in the DLL_EXPORT && !IN_WINPTHREAD case, leave WINPTHREAD_API
empty instead of using __declspec(dllimport). This avoids the __imp__
references while preserving dllexport for the actual pthread9x DLL build.
"""

import sys
from pathlib import Path

_THIS_DIR = Path(__file__).resolve().parent
_PARENT_DIR = _THIS_DIR.parent
if str(_PARENT_DIR) not in sys.path:
    sys.path.insert(0, str(_PARENT_DIR))

from base import PatchSet

_DLLIMPORT_LINE = "#define WINPTHREAD_API __declspec(dllimport)"
_COMMENT_LINE = (
    "/* Static linking: dllimport generates __imp__ refs with no DLL to resolve them."
    " Leave WINPTHREAD_API empty so consumers (e.g. libstdc++-v3 with -DDLL_EXPORT)"
    " do not emit dllimport-style indirect calls. */"
)
_EMPTY_DEFINE_LINE = "#define WINPTHREAD_API"


class Pthread9xPatchSet(PatchSet):
    """pthread9x patch set for Win98 static-linking compatibility."""

    supported_version_patterns = ("master", "main")

    def generate_patch_0001(self) -> str:
        """Fix WINPTHREAD_API dllimport for static linking in include/pthread.h."""
        target = "include/pthread.h"
        fpath = self.find_file(target)
        if not fpath:
            print(f"ERROR: {target} not found in {self.source_dir}")
            return ""

        lines = fpath.read_text().splitlines(keepends=True)
        old_lines: list[str] = []
        new_lines: list[str] = []
        found = False

        for line in lines:
            if line.rstrip("\n") == _DLLIMPORT_LINE:
                old_lines.append(line)
                new_lines.append(_COMMENT_LINE + "\n")
                new_lines.append(_EMPTY_DEFINE_LINE + "\n")
                found = True
            else:
                old_lines.append(line)
                new_lines.append(line)

        if not found:
            print(f"WARNING: dllimport pattern not found in {target}, may already be patched")

        return self.make_unified_diff(str(fpath.relative_to(self.source_dir)), old_lines, new_lines)

    def generate(self) -> list[Path]:
        """Generate all pthread9x patches and write series.txt."""
        self.require_supported_version()
        self.patches_dir.mkdir(parents=True, exist_ok=True)

        patch_generators = [
            ("0001-fix-static-linking-dllimport.patch", self.generate_patch_0001),
        ]

        series_entries: list[str] = []
        for filename, generator in patch_generators:
            content = generator()
            if content and not content.startswith("# No changes"):
                patch_path = self.patches_dir / filename
                patch_path.write_text(content)
                print(f"  -> {patch_path}")
                self.patches.append(patch_path)
                series_entries.append(filename)

        self.write_series(series_entries)
        return self.patches
