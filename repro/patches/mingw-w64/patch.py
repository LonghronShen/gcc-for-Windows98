import re
import sys
from pathlib import Path

_THIS_DIR = Path(__file__).resolve().parent
_PARENT_DIR = _THIS_DIR.parent
if str(_PARENT_DIR) not in sys.path:
    sys.path.insert(0, str(_PARENT_DIR))

from base import PatchSet


class MinGW_W64PatchSet(PatchSet):
    """mingw-w64 patch set for Win98 compatibility."""

    supported_version_patterns = ("master",)

    def generate_patch_0001(self) -> str:
        """Set default msvcrt from ucrt to msvcrt-os in configure.ac."""
        target = "mingw-w64-crt/configure.ac"
        fpath = self.find_file(target)
        if not fpath:
            fpath = self.find_file("configure.ac")
            if not fpath or "mingw-w64-crt" not in str(fpath):
                print(f"ERROR: {target} not found in {self.source_dir}")
                return ""

        content = fpath.read_text()
        lines = content.splitlines(keepends=True)
        old_lines: list[str] = []
        new_lines: list[str] = []

        modified = False
        for line in lines:
            if re.search(r"with_default_msvcrt=ucrt", line):
                old_lines.append(line)
                new_lines.append(re.sub(r"with_default_msvcrt=ucrt", "with_default_msvcrt=msvcrt-os", line))
                modified = True
            elif re.search(r"with_default_msvcrt=msvcrt-os", line):
                old_lines.append(re.sub(r"with_default_msvcrt=msvcrt-os", "with_default_msvcrt=ucrt", line))
                new_lines.append(line)
                modified = True
            elif re.search(r"with_default_msvcrt=msvcrt\b", line):
                old_lines.append(re.sub(r"with_default_msvcrt=msvcrt\b", "with_default_msvcrt=ucrt", line))
                new_lines.append(re.sub(r"with_default_msvcrt=msvcrt\b", "with_default_msvcrt=msvcrt-os", line))
                modified = True
            else:
                old_lines.append(line)
                new_lines.append(line)

        if not modified:
            print(f"WARNING: No 'default_msvcrt' found in {fpath}, patch may not be needed")
            return ""

        return self.make_unified_diff(str(fpath.relative_to(self.source_dir)), old_lines, new_lines)

    def generate_patch_0002(self) -> str:
        """Disable LFS64 auto-redirect macros in mingw-w64 CRT headers."""
        targets = [
            "mingw-w64-headers/crt/io.h",
            "mingw-w64-headers/crt/stdio.h",
            "mingw-w64-headers/crt/unistd.h",
            "mingw-w64-headers/crt/wchar.h",
        ]
        replacements = {
            "#define lseek lseek64": "/* win98 repro: disabled lseek -> lseek64 redirect */",
            "#define fseeko fseeko64": "/* win98 repro: disabled fseeko -> fseeko64 redirect */",
            "#define ftello ftello64": "/* win98 repro: disabled ftello -> ftello64 redirect */",
            "#define ftruncate ftruncate64": "/* win98 repro: disabled ftruncate -> ftruncate64 redirect */",
            "#define truncate truncate64": "/* win98 repro: disabled truncate -> truncate64 redirect */",
        }
        patch_lines: list[str] = []

        for target in targets:
            fpath = self.find_file(target)
            if not fpath:
                continue

            lines = fpath.read_text().splitlines(keepends=True)
            old_lines: list[str] = []
            new_lines: list[str] = []

            for line in lines:
                stripped = line.rstrip("\n")
                if stripped in replacements:
                    old_lines.append(line)
                    new_lines.append(replacements[stripped] + "\n")
                elif stripped in replacements.values():
                    # Already patched: reconstruct original
                    reverse = {v: k for k, v in replacements.items()}
                    old_lines.append(reverse[stripped] + "\n")
                    new_lines.append(line)
                else:
                    old_lines.append(line)
                    new_lines.append(line)

            diff = self.make_unified_diff(str(fpath.relative_to(self.source_dir)), old_lines, new_lines)
            if not diff.startswith("# No changes"):
                patch_lines.append(diff)

        return "\n".join(patch_lines)

    def generate_patch_0003(self) -> str:
        """Disable _mm_malloc -> _aligned_malloc redirect in CRT headers."""
        targets = [
            "mingw-w64-headers/crt/intrin.h",
            "mingw-w64-headers/crt/malloc.h",
            "mingw-w64-headers/crt/stdlib.h",
        ]
        patch_lines: list[str] = []

        for target in targets:
            fpath = self.find_file(target)
            if not fpath:
                continue

            lines = fpath.read_text().splitlines(keepends=True)
            old_lines: list[str] = []
            new_lines: list[str] = []
            DISABLED = "/* win98 repro: disabled _mm_malloc -> _aligned_malloc redirect */"

            for line in lines:
                stripped = line.rstrip("\n")
                if stripped == "#define _MM_MALLOC_H_INCLUDED":
                    # Shell removes this line entirely
                    old_lines.append(line)
                    # new_lines gets nothing (line deleted)
                elif stripped == "#define _mm_malloc _aligned_malloc":
                    old_lines.append(line)
                    new_lines.append(DISABLED + "\n")
                elif stripped == DISABLED:
                    # Already patched: reconstruct original
                    old_lines.append("#define _mm_malloc _aligned_malloc\n")
                    new_lines.append(line)
                else:
                    old_lines.append(line)
                    new_lines.append(line)

            diff = self.make_unified_diff(str(fpath.relative_to(self.source_dir)), old_lines, new_lines)
            if not diff.startswith("# No changes"):
                patch_lines.append(diff)

        return "\n".join(patch_lines)

    def generate(self) -> list[Path]:
        self.require_supported_version()

        if not self.detect_applicability():
            print(f"ERROR: Source directory not found: {self.source_dir}")
            return []
        self.patches_dir.mkdir(parents=True, exist_ok=True)

        patch_generators = [
            ("0001-ucrt-default-to-msvcrt.patch", self.generate_patch_0001),
            ("0002-disable-lfs64-redirects.patch", self.generate_patch_0002),
            ("0003-disable-mm-malloc-redirect.patch", self.generate_patch_0003),
        ]
        series_entries: list[str] = []
        for name, gen_func in patch_generators:
            print(f"Generating {name}...")
            content = gen_func()
            if not content or content.startswith("# No changes"):
                print(f"WARNING: {name} produced no changes")
                continue
            out_path = self.patches_dir / name
            out_path.write_text(content)
            series_entries.append(name)
            self.patches.append(out_path)
            print(f"  -> {out_path}")

        self.write_series(series_entries)
        print(f"\nDone. mingw-w64 patches written to: {self.patches_dir}")
        return self.patches
