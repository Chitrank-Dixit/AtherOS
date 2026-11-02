"""Unit checks for Sprint 0 repository tooling and fixtures."""

import json
import subprocess
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


class RepositoryToolTests(unittest.TestCase):
    def test_report_helper_prints_current_report(self) -> None:
        result = subprocess.run(
            [sys.executable, str(ROOT / "scripts/generate-report.py")],
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Sprint 0 report", result.stdout)

    def test_blocked_experiment_fixture_matches_required_shape(self) -> None:
        schema = json.loads((ROOT / "schemas/experiment-record.schema.json").read_text())
        record = json.loads((ROOT / "tests/fixtures/experiment-record.json").read_text())
        self.assertTrue(set(schema["required"]).issubset(record))
        self.assertIn(record["status"], schema["properties"]["status"]["enum"])
        self.assertEqual(set(record), set(schema["properties"]))


if __name__ == "__main__":
    unittest.main()
