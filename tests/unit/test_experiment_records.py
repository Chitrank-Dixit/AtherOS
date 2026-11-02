import contextlib
import importlib.util
import io
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[2]
VALIDATOR_PATH = ROOT / "scripts/experiments/validate-records.py"
SPEC = importlib.util.spec_from_file_location("record_validator", VALIDATOR_PATH)
assert SPEC is not None and SPEC.loader is not None
validator = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(validator)
REPORT_PATH = ROOT / "scripts/experiments/generate-results-report.py"
REPORT_SPEC = importlib.util.spec_from_file_location("experiment_report", REPORT_PATH)
assert REPORT_SPEC is not None and REPORT_SPEC.loader is not None
report_generator = importlib.util.module_from_spec(REPORT_SPEC)
REPORT_SPEC.loader.exec_module(report_generator)
SCHEMA = json.loads((ROOT / "schemas/experiment-record.schema.json").read_text(encoding="utf-8"))


class ExperimentRecordTests(unittest.TestCase):
    def test_all_examples_validate(self) -> None:
        paths = sorted((ROOT / "tests/fixtures").rglob("*.json"))
        self.assertGreaterEqual(len(paths), 5)
        for path in paths:
            with self.subTest(path=path.name):
                self.assertEqual([], validator.validate(path, SCHEMA))

    def test_passed_record_requires_evidence(self) -> None:
        source = ROOT / "tests/fixtures/experiment-records/passed.example.json"
        record = json.loads(source.read_text(encoding="utf-8"))
        record["evidence"] = []
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "invalid.json"
            path.write_text(json.dumps(record), encoding="utf-8")
            self.assertTrue(any("requires evidence" in error for error in validator.validate(path, SCHEMA)))

    def test_report_is_deterministic_and_omits_synthetic_fixtures(self) -> None:
        outputs = []
        for _ in range(2):
            output = io.StringIO()
            with patch("sys.argv", [str(REPORT_PATH), str(ROOT / "tests/fixtures")]), contextlib.redirect_stdout(output):
                self.assertEqual(0, report_generator.main())
            outputs.append(output.getvalue())
        self.assertEqual(outputs[0], outputs[1])
        self.assertIn("S0-VM-ARCH", outputs[0])
        self.assertNotIn("EXAMPLE-PASSED", outputs[0])


if __name__ == "__main__":
    unittest.main()
