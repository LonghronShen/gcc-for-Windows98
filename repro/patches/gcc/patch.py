import re
import sys
from pathlib import Path

_THIS_DIR = Path(__file__).resolve().parent
_PARENT_DIR = _THIS_DIR.parent
if str(_PARENT_DIR) not in sys.path:
    sys.path.insert(0, str(_PARENT_DIR))

from base import PatchSet


class GCCPatchSet(PatchSet):
    """GCC patch set for Win98 compatibility."""

    supported_version_patterns = ("11.*",)

    def generate_patch_0001(self) -> str:
        """Disable _GLIBCXX_THREAD_ATEXIT_WIN32 in os_defines.h files."""
        targets = [
            "libstdc++-v3/config/os/mingw32-w64/os_defines.h",
            "libstdc++-v3/config/os/newlib/os_defines.h",
        ]
        patch_lines: list[str] = []
        for target in targets:
            fpath = self.find_file(target)
            if not fpath:
                print(f"WARNING: {target} not found, skipping")
                continue
            content = fpath.read_text()
            if "_GLIBCXX_THREAD_ATEXIT_WIN32" not in content:
                print(f"WARNING: Pattern not found in {target}")
                continue
            lines = content.splitlines(keepends=True)
            old_lines: list[str] = []
            new_lines: list[str] = []
            found = False
            for line in lines:
                if re.search(r"^/\*\s*win98 repro:\s*disable _GLIBCXX_THREAD_ATEXIT_WIN32\s*\*/", line):
                    old_lines.append("#define _GLIBCXX_THREAD_ATEXIT_WIN32 1\n")
                    new_lines.append(line)
                    found = True
                elif re.search(r"^#define\s+_GLIBCXX_THREAD_ATEXIT_WIN32\s+1", line):
                    old_lines.append(line)
                    new_lines.append("/* win98 repro: disable _GLIBCXX_THREAD_ATEXIT_WIN32 */\n")
                    found = True
                else:
                    old_lines.append(line)
                    new_lines.append(line)
            if not found:
                print(f"WARNING: Could not locate #define in {target}")
                continue
            patch_lines.append(self.make_unified_diff(str(fpath.relative_to(self.source_dir)), old_lines, new_lines))
        return "\n".join(patch_lines)

    def generate_patch_0002(self) -> str:
        """Remove Windows DLL handle tracking from atexit_thread.cc."""
        target = "libstdc++-v3/libsupc++/atexit_thread.cc"
        fpath = self.find_file(target)
        if not fpath:
            print(f"ERROR: {target} not found")
            return ""
        lines = fpath.read_text().splitlines(keepends=True)
        old_lines: list[str] = []
        new_lines: list[str] = []
        i = 0
        while i < len(lines):
            line = lines[i]
            if re.search(r"^#ifdef _GLIBCXX_THREAD_ATEXIT_WIN32\s*$", line):
                if i + 1 < len(lines) and re.search(r"^#endif", lines[i + 1]):
                    old_lines.append(line)
                    old_lines.append("#define WIN32_LEAN_AND_MEAN\n")
                    old_lines.append("#include <windows.h>\n")
                    old_lines.append(lines[i + 1])

                    new_lines.append(line)
                    new_lines.append(lines[i + 1])
                    i += 2
                    continue
                old_lines.append(line)
                new_lines.append(line)
            elif re.search(r"^\s+HMODULE dll;", line):
                old_lines.append("    HMODULE dll;\n")
                i += 1
                continue
            elif re.search(r"^\s+if \(e->dll\)", line):
                old_lines.append("\tif (e->dll)\n")
                old_lines.append("\t  FreeLibrary (e->dll);\n")
                i += 1
                continue
            elif re.search(r"^\s+FreeLibrary \(e->dll\);", line):
                i += 1
                continue
            elif re.search(r"/\*\s+Decrement DLL count\s+\*/", line):
                old_lines.append(line)
                i += 1
                continue
            else:
                old_lines.append(line)
                new_lines.append(line)
            i += 1
        return self.make_unified_diff(str(fpath.relative_to(self.source_dir)), old_lines, new_lines)

    def generate_patch_0004(self) -> str:
        """Disable at_quick_exit and quick_exit detection in key libstdc++ files."""
        targets = [
            "libstdc++-v3/config.h.in",
            "libstdc++-v3/crossconfig.m4",
            "libstdc++-v3/acinclude.m4",
            "libstdc++-v3/configure",
        ]
        patch_lines: list[str] = []

        for target in targets:
            fpath = self.find_file(target)
            if not fpath:
                continue

            lines = fpath.read_text().splitlines(keepends=True)
            old_lines: list[str] = []
            new_lines: list[str] = []

            for line in lines:
                if re.search(r"^\s+glibcxx_cv_func_at_quick_exit_use=no", line):
                    old_lines.append(re.sub(r"=no$", "=yes", line))
                    new_lines.append(line)
                elif re.search(r"^\s+glibcxx_cv_func_at_quick_exit_use=yes", line):
                    old_lines.append(line)
                    new_lines.append(re.sub(r"=yes$", "=no", line))
                elif re.search(r"^\s+glibcxx_cv_func_quick_exit_use=no", line):
                    old_lines.append(re.sub(r"=no$", "=yes", line))
                    new_lines.append(line)
                elif re.search(r"^\s+glibcxx_cv_func_quick_exit_use=yes", line):
                    old_lines.append(line)
                    new_lines.append(re.sub(r"=yes$", "=no", line))
                elif re.search(r"^\s*ac_cv_func_at_quick_exit=no", line):
                    old_lines.append(re.sub(r"=no$", "=yes", line))
                    new_lines.append(line)
                elif re.search(r"^\s*ac_cv_func_at_quick_exit=yes", line):
                    old_lines.append(line)
                    new_lines.append(re.sub(r"=yes$", "=no", line))
                elif re.search(r"^\s*ac_cv_func_quick_exit=no", line):
                    old_lines.append(re.sub(r"=no$", "=yes", line))
                    new_lines.append(line)
                elif re.search(r"^\s*ac_cv_func_quick_exit=yes", line):
                    old_lines.append(line)
                    new_lines.append(re.sub(r"=yes$", "=no", line))
                elif re.search(r"^/\*\s*win98 repro disabled:\s*#define HAVE_AT_QUICK_EXIT 1\s*\*/", line):
                    old_lines.append("#define HAVE_AT_QUICK_EXIT 1\n")
                    new_lines.append(line)
                elif re.search(r"^#define HAVE_AT_QUICK_EXIT 1", line):
                    old_lines.append(line)
                    new_lines.append("/* win98 repro disabled: #define HAVE_AT_QUICK_EXIT 1 */\n")
                elif re.search(r"^/\*\s*win98 repro disabled:\s*#define HAVE_QUICK_EXIT 1\s*\*/", line):
                    old_lines.append("#define HAVE_QUICK_EXIT 1\n")
                    new_lines.append(line)
                elif re.search(r"^#define HAVE_QUICK_EXIT 1", line):
                    old_lines.append(line)
                    new_lines.append("/* win98 repro disabled: #define HAVE_QUICK_EXIT 1 */\n")
                else:
                    old_lines.append(line)
                    new_lines.append(line)

            diff = self.make_unified_diff(str(fpath.relative_to(self.source_dir)), old_lines, new_lines)
            if not diff.startswith("# No changes"):
                patch_lines.append(diff)

        return "\n".join(patch_lines)

    def generate_patch_0005(self) -> str:
        """Wrap windows.h includes with abort macro push/pop guards to avoid COM method clashes."""
        # (target, needs_comment): diagnostic-color.c gets an explanatory comment block
        targets = [
            ("gcc/diagnostic-color.c", True),
            ("gcc/plugin.c", False),
            ("gcc/prefix.c", False),
            ("gcc/pretty-print.c", False),
        ]
        comment_lines = [
            "/* msxml.h (pulled in via windows.h -> urlmon.h) declares COM methods named\n",
            "   'abort', which clash with GCC's '#define abort() fancy_abort(...)' from\n",
            "   system.h.  Temporarily suppress the macro while processing Windows SDK\n",
            "   headers, then restore it afterwards.  */\n",
        ]
        patch_lines: list[str] = []

        for target, needs_comment in targets:
            fpath = self.find_file(target)
            if not fpath:
                print(f"WARNING: {target} not found, skipping")
                continue

            content = fpath.read_text()
            already_patched = '#pragma push_macro("abort")' in content
            lines = content.splitlines(keepends=True)
            old_lines: list[str] = []
            new_lines: list[str] = []
            i = 0

            if already_patched:
                while i < len(lines):
                    line = lines[i]
                    if needs_comment and re.search(r"^/\* msxml\.h", line):
                        # Our 4-line comment block: new only
                        for j in range(4):
                            if i + j < len(lines):
                                new_lines.append(lines[i + j])
                        i += 4
                        continue
                    if re.search(r'^#pragma push_macro\("abort"\)', line):
                        new_lines.append(line)
                        i += 1
                        continue
                    if re.search(r"^#undef abort\s*$", line):
                        new_lines.append(line)
                        i += 1
                        continue
                    if re.search(r'^#pragma pop_macro\("abort"\)', line):
                        new_lines.append(line)
                        i += 1
                        continue
                    old_lines.append(line)
                    new_lines.append(line)
                    i += 1
            else:
                while i < len(lines):
                    line = lines[i]
                    if re.search(r"^#\s*include\s+<windows\.h>", line):
                        if needs_comment:
                            for cl in comment_lines:
                                new_lines.append(cl)
                        new_lines.append('#pragma push_macro("abort")\n')
                        new_lines.append("#undef abort\n")
                        old_lines.append(line)
                        new_lines.append(line)
                        new_lines.append('#pragma pop_macro("abort")\n')
                    else:
                        old_lines.append(line)
                        new_lines.append(line)
                    i += 1

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
            ("0001-disable-thread-atexit-win32.patch", self.generate_patch_0001),
            ("0002-remove-atexit-thread-dll-handling.patch", self.generate_patch_0002),
            ("0004-fix-msvcrt-quick-exit-detection.patch", self.generate_patch_0004),
            ("0005-fix-windows-h-abort-macro-conflict.patch", self.generate_patch_0005),
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
            # Insert the 0003 note into series before 0004
            if name == "0004-fix-msvcrt-quick-exit-detection.patch":
                series_entries.append("# 0003 — handled via configure cache variables (glibcxx_cv_LFS=no, etc.)")
            series_entries.append(name)
            self.patches.append(out_path)
            print(f"  -> {out_path}")

        self.write_series(series_entries)
        print(f"\nDone. GCC patches written to: {self.patches_dir}")
        return self.patches
