"""Unit checks for Sprint 0 repository tooling and fixtures."""

import json
import subprocess
import sys
import unittest
from pathlib import Path

from jsonschema import Draft202012Validator


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

    def test_experiment_fixtures_cover_each_status_and_required_field(self) -> None:
        schema = json.loads(
            (ROOT / "schemas/experiment-record.schema.json").read_text(encoding="utf-8")
        )
        validator = Draft202012Validator(schema)
        fixtures = sorted((ROOT / "tests/fixtures").rglob("*.json"))
        records = [json.loads(path.read_text(encoding="utf-8")) for path in fixtures]
        statuses = {record["status"] for record in records}

        self.assertEqual(
            statuses,
            set(schema["properties"]["status"]["enum"]),
        )
        for record in records:
            self.assertTrue(set(schema["required"]).issubset(record))
            self.assertTrue(set(record).issubset(schema["properties"]))
            self.assertEqual([], list(validator.iter_errors(record)))

    def test_optional_properties_are_validated_when_present(self) -> None:
        schema = json.loads(
            (ROOT / "schemas/experiment-record.schema.json").read_text(encoding="utf-8")
        )
        validator = Draft202012Validator(schema)
        record = json.loads(
            (ROOT / "tests/fixtures/experiment-record.json").read_text(encoding="utf-8")
        )
        self.assertEqual([], list(validator.iter_errors(record)))
        record["iso_sha256"] = "not-a-checksum"
        self.assertTrue(list(validator.iter_errors(record)))

    def test_missing_required_property_is_rejected(self) -> None:
        schema = json.loads(
            (ROOT / "schemas/experiment-record.schema.json").read_text(encoding="utf-8")
        )
        record = json.loads(
            (ROOT / "tests/fixtures/experiment-record.json").read_text(encoding="utf-8")
        )
        del record["expected"]
        errors = list(Draft202012Validator(schema).iter_errors(record))
        self.assertTrue(any("expected" in error.message for error in errors))

    def test_unexpected_property_is_rejected(self) -> None:
        schema = json.loads(
            (ROOT / "schemas/experiment-record.schema.json").read_text(encoding="utf-8")
        )
        record = json.loads(
            (ROOT / "tests/fixtures/experiment-record.json").read_text(encoding="utf-8")
        )
        record["unexpected"] = True
        errors = list(Draft202012Validator(schema).iter_errors(record))
        self.assertTrue(any("Additional properties" in error.message for error in errors))


if __name__ == "__main__":
    unittest.main()
