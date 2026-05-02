import json
import tempfile
import unittest
from pathlib import Path
from typing import Any

import sys

THIS_DIR = Path(__file__).resolve().parent
LIB_DIR = THIS_DIR.parent
sys.path.insert(0, str(LIB_DIR))

from config_matrix_exports import build_exports, format_exports_lines, main


class ConfigMatrixExportsTests(unittest.TestCase):
    def test_build_exports_by_index(self):
        cfg: dict[str, Any] = {
            "matrix": [
                {
                    "version": "v1",
                    "components": [
                        {"gcc": {"source": "s1", "commit": "c1", "version": "11.1.0"}},
                        {"binutils": {"source": "s2", "commit": "c2", "version": "2.36.1"}},
                        {"gmp": {"version": "v6.2.1"}},
                        {"mpfr": {"version": "4.1.0"}},
                        {"mpc": {"version": "1.2.1"}},
                    ],
                }
            ]
        }

        exports = build_exports(cfg, "0")
        self.assertEqual(exports["MATRIX_SELECTED_LABEL"], "v1")
        self.assertEqual(exports["GCC_FETCH_SOURCE"], "s1")
        self.assertEqual(exports["GCC_FETCH_REF"], "c1")
        self.assertEqual(exports["GCC_COMPONENT_VERSION"], "11.1.0")
        self.assertEqual(exports["BINUTILS_FETCH_SOURCE"], "s2")
        self.assertEqual(exports["GMP_VERSION"], "v6.2.1")
        self.assertEqual(exports["MPFR_VERSION"], "4.1.0")
        self.assertEqual(exports["MPC_VERSION"], "1.2.1")

    def test_build_exports_by_label(self):
        cfg: dict[str, Any] = {
            "matrix": [
                {"version": "stable", "components": [{"pthread9x": {"commit": "abc"}}]},
            ]
        }
        exports = build_exports(cfg, "stable")
        self.assertEqual(exports["PTHREAD9X_FETCH_REF"], "abc")

    def test_format_exports_lines(self):
        lines = list(format_exports_lines({"B": "2", "A": "hello world"}))
        self.assertEqual(lines[0], "A='hello world'")
        self.assertEqual(lines[1], "B=2")

    def test_main_success(self):
        cfg: dict[str, Any] = {"matrix": [{"version": "v2", "components": []}]}
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / "config.json"
            path.write_text(json.dumps(cfg), encoding="utf-8")
            rc = main([str(path), "0"])
            self.assertEqual(rc, 0)

    def test_main_invalid_selector(self):
        cfg: dict[str, Any] = {"matrix": [{"version": "v2", "components": []}]}
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / "config.json"
            path.write_text(json.dumps(cfg), encoding="utf-8")
            rc = main([str(path), "missing"])
            self.assertEqual(rc, 1)


if __name__ == "__main__":
    unittest.main()
