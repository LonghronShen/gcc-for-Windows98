import subprocess
import unittest
from pathlib import Path


REPRO_ROOT = Path(__file__).resolve().parents[3]


class ProjectStatusScriptDirTests(unittest.TestCase):
    def test_common_sh_preserves_caller_script_dir(self):
        result = subprocess.run(
            [
                "bash",
                "-lc",
                'SCRIPT_DIR="caller-dir"; source scripts/lib/common.sh; printf "%s" "$SCRIPT_DIR"',
            ],
            cwd=REPRO_ROOT,
            capture_output=True,
            text=True,
        )

        self.assertEqual(result.returncode, 0, msg=result.stderr or result.stdout)
        self.assertEqual(result.stdout.strip().splitlines()[-1], "caller-dir")

    def test_project_status_uses_its_own_directory_after_sourcing_common(self):
        result = subprocess.run(
            ["bash", "scripts/utils/project-status.sh"],
            cwd=REPRO_ROOT,
            capture_output=True,
            text=True,
        )

        self.assertEqual(result.returncode, 0, msg=result.stderr or result.stdout)
        self.assertIn("== cross toolset report ==", result.stdout)
        self.assertIn("== native toolset report ==", result.stdout)
        self.assertIn("== smoke report ==", result.stdout)


if __name__ == "__main__":
    unittest.main()