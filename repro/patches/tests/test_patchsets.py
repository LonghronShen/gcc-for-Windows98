import tempfile
import unittest
import importlib.util
import subprocess
import sys
from pathlib import Path

from patches.gcc.patch import GCCPatchSet


def load_mingw_patchset_class():
    module_path = Path(__file__).resolve().parents[1] / "mingw-w64" / "patch.py"
    spec = importlib.util.spec_from_file_location("tests_mingw_patch", module_path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Could not load module from {module_path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.MinGW_W64PatchSet


def load_pthread9x_patchset_class():
    module_path = Path(__file__).resolve().parents[1] / "pthread9x" / "patch.py"
    spec = importlib.util.spec_from_file_location("tests_pthread9x_patch", module_path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Could not load module from {module_path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.Pthread9xPatchSet


    module_path = Path(__file__).resolve().parents[1] / "mingw-w64" / "patch.py"
    spec = importlib.util.spec_from_file_location("tests_mingw_patch", module_path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Could not load module from {module_path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.MinGW_W64PatchSet


class PatchSetGenerationTests(unittest.TestCase):
    def test_gcc_version_gating_accepts_supported_version(self):
        with tempfile.TemporaryDirectory() as tmp:
            source_dir = Path(tmp) / "src"
            patches_dir = Path(tmp) / "out"
            source_dir.mkdir(parents=True)

            patchset = GCCPatchSet("gcc", "11.1.0", source_dir, patches_dir)
            self.assertTrue(patchset.is_supported_version())

    def test_gcc_version_gating_rejects_unsupported_version(self):
        with tempfile.TemporaryDirectory() as tmp:
            source_dir = Path(tmp) / "src"
            patches_dir = Path(tmp) / "out"
            source_dir.mkdir(parents=True)

            patchset = GCCPatchSet("gcc", "12.1.0", source_dir, patches_dir)
            with self.assertRaises(ValueError):
                patchset.require_supported_version()

    def test_gcc_patch_0003_disables_lfs_and_aligned_alloc(self):
        with tempfile.TemporaryDirectory() as tmp:
            source_dir = Path(tmp) / "src"
            patches_dir = Path(tmp) / "out"
            target = source_dir / "libstdc++-v3" / "config.h.in"
            target.parent.mkdir(parents=True)
            target.write_text(
                "\n".join(
                    [
                        "#define _GLIBCXX_USE_LFS 1",
                        "#define _GLIBCXX_HAVE_ALIGNED_ALLOC 1",
                        "#define _GLIBCXX_HAVE__ALIGNED_MALLOC 1",
                    ]
                )
                + "\n"
            )

            patchset = GCCPatchSet("gcc", "11.1.0", source_dir, patches_dir)
            diff = patchset.generate_patch_0003()

            self.assertIn("/* win98 repro disabled: #define _GLIBCXX_USE_LFS 1 */", diff)
            self.assertIn("/* win98 repro disabled: #define _GLIBCXX_HAVE_ALIGNED_ALLOC 1 */", diff)
            self.assertIn("/* win98 repro disabled: #define _GLIBCXX_HAVE__ALIGNED_MALLOC 1 */", diff)

    def test_gcc_patch_0004_disables_quick_exit_detection(self):
        with tempfile.TemporaryDirectory() as tmp:
            source_dir = Path(tmp) / "src"
            patches_dir = Path(tmp) / "out"
            target = source_dir / "libstdc++-v3" / "configure"
            target.parent.mkdir(parents=True)
            target.write_text(
                "\n".join(
                    [
                        "  glibcxx_cv_func_at_quick_exit_use=yes",
                        "  glibcxx_cv_func_quick_exit_use=yes",
                        "#define HAVE_AT_QUICK_EXIT 1",
                        "#define HAVE_QUICK_EXIT 1",
                    ]
                )
                + "\n"
            )

            patchset = GCCPatchSet("gcc", "11.1.0", source_dir, patches_dir)
            diff = patchset.generate_patch_0004()

            self.assertIn("glibcxx_cv_func_at_quick_exit_use=no", diff)
            self.assertIn("glibcxx_cv_func_quick_exit_use=no", diff)
            self.assertIn("/* win98 repro disabled: #define HAVE_AT_QUICK_EXIT 1 */", diff)
            self.assertIn("/* win98 repro disabled: #define HAVE_QUICK_EXIT 1 */", diff)

    def test_gcc_patch_0004_applies_ac_cv_and_multiple_files(self):
        with tempfile.TemporaryDirectory() as tmp:
            source_dir = Path(tmp) / "src"
            patches_dir = Path(tmp) / "out"

            config_h = source_dir / "libstdc++-v3" / "config.h.in"
            config_h.parent.mkdir(parents=True)
            config_h.write_text(
                "\n".join(
                    [
                        "#define HAVE_AT_QUICK_EXIT 1",
                        "#define HAVE_QUICK_EXIT 1",
                    ]
                )
                + "\n"
            )

            crossconfig = source_dir / "libstdc++-v3" / "crossconfig.m4"
            crossconfig.parent.mkdir(parents=True)
            crossconfig.write_text("ac_cv_func_at_quick_exit=yes\n")

            acinclude = source_dir / "libstdc++-v3" / "acinclude.m4"
            acinclude.parent.mkdir(parents=True)
            acinclude.write_text("ac_cv_func_quick_exit=yes\n")

            configure = source_dir / "libstdc++-v3" / "configure"
            configure.parent.mkdir(parents=True)
            configure.write_text(
                "\n".join(
                    [
                        "  glibcxx_cv_func_at_quick_exit_use=yes",
                        "  glibcxx_cv_func_quick_exit_use=yes",
                    ]
                )
                + "\n"
            )

            patchset = GCCPatchSet("gcc", "11.1.0", source_dir, patches_dir)
            diff = patchset.generate_patch_0004()

            self.assertIn("a/libstdc++-v3/config.h.in", diff)
            self.assertIn("a/libstdc++-v3/crossconfig.m4", diff)
            self.assertIn("a/libstdc++-v3/acinclude.m4", diff)
            self.assertIn("a/libstdc++-v3/configure", diff)
            self.assertIn("ac_cv_func_at_quick_exit=no", diff)
            self.assertIn("ac_cv_func_quick_exit=no", diff)

    def test_gcc_patch_0005_comments_first_int128_line(self):
        with tempfile.TemporaryDirectory() as tmp:
            source_dir = Path(tmp) / "src"
            patches_dir = Path(tmp) / "out"

            fs_path = source_dir / "libstdc++-v3" / "include" / "bits" / "fs_path.h"
            fs_path.parent.mkdir(parents=True)
            fs_path.write_text(
                "\n".join(
                    [
                        "using value_type = char;",
                        "__int128 maybe_problematic;",
                        "__int128 another_line;",
                    ]
                )
                + "\n"
            )

            patchset = GCCPatchSet("gcc", "11.1.0", source_dir, patches_dir)
            diff = patchset.generate_patch_0005()

            self.assertIn("// win98 repro disabled: __int128 maybe_problematic;", diff)
            self.assertNotIn("// win98 repro disabled: __int128 another_line;", diff)

    def test_gcc_patch_0006_adjusts_mkdir_signatures(self):
        with tempfile.TemporaryDirectory() as tmp:
            source_dir = Path(tmp) / "src"
            patches_dir = Path(tmp) / "out"

            fs_ops = source_dir / "libstdc++-v3" / "src" / "c++17" / "fs_ops.cc"
            fs_ops.parent.mkdir(parents=True)
            fs_ops.write_text("mkdir(to_char(path.c_str()), static_cast<int>(perms::all));\n")

            ops = source_dir / "libstdc++-v3" / "src" / "filesystem" / "ops.cc"
            ops.parent.mkdir(parents=True)
            ops.write_text("mkdir(p.c_str(), static_cast<int>(perms::all));\n")

            patchset = GCCPatchSet("gcc", "11.1.0", source_dir, patches_dir)
            diff = patchset.generate_patch_0006()

            self.assertIn("mkdir(to_char(path.c_str()));", diff)
            self.assertIn("mkdir(p.c_str());", diff)

    def test_mingw_patch_0001_switches_ucrt_default(self):
        mingw_patchset_class = load_mingw_patchset_class()

        with tempfile.TemporaryDirectory() as tmp:
            source_dir = Path(tmp) / "src"
            patches_dir = Path(tmp) / "out"
            target = source_dir / "mingw-w64-crt" / "configure.ac"
            target.parent.mkdir(parents=True)
            target.write_text(
                "\n".join(
                    [
                        "with_default_msvcrt=ucrt",
                        "with_default_msvcrt=msvcrt",
                    ]
                )
                + "\n"
            )

            patchset = mingw_patchset_class("mingw-w64", "master", source_dir, patches_dir)
            diff = patchset.generate_patch_0001()

            self.assertIn("with_default_msvcrt=msvcrt-os", diff)

    def test_mingw_version_gating_rejects_non_master(self):
        mingw_patchset_class = load_mingw_patchset_class()

        with tempfile.TemporaryDirectory() as tmp:
            source_dir = Path(tmp) / "src"
            patches_dir = Path(tmp) / "out"
            source_dir.mkdir(parents=True)

            patchset = mingw_patchset_class("mingw-w64", "v11.0.0", source_dir, patches_dir)
            with self.assertRaises(ValueError):
                patchset.require_supported_version()

    def test_mingw_patch_0002_disables_lfs64_redirects(self):
        mingw_patchset_class = load_mingw_patchset_class()

        with tempfile.TemporaryDirectory() as tmp:
            source_dir = Path(tmp) / "src"
            patches_dir = Path(tmp) / "out"

            io_h = source_dir / "mingw-w64-headers" / "crt" / "io.h"
            io_h.parent.mkdir(parents=True)
            io_h.write_text(
                "\n".join(
                    [
                        "#define lseek lseek64",
                        "#define fseeko fseeko64",
                        "#define ftello ftello64",
                        "#define ftruncate ftruncate64",
                        "#define truncate truncate64",
                        "int other_line;",
                    ]
                )
                + "\n"
            )

            patchset = mingw_patchset_class("mingw-w64", "master", source_dir, patches_dir)
            diff = patchset.generate_patch_0002()

            self.assertIn("/* win98 repro: disabled lseek -> lseek64 redirect */", diff)
            self.assertIn("/* win98 repro: disabled fseeko -> fseeko64 redirect */", diff)
            self.assertIn("/* win98 repro: disabled ftello -> ftello64 redirect */", diff)
            self.assertIn("/* win98 repro: disabled ftruncate -> ftruncate64 redirect */", diff)
            self.assertIn("/* win98 repro: disabled truncate -> truncate64 redirect */", diff)
            self.assertNotIn("int other_line", diff)

    def test_mingw_patch_0003_disables_mm_malloc_redirect(self):
        mingw_patchset_class = load_mingw_patchset_class()

        with tempfile.TemporaryDirectory() as tmp:
            source_dir = Path(tmp) / "src"
            patches_dir = Path(tmp) / "out"

            malloc_h = source_dir / "mingw-w64-headers" / "crt" / "malloc.h"
            malloc_h.parent.mkdir(parents=True)
            malloc_h.write_text(
                "\n".join(
                    [
                        "#define _MM_MALLOC_H_INCLUDED",
                        "#define _mm_malloc _aligned_malloc",
                        "int other_line;",
                    ]
                )
                + "\n"
            )

            patchset = mingw_patchset_class("mingw-w64", "master", source_dir, patches_dir)
            diff = patchset.generate_patch_0003()

            self.assertIn("/* win98 repro: disabled _mm_malloc -> _aligned_malloc redirect */", diff)
            self.assertNotIn("#define _MM_MALLOC_H_INCLUDED", diff)

    def test_mingw_generate_writes_patch_and_series(self):
        mingw_patchset_class = load_mingw_patchset_class()

        with tempfile.TemporaryDirectory() as tmp:
            source_dir = Path(tmp) / "src"
            patches_dir = Path(tmp) / "out"
            target = source_dir / "mingw-w64-crt" / "configure.ac"
            target.parent.mkdir(parents=True)
            target.write_text("with_default_msvcrt=ucrt\n")

            patchset = mingw_patchset_class("mingw-w64", "master", source_dir, patches_dir)
            generated = patchset.generate()

            self.assertEqual(len(generated), 1)
            self.assertTrue((patches_dir / "0001-ucrt-default-to-msvcrt.patch").exists())
            self.assertTrue((patches_dir / "series.txt").exists())
            series = (patches_dir / "series.txt").read_text().strip().splitlines()
            self.assertEqual(series, ["0001-ucrt-default-to-msvcrt.patch"])

    def test_gcc_generate_writes_series_in_order(self):
        with tempfile.TemporaryDirectory() as tmp:
            source_dir = Path(tmp) / "src"
            patches_dir = Path(tmp) / "out"

            mingw_os = source_dir / "libstdc++-v3" / "config" / "os" / "mingw32-w64" / "os_defines.h"
            mingw_os.parent.mkdir(parents=True)
            mingw_os.write_text("#define _GLIBCXX_THREAD_ATEXIT_WIN32 1\n")

            newlib_os = source_dir / "libstdc++-v3" / "config" / "os" / "newlib" / "os_defines.h"
            newlib_os.parent.mkdir(parents=True)
            newlib_os.write_text("#define _GLIBCXX_THREAD_ATEXIT_WIN32 1\n")

            atexit_thread = source_dir / "libstdc++-v3" / "libsupc++" / "atexit_thread.cc"
            atexit_thread.parent.mkdir(parents=True)
            atexit_thread.write_text(
                "\n".join(
                    [
                        "#ifdef _GLIBCXX_THREAD_ATEXIT_WIN32",
                        "#endif",
                        "    HMODULE dll;",
                        "\tif (e->dll)",
                        "\t  FreeLibrary (e->dll);",
                        "/* Decrement DLL count */",
                        "/* Store the DLL address */",
                        "  GetModuleHandleExW(foo);",
                    ]
                )
                + "\n"
            )

            config_h = source_dir / "libstdc++-v3" / "config.h.in"
            config_h.parent.mkdir(parents=True)
            config_h.write_text(
                "\n".join(
                    [
                        "#define _GLIBCXX_USE_LFS 1",
                        "#define _GLIBCXX_HAVE_ALIGNED_ALLOC 1",
                        "#define _GLIBCXX_HAVE__ALIGNED_MALLOC 1",
                    ]
                )
                + "\n"
            )

            configure = source_dir / "libstdc++-v3" / "configure"
            configure.parent.mkdir(parents=True)
            configure.write_text(
                "\n".join(
                    [
                        "  glibcxx_cv_func_at_quick_exit_use=yes",
                        "  glibcxx_cv_func_quick_exit_use=yes",
                        "#define HAVE_AT_QUICK_EXIT 1",
                        "#define HAVE_QUICK_EXIT 1",
                    ]
                )
                + "\n"
            )

            patchset = GCCPatchSet("gcc", "11.1.0", source_dir, patches_dir)
            generated = patchset.generate()

            self.assertEqual(len(generated), 4)
            series = (patches_dir / "series.txt").read_text().strip().splitlines()
            self.assertEqual(
                series,
                [
                    "0001-disable-thread-atexit-win32.patch",
                    "0002-remove-atexit-thread-dll-handling.patch",
                    "0003-disable-lfs-and-aligned-alloc.patch",
                    "0004-fix-msvcrt-quick-exit-detection.patch",
                ],
            )

    def test_gcc_generate_writes_full_series_with_optional_steps(self):
        with tempfile.TemporaryDirectory() as tmp:
            source_dir = Path(tmp) / "src"
            patches_dir = Path(tmp) / "out"

            mingw_os = source_dir / "libstdc++-v3" / "config" / "os" / "mingw32-w64" / "os_defines.h"
            mingw_os.parent.mkdir(parents=True)
            mingw_os.write_text("#define _GLIBCXX_THREAD_ATEXIT_WIN32 1\n")

            newlib_os = source_dir / "libstdc++-v3" / "config" / "os" / "newlib" / "os_defines.h"
            newlib_os.parent.mkdir(parents=True)
            newlib_os.write_text("#define _GLIBCXX_THREAD_ATEXIT_WIN32 1\n")

            atexit_thread = source_dir / "libstdc++-v3" / "libsupc++" / "atexit_thread.cc"
            atexit_thread.parent.mkdir(parents=True)
            atexit_thread.write_text(
                "\n".join(
                    [
                        "#ifdef _GLIBCXX_THREAD_ATEXIT_WIN32",
                        "#endif",
                        "    HMODULE dll;",
                        "\tif (e->dll)",
                        "\t  FreeLibrary (e->dll);",
                        "/* Decrement DLL count */",
                        "/* Store the DLL address */",
                        "  GetModuleHandleExW(foo);",
                    ]
                )
                + "\n"
            )

            config_h = source_dir / "libstdc++-v3" / "config.h.in"
            config_h.parent.mkdir(parents=True)
            config_h.write_text(
                "\n".join(
                    [
                        "#define _GLIBCXX_USE_LFS 1",
                        "#define _GLIBCXX_HAVE_ALIGNED_ALLOC 1",
                        "#define _GLIBCXX_HAVE__ALIGNED_MALLOC 1",
                        "#define HAVE_AT_QUICK_EXIT 1",
                        "#define HAVE_QUICK_EXIT 1",
                    ]
                )
                + "\n"
            )

            crossconfig = source_dir / "libstdc++-v3" / "crossconfig.m4"
            crossconfig.parent.mkdir(parents=True)
            crossconfig.write_text("ac_cv_func_at_quick_exit=yes\n")

            acinclude = source_dir / "libstdc++-v3" / "acinclude.m4"
            acinclude.parent.mkdir(parents=True)
            acinclude.write_text("ac_cv_func_quick_exit=yes\n")

            configure = source_dir / "libstdc++-v3" / "configure"
            configure.parent.mkdir(parents=True)
            configure.write_text(
                "\n".join(
                    [
                        "  glibcxx_cv_func_at_quick_exit_use=yes",
                        "  glibcxx_cv_func_quick_exit_use=yes",
                    ]
                )
                + "\n"
            )

            fs_path = source_dir / "libstdc++-v3" / "include" / "bits" / "fs_path.h"
            fs_path.parent.mkdir(parents=True)
            fs_path.write_text("__int128 maybe_problematic;\n")

            fs_ops = source_dir / "libstdc++-v3" / "src" / "c++17" / "fs_ops.cc"
            fs_ops.parent.mkdir(parents=True)
            fs_ops.write_text("mkdir(to_char(path.c_str()), static_cast<int>(perms::all));\n")

            ops = source_dir / "libstdc++-v3" / "src" / "filesystem" / "ops.cc"
            ops.parent.mkdir(parents=True)
            ops.write_text("mkdir(p.c_str(), static_cast<int>(perms::all));\n")

            patchset = GCCPatchSet("gcc", "11.1.0", source_dir, patches_dir)
            generated = patchset.generate()

            self.assertEqual(len(generated), 6)
            series = (patches_dir / "series.txt").read_text().strip().splitlines()
            self.assertEqual(
                series,
                [
                    "0001-disable-thread-atexit-win32.patch",
                    "0002-remove-atexit-thread-dll-handling.patch",
                    "0003-disable-lfs-and-aligned-alloc.patch",
                    "0004-fix-msvcrt-quick-exit-detection.patch",
                    "0005-disable-fs-path-int128.patch",
                    "0006-adjust-filesystem-mkdir-signature.patch",
                ],
            )

    def test_gcc_generate_with_no_inputs_writes_empty_series(self):
        with tempfile.TemporaryDirectory() as tmp:
            source_dir = Path(tmp) / "src"
            patches_dir = Path(tmp) / "out"
            source_dir.mkdir(parents=True)

            patchset = GCCPatchSet("gcc", "11.1.0", source_dir, patches_dir)
            generated = patchset.generate()

            self.assertEqual(generated, [])
            self.assertTrue((patches_dir / "series.txt").exists())
            series = (patches_dir / "series.txt").read_text().strip().splitlines()
            self.assertEqual(series, [])

    def test_pthread9x_patch_0001_replaces_dllimport(self):
        pthread9x_patchset_class = load_pthread9x_patchset_class()

        with tempfile.TemporaryDirectory() as tmp:
            source_dir = Path(tmp) / "src"
            patches_dir = Path(tmp) / "out"

            pthread_h = source_dir / "include" / "pthread.h"
            pthread_h.parent.mkdir(parents=True)
            pthread_h.write_text(
                "\n".join(
                    [
                        "#ifdef IN_WINPTHREAD",
                        "#define WINPTHREAD_API __declspec(dllexport)",
                        "#else",
                        "#define WINPTHREAD_API __declspec(dllimport)",
                        "#endif",
                    ]
                )
                + "\n"
            )

            patchset = pthread9x_patchset_class("pthread9x", "master", source_dir, patches_dir)
            diff = patchset.generate_patch_0001()

            self.assertIn("-#define WINPTHREAD_API __declspec(dllimport)", diff)
            self.assertIn("+/* Static linking:", diff)
            self.assertIn("+#define WINPTHREAD_API\n", diff)
            self.assertNotIn("#define WINPTHREAD_API __declspec(dllexport)", diff)

    def test_pthread9x_version_gating_rejects_non_master(self):
        pthread9x_patchset_class = load_pthread9x_patchset_class()

        with tempfile.TemporaryDirectory() as tmp:
            source_dir = Path(tmp) / "src"
            patches_dir = Path(tmp) / "out"
            source_dir.mkdir(parents=True)

            patchset = pthread9x_patchset_class("pthread9x", "0.9.0", source_dir, patches_dir)
            with self.assertRaises(ValueError) as ctx:
                patchset.generate()
            self.assertIn("Unsupported pthread9x version", str(ctx.exception))

    def test_pthread9x_generate_writes_patch_and_series(self):
        pthread9x_patchset_class = load_pthread9x_patchset_class()

        with tempfile.TemporaryDirectory() as tmp:
            source_dir = Path(tmp) / "src"
            patches_dir = Path(tmp) / "out"

            pthread_h = source_dir / "include" / "pthread.h"
            pthread_h.parent.mkdir(parents=True)
            pthread_h.write_text("#define WINPTHREAD_API __declspec(dllimport)\n")

            patchset = pthread9x_patchset_class("pthread9x", "master", source_dir, patches_dir)
            generated = patchset.generate()

            self.assertEqual(len(generated), 1)
            self.assertTrue((patches_dir / "0001-fix-static-linking-dllimport.patch").exists())
            self.assertTrue((patches_dir / "series.txt").exists())
            series = (patches_dir / "series.txt").read_text().strip().splitlines()
            self.assertEqual(series, ["0001-fix-static-linking-dllimport.patch"])

    def test_cli_rejects_unsupported_gcc_version(self):
        script = Path(__file__).resolve().parents[1] / "generate-patches.py"
        with tempfile.TemporaryDirectory() as tmp:
            source_dir = Path(tmp) / "src" / "gcc"
            source_dir.mkdir(parents=True)
            result = subprocess.run(
                [
                    sys.executable,
                    str(script),
                    "--gcc-version",
                    "12.1.0",
                    "--source-dir",
                    str(source_dir),
                ],
                capture_output=True,
                text=True,
            )

            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Unsupported gcc version", result.stderr)

    def test_cli_generates_mingw_patch(self):
        script = Path(__file__).resolve().parents[1] / "generate-patches.py"
        with tempfile.TemporaryDirectory() as tmp:
            source_dir = Path(tmp) / "src" / "mingw-w64" / "mingw-w64-crt"
            source_dir.mkdir(parents=True)
            (source_dir / "configure.ac").write_text("with_default_msvcrt=ucrt\n")
            out_dir = Path(tmp) / "out"

            result = subprocess.run(
                [
                    sys.executable,
                    str(script),
                    "--mingw-w64-version",
                    "master",
                    "--source-dir",
                    str(source_dir.parent),
                    "--patches-dir",
                    str(out_dir),
                ],
                capture_output=True,
                text=True,
            )

            self.assertEqual(result.returncode, 0)
            self.assertTrue((out_dir / "0001-ucrt-default-to-msvcrt.patch").exists())
            self.assertTrue((out_dir / "series.txt").exists())

    def test_cli_generates_pthread9x_patch(self):
        script = Path(__file__).resolve().parents[1] / "generate-patches.py"
        with tempfile.TemporaryDirectory() as tmp:
            source_dir = Path(tmp) / "src" / "pthread9x" / "include"
            source_dir.mkdir(parents=True)
            (source_dir / "pthread.h").write_text(
                "#define WINPTHREAD_API __declspec(dllimport)\n"
            )
            out_dir = Path(tmp) / "out"

            result = subprocess.run(
                [
                    sys.executable,
                    str(script),
                    "--pthread9x-version",
                    "master",
                    "--source-dir",
                    str(source_dir.parent),
                    "--patches-dir",
                    str(out_dir),
                ],
                capture_output=True,
                text=True,
            )

            self.assertEqual(result.returncode, 0)
            self.assertTrue((out_dir / "0001-fix-static-linking-dllimport.patch").exists())
            self.assertTrue((out_dir / "series.txt").exists())

    def test_cli_cleans_existing_output_directory_before_generation(self):
        script = Path(__file__).resolve().parents[1] / "generate-patches.py"
        with tempfile.TemporaryDirectory() as tmp:
            source_dir = Path(tmp) / "src" / "mingw-w64" / "mingw-w64-crt"
            source_dir.mkdir(parents=True)
            (source_dir / "configure.ac").write_text("with_default_msvcrt=ucrt\n")

            out_dir = Path(tmp) / "out"
            out_dir.mkdir(parents=True)
            stale_file = out_dir / "stale.txt"
            stale_file.write_text("old")

            result = subprocess.run(
                [
                    sys.executable,
                    str(script),
                    "--mingw-w64-version",
                    "master",
                    "--source-dir",
                    str(source_dir.parent),
                    "--patches-dir",
                    str(out_dir),
                ],
                capture_output=True,
                text=True,
            )

            self.assertEqual(result.returncode, 0)
            self.assertFalse(stale_file.exists())
            self.assertTrue((out_dir / "0001-ucrt-default-to-msvcrt.patch").exists())
            self.assertTrue((out_dir / "series.txt").exists())

    def test_cli_mingw_selector_commit_falls_back_to_existing_master_folder(self):
        script = Path(__file__).resolve().parents[1] / "generate-patches.py"
        with tempfile.TemporaryDirectory() as tmp:
            source_dir = Path(tmp) / "src" / "mingw-w64" / "mingw-w64-crt"
            source_dir.mkdir(parents=True)
            (source_dir / "configure.ac").write_text("with_default_msvcrt=ucrt\n")

            repo_root = Path(tmp) / "repo"
            (repo_root / "patches" / "mingw-w64" / "master").mkdir(parents=True)

            result = subprocess.run(
                [
                    sys.executable,
                    str(script),
                    "--mingw-w64-version",
                    "a1b2c3d4e5f6",
                    "--source-dir",
                    str(source_dir.parent),
                ],
                capture_output=True,
                text=True,
                cwd=repo_root,
            )

            self.assertEqual(result.returncode, 0)
            self.assertIn("using existing 'master'", result.stdout)
            self.assertTrue(
                (repo_root / "patches" / "mingw-w64" / "master" / "0001-ucrt-default-to-msvcrt.patch").exists()
            )

    def test_cli_without_args_prints_help_and_fails(self):
        script = Path(__file__).resolve().parents[1] / "generate-patches.py"
        result = subprocess.run(
            [sys.executable, str(script)],
            capture_output=True,
            text=True,
        )

        self.assertEqual(result.returncode, 1)
        self.assertIn("usage:", result.stdout.lower())

    def test_cli_help_flag_succeeds(self):
        script = Path(__file__).resolve().parents[1] / "generate-patches.py"
        result = subprocess.run(
            [sys.executable, str(script), "-h"],
            capture_output=True,
            text=True,
        )

        self.assertEqual(result.returncode, 0)
        self.assertIn("Generate Win98 compatibility patches", result.stdout)

    def test_cli_rejects_multiple_component_version_options(self):
        script = Path(__file__).resolve().parents[1] / "generate-patches.py"
        result = subprocess.run(
            [
                sys.executable,
                str(script),
                "--gcc-version",
                "11.1.0",
                "--mingw-w64-version",
                "master",
            ],
            capture_output=True,
            text=True,
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Specify exactly one", result.stderr)


if __name__ == "__main__":
    unittest.main()
