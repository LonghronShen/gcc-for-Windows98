import unittest
from pathlib import Path


REPRO_ROOT = Path(__file__).resolve().parents[3]
SCRIPTS_DIR = REPRO_ROOT / "scripts"


class NativeMingwDepsContractTests(unittest.TestCase):
    def test_native_phase_includes_dependency_build_before_host_gcc(self):
        run_toolchain_build = (SCRIPTS_DIR / "run-toolchain-build.sh").read_text(encoding="utf-8")
        build_deps_step = '  "build-native-mingw-deps|build-native-mingw-deps.sh|Build native mingw dependency libraries|builder"'
        host_gcc_step = '  "build-native-host-gcc|build-native-host-gcc.sh|Build native-host GCC|builder"'

        self.assertIn(build_deps_step, run_toolchain_build)
        self.assertIn(host_gcc_step, run_toolchain_build)
        self.assertLess(run_toolchain_build.index(build_deps_step), run_toolchain_build.index(host_gcc_step))

    def test_native_status_reports_dependency_build_step(self):
        native_status = (SCRIPTS_DIR / "utils" / "native-toolset-status.sh").read_text(encoding="utf-8")
        self.assertIn('status_step_line "build-native-mingw-deps"', native_status)

    def test_native_host_gcc_requires_explicit_mingw_deps_prefix(self):
        build_native_host_gcc = (SCRIPTS_DIR / "build-native-host-gcc.sh").read_text(encoding="utf-8")

        self.assertIn('MINGW_DEPS_DIR="$REPO_ROOT/out/mingw-deps"', build_native_host_gcc)
        self.assertIn('--without-isl', build_native_host_gcc, "build-native-host-gcc.sh must disable ISL to match --no-isl in build-native-mingw-deps.sh")
        self.assertIn('require_dir "$MINGW_DEPS_DIR/include"', build_native_host_gcc)
        self.assertIn('require_dir "$MINGW_DEPS_DIR/lib"', build_native_host_gcc)
        self.assertIn('--with-gmp="$MINGW_DEPS_DIR"', build_native_host_gcc)
        self.assertIn('--with-mpfr="$MINGW_DEPS_DIR"', build_native_host_gcc)
        self.assertIn('--with-mpc="$MINGW_DEPS_DIR"', build_native_host_gcc)

    def test_package_verifier_asserts_no_gmp_mpfr_mpc_runtime_dependency(self):
        verifier = (SCRIPTS_DIR / "verifiers" / "verify-native-package.sh").read_text(encoding="utf-8")
        self.assertIn('gmp', verifier)
        self.assertIn('mpfr', verifier)
        self.assertIn('mpc', verifier)


if __name__ == "__main__":
    unittest.main()
