import json
import tempfile
import unittest
from pathlib import Path

import sys

THIS_DIR = Path(__file__).resolve().parent
LIB_DIR = THIS_DIR.parent
sys.path.insert(0, str(LIB_DIR))

from validate_matrix_selector import main


class ValidateMatrixSelectorCliTests(unittest.TestCase):
    def test_main_success(self):
        with tempfile.TemporaryDirectory() as td:
            config = Path(td) / "config.json"
            config.write_text(json.dumps({"matrix": [{"version": "stable"}]}), encoding="utf-8")
            rc = main([str(config), "stable"])
            self.assertEqual(rc, 0)

    def test_main_failure(self):
        with tempfile.TemporaryDirectory() as td:
            config = Path(td) / "config.json"
            config.write_text(json.dumps({"matrix": [{"version": "stable"}]}), encoding="utf-8")
            rc = main([str(config), "missing"])
            self.assertEqual(rc, 1)


if __name__ == "__main__":
    unittest.main()
