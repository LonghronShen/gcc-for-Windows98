import json
import tempfile
import unittest
from pathlib import Path

import sys

THIS_DIR = Path(__file__).resolve().parent
LIB_DIR = THIS_DIR.parent
sys.path.insert(0, str(LIB_DIR))

from matrix_config import (
    available_labels,
    get_matrix_entries,
    load_config,
    select_matrix_entry,
    validate_matrix_selector,
)


class MatrixConfigTests(unittest.TestCase):
    def test_load_config_success(self):
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / "config.json"
            path.write_text('{"matrix": [{"version": "v1"}]}', encoding="utf-8")
            cfg = load_config(path)
            self.assertIn("matrix", cfg)

    def test_load_config_invalid_json(self):
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / "config.json"
            path.write_text('{"matrix": [', encoding="utf-8")
            with self.assertRaises(ValueError):
                load_config(path)

    def test_get_matrix_entries_non_empty(self):
        cfg = {"matrix": [{"version": "v1"}, "bad", {"version": "v2"}]}
        entries = get_matrix_entries(cfg)
        self.assertEqual(len(entries), 2)

    def test_get_matrix_entries_empty_raises(self):
        with self.assertRaises(ValueError):
            get_matrix_entries({"matrix": []})

    def test_available_labels(self):
        labels = available_labels([{"version": "v1"}, {"version": ""}, {"version": "v2"}])
        self.assertEqual(labels, ["v1", "v2"])

    def test_select_matrix_entry_by_index(self):
        cfg = {"matrix": [{"version": "v1"}, {"version": "v2"}]}
        selected = select_matrix_entry(cfg, "1")
        self.assertEqual(selected.get("version"), "v2")

    def test_select_matrix_entry_by_label(self):
        cfg = {"matrix": [{"version": "stable"}]}
        selected = select_matrix_entry(cfg, "stable")
        self.assertEqual(selected.get("version"), "stable")

    def test_select_matrix_entry_invalid_label(self):
        cfg = {"matrix": [{"version": "stable"}]}
        with self.assertRaises(ValueError) as exc:
            select_matrix_entry(cfg, "dev")
        self.assertIn("Available labels", str(exc.exception))

    def test_validate_matrix_selector_end_to_end(self):
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / "config.json"
            path.write_text(json.dumps({"matrix": [{"version": "stable"}]}), encoding="utf-8")
            selected = validate_matrix_selector(path, "stable")
            self.assertEqual(selected.get("version"), "stable")


if __name__ == "__main__":
    unittest.main()
