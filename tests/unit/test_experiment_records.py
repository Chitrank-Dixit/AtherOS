import contextlib
import importlib.util
import io
import json
import subprocess
import tempfile
import sys
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
NIXOS_ARTIFACT_HELPER = ROOT / "scripts/experiments/find-nixos-iso.sh"
ARCH_EVIDENCE_PATH = ROOT / "scripts/experiments/arch_evidence.py"
ARCH_EVIDENCE_SPEC = importlib.util.spec_from_file_location("arch_evidence", ARCH_EVIDENCE_PATH)
assert ARCH_EVIDENCE_SPEC is not None and ARCH_EVIDENCE_SPEC.loader is not None
arch_evidence = importlib.util.module_from_spec(ARCH_EVIDENCE_SPEC)
ARCH_EVIDENCE_SPEC.loader.exec_module(arch_evidence)
ARCH_SNAPSHOT_PATH = ROOT / "scripts/experiments/arch_snapshot.py"
ARCH_SNAPSHOT_SPEC = importlib.util.spec_from_file_location("arch_snapshot", ARCH_SNAPSHOT_PATH)
assert ARCH_SNAPSHOT_SPEC is not None and ARCH_SNAPSHOT_SPEC.loader is not None
arch_snapshot = importlib.util.module_from_spec(ARCH_SNAPSHOT_SPEC)
ARCH_SNAPSHOT_SPEC.loader.exec_module(arch_snapshot)
SCHEMA = json.loads((ROOT / "schemas/experiment-record.schema.json").read_text(encoding="utf-8"))


class ExperimentRecordTests(unittest.TestCase):
    def run_artifact_helper(
        self, link: Path, store: Path
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["bash", str(NIXOS_ARTIFACT_HELPER), str(link), str(store)],
            capture_output=True,
            text=True,
            check=False,
        )

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
            self.assertTrue(validator.validate(path, SCHEMA))

    def test_invalid_nested_fields_are_rejected(self) -> None:
        source = ROOT / "tests/fixtures/experiment-records/passed.example.json"
        record = json.loads(source.read_text(encoding="utf-8"))
        record["vm_configuration"] = {"cpu_count": 0}
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "nested-invalid.json"
            path.write_text(json.dumps(record), encoding="utf-8")
            self.assertTrue(validator.validate(path, SCHEMA))

    def test_malformed_json_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "malformed.json"
            path.write_text('{"id":', encoding="utf-8")
            self.assertIn("invalid JSON", validator.validate(path, SCHEMA)[0])

    @unittest.skipUnless(sys.platform.startswith("linux"), "requires Linux symlink/find tooling")
    def test_nixos_artifact_at_result_root(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            store = base / "store"
            result = store / "aether-iso"
            result.mkdir(parents=True)
            (result / "system.iso").write_bytes(b"iso")
            link = base / "result"
            link.symlink_to(result, target_is_directory=True)
            command_result = self.run_artifact_helper(link, store)
            self.assertEqual(0, command_result.returncode, command_result.stderr)
            artifact, relative = command_result.stdout.rstrip("\n").split("\t", maxsplit=1)
            self.assertEqual(str(result / "system.iso"), artifact)
            self.assertEqual("system.iso", relative)

    @unittest.skipUnless(sys.platform.startswith("linux"), "requires Linux symlink/find tooling")
    def test_nixos_artifact_in_iso_subdirectory(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            store = base / "store"
            result = store / "aether-iso"
            (result / "iso").mkdir(parents=True)
            (result / "iso/system.iso").write_bytes(b"iso")
            link = base / "result"
            link.symlink_to(result, target_is_directory=True)
            command_result = self.run_artifact_helper(link, store)
            self.assertEqual(0, command_result.returncode, command_result.stderr)
            _, relative = command_result.stdout.rstrip("\n").split("\t", maxsplit=1)
            self.assertEqual("iso/system.iso", relative)

    @unittest.skipUnless(sys.platform.startswith("linux"), "requires Linux symlink/find tooling")
    def test_nixos_artifact_missing_and_multiple_are_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            store = base / "store"
            result = store / "empty"
            result.mkdir(parents=True)
            link = base / "result"
            link.symlink_to(result, target_is_directory=True)
            missing = self.run_artifact_helper(link, store)
            self.assertNotEqual(0, missing.returncode)
            self.assertIn("no regular ISO", missing.stderr)
            (result / "one.iso").touch()
            (result / "two.iso").touch()
            multiple = self.run_artifact_helper(link, store)
            self.assertNotEqual(0, multiple.returncode)
            self.assertIn("found 2", multiple.stderr)

    @unittest.skipUnless(sys.platform.startswith("linux"), "requires Linux symlink/find tooling")
    def test_nixos_result_link_outside_store_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            store = base / "store"
            external = base / "external"
            store.mkdir()
            external.mkdir()
            (external / "system.iso").touch()
            link = base / "result"
            link.symlink_to(external, target_is_directory=True)
            result = self.run_artifact_helper(link, store)
            self.assertNotEqual(0, result.returncode)
            self.assertIn("outside", result.stderr)

    @unittest.skipUnless(sys.platform.startswith("linux"), "requires Linux symlink/find tooling")
    def test_nixos_discovery_does_not_follow_nested_symlink_directories(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            store = base / "store"
            result = store / "aether-iso"
            result.mkdir(parents=True)
            external = base / "external"
            external.mkdir()
            (external / "outside.iso").touch()
            (result / "external").symlink_to(external, target_is_directory=True)
            link = base / "result"
            link.symlink_to(result, target_is_directory=True)
            command_result = self.run_artifact_helper(link, store)
            self.assertNotEqual(0, command_result.returncode)
            self.assertIn("no regular ISO", command_result.stderr)

    def test_arch_snapshot_requires_real_date_and_matching_immutable_base(self) -> None:
        digest = "a" * 64
        base = f"archlinux/archlinux:base-devel-20261102.0.620672@sha256:{digest}"
        self.assertTrue(arch_snapshot.validate_snapshot("2026/11/02"))
        self.assertFalse(arch_snapshot.validate_snapshot("2026/99/02"))
        self.assertTrue(arch_snapshot.base_matches_snapshot(base, "2026/11/02"))
        self.assertFalse(arch_snapshot.base_matches_snapshot(base, "2026/11/03"))
        self.assertFalse(
            arch_snapshot.base_matches_snapshot(
                "archlinux/archlinux:base-devel-20261102.0.620672", "2026/11/02"
            )
        )

    def test_arch_snapshot_metadata_records_all_inputs_and_limitations(self) -> None:
        digest = "a" * 64
        base = f"archlinux/archlinux:base-devel-20261102.0.620672@sha256:{digest}"
        metadata = arch_snapshot.build_metadata(
            "2026/11/02",
            base,
            f"sha256:{digest}",
            "sha256:" + "b" * 64,
            "archiso 86-1",
            "package-manifest.txt",
        )
        self.assertEqual("2026/11/02", metadata["archive_snapshot"])
        self.assertEqual(base, metadata["base_image_reference"])
        self.assertEqual("EXPERIMENTAL", metadata["reproducibility"])
        self.assertIn("may differ", str(metadata["reproducibility_limitation"]))

    def test_arch_manifest_missing_database_is_failure(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            database = Path(temporary) / "missing"
            with self.assertRaisesRegex(arch_evidence.ManifestError, "database is missing"):
                arch_evidence.extract_manifest(database)

    def test_arch_manifest_rejects_incomplete_package_description(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            database = Path(temporary)
            package = database / "pkg-1"
            package.mkdir()
            (package / "desc").write_text("%NAME%\npkg\n", encoding="utf-8")
            with self.assertRaisesRegex(arch_evidence.ManifestError, "version field is missing"):
                arch_evidence.extract_manifest(database)

    def test_report_is_deterministic_and_omits_synthetic_fixtures(self) -> None:
        outputs = []
        for _ in range(2):
            output = io.StringIO()
            arguments = [str(REPORT_PATH), str(ROOT / "tests/fixtures")]
            with patch("sys.argv", arguments), contextlib.redirect_stdout(output):
                self.assertEqual(0, report_generator.main())
            outputs.append(output.getvalue())
        self.assertEqual(outputs[0], outputs[1])
        self.assertIn("S0-VM-ARCH", outputs[0])
        self.assertNotIn("EXAMPLE-PASSED", outputs[0])

    def test_report_rejects_invalid_records_without_emitting_outcomes(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            records = Path(directory)
            invalid = json.loads(
                (ROOT / "tests/fixtures/experiment-records/passed.example.json").read_text(
                    encoding="utf-8"
                )
            )
            invalid["vm_configuration"] = {"cpu_count": 0}
            (records / "invalid.json").write_text(json.dumps(invalid), encoding="utf-8")
            output = io.StringIO()
            arguments = [str(REPORT_PATH), str(records)]
            with patch("sys.argv", arguments), contextlib.redirect_stdout(output):
                self.assertEqual(1, report_generator.main())
            self.assertEqual("", output.getvalue())


if __name__ == "__main__":
    unittest.main()
