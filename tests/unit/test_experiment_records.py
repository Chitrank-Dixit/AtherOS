import contextlib
import importlib.util
import io
import json
import subprocess
import sys
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
NIXOS_ARTIFACT_HELPER = ROOT / "scripts/experiments/find-nixos-iso.sh"
NIXOS_RECORD_PATH = ROOT / "scripts/experiments/nixos_record.py"
NIXOS_RESULT_LINK_PATH = ROOT / "scripts/experiments/nixos_result_link.py"
ARCH_EVIDENCE_PATH = ROOT / "scripts/experiments/arch_evidence.py"
ARCH_BUILD_RESULT_PATH = ROOT / "scripts/experiments/arch_build_result.py"
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
    def run_arch_outcome(
        self,
        directory: Path,
        *,
        artifact: str = "PASSED",
        checksum: str = "PASSED",
        manifest: str = "PASSED",
        archiso: str = "PASSED",
    ) -> tuple[subprocess.CompletedProcess[str], dict[str, object]]:
        output = directory / "experiment-record.json"
        result = subprocess.run(
            [
                sys.executable, str(ARCH_BUILD_RESULT_PATH), str(output),
                str(ROOT / "schemas/experiment-record.schema.json"), "ARCH-test",
                "2026/11/02", "Linux x86_64", "PASSED", artifact, checksum, manifest,
                archiso, "evidence", "controlled test outcome", "controlled evidence",
                "not-applicable", "not-applicable", "", "",
            ],
            capture_output=True,
            text=True,
            check=False,
        )
        record = json.loads(output.read_text(encoding="utf-8"))
        self.assertEqual([], list(Draft202012Validator(SCHEMA).iter_errors(record)))
        return result, record

    def test_arch_missing_manifest_fails_overall_experiment(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            result, record = self.run_arch_outcome(Path(temporary), manifest="FAILED")
            self.assertEqual(1, result.returncode)
            self.assertEqual("PASSED", record["build_status"])
            self.assertEqual("PASSED", record["artifact_status"])
            self.assertEqual("FAILED", record["package_manifest_status"])
            self.assertFalse(record["evidence_complete"])
            self.assertEqual("FAILED", record["status"])

    def test_arch_missing_checksum_fails_overall_experiment(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            result, record = self.run_arch_outcome(Path(temporary), checksum="FAILED")
            self.assertEqual(1, result.returncode)
            self.assertEqual("FAILED", record["checksum_status"])
            self.assertFalse(record["evidence_complete"])
            self.assertEqual("FAILED", record["status"])

    def test_arch_complete_evidence_passes(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            result, record = self.run_arch_outcome(Path(temporary))
            self.assertEqual(0, result.returncode, result.stderr)
            self.assertEqual("PASSED", record["status"])
            self.assertTrue(record["evidence_complete"])
            for field in (
                "build_status", "artifact_status", "checksum_status",
                "package_manifest_status", "archiso_version_status",
            ):
                self.assertEqual("PASSED", record[field])

    def test_arch_missing_iso_fails_artifact_evidence(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            result, record = self.run_arch_outcome(Path(temporary), artifact="FAILED")
            self.assertEqual(1, result.returncode)
            self.assertEqual("FAILED", record["artifact_status"])
            self.assertFalse(record["evidence_complete"])
            self.assertEqual("FAILED", record["status"])

    def test_nixos_record_round_trips_shell_sensitive_strings_and_schema(self) -> None:
        from importlib.util import module_from_spec, spec_from_file_location

        spec = spec_from_file_location("nixos_record", NIXOS_RECORD_PATH)
        self.assertIsNotNone(spec)
        assert spec is not None and spec.loader is not None
        module = module_from_spec(spec)
        spec.loader.exec_module(module)
        values = {
            "id": "NIXOS-test",
            "status": "FAILED",
            "build_status": "PASSED",
            "artifact_status": "FAILED",
            "checksum_status": "NOT TESTED",
            "complete": False,
            "stage": 'artifact "quoted" \\ newline\n雪',
            "revision": "rev\\with\nline",
            "actual": 'quote " slash \\ newline\nUnicode 雪',
            "error": "",
            "relative_iso": "",
            "checksum": "",
        }
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "record.json"
            module.write_validated_record(
                output, ROOT / "schemas/experiment-record.schema.json", values
            )
            record = json.loads(output.read_text(encoding="utf-8"))
            self.assertEqual([], list(Draft202012Validator(SCHEMA).iter_errors(record)))
            self.assertEqual(values["actual"], record["actual"])
            self.assertEqual(values["stage"], record["build_stage"])
            self.assertEqual("", record["error"])
            self.assertNotIn("artifact_relative_path", record)
            self.assertNotIn("iso_sha256", record)

    def run_result_link_helper(self, *arguments: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(NIXOS_RESULT_LINK_PATH), *arguments],
            capture_output=True,
            text=True,
            check=False,
        )

    @unittest.skipUnless(sys.platform.startswith("linux"), "requires POSIX symlinks")
    def test_nixos_result_link_cleanup_only_unlinks_owned_symlink(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            target = base / "target"
            target.mkdir()
            link = base / "result"
            link.symlink_to(target, target_is_directory=True)
            identity = self.run_result_link_helper("identity", str(link))
            self.assertEqual(0, identity.returncode, identity.stderr)
            removed = self.run_result_link_helper("cleanup", str(link), identity.stdout.strip())
            self.assertEqual(0, removed.returncode, removed.stderr)
            self.assertFalse(link.is_symlink())
            self.assertTrue(target.is_dir())

    @unittest.skipUnless(sys.platform.startswith("linux"), "requires POSIX symlinks")
    def test_nixos_result_link_cleanup_after_build_and_discovery_failures(self) -> None:
        for stage in ("build-failure", "artifact-discovery-failure"):
            with self.subTest(stage=stage), tempfile.TemporaryDirectory() as temporary:
                base = Path(temporary)
                target = base / "nix-store-result"
                target.mkdir()
                unrelated_file = base / "keep.txt"
                unrelated_file.write_text("keep", encoding="utf-8")
                unrelated_directory = base / "keep-dir"
                unrelated_directory.mkdir()
                link = base / "owned-result"
                link.symlink_to(target, target_is_directory=True)
                identity = self.run_result_link_helper("identity", str(link)).stdout.strip()
                cleaned = self.run_result_link_helper("cleanup", str(link), identity)
                self.assertEqual(0, cleaned.returncode, cleaned.stderr)
                self.assertFalse(link.is_symlink())
                self.assertTrue(target.is_dir())
                self.assertEqual("keep", unrelated_file.read_text(encoding="utf-8"))
                self.assertTrue(unrelated_directory.is_dir())

    @unittest.skipUnless(sys.platform.startswith("linux"), "requires POSIX symlinks")
    def test_nixos_result_link_cleanup_preserves_preexisting_or_replaced_link(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            first = base / "first"
            second = base / "second"
            first.mkdir()
            second.mkdir()
            link = base / "result"
            link.symlink_to(first, target_is_directory=True)
            original = self.run_result_link_helper("identity", str(link)).stdout.strip()
            preserved = self.run_result_link_helper("cleanup", str(link), "wrong-identity")
            self.assertNotEqual(0, preserved.returncode)
            link.unlink()
            link.symlink_to(second, target_is_directory=True)
            changed = self.run_result_link_helper("cleanup", str(link), original)
            self.assertNotEqual(0, changed.returncode)
            self.assertTrue(link.is_symlink())
            self.assertTrue(first.is_dir())
            self.assertTrue(second.is_dir())

    def test_nixos_record_generation_rejects_invalid_schema_without_replacing_output(self) -> None:
        from importlib.util import module_from_spec, spec_from_file_location

        spec = spec_from_file_location("nixos_record_invalid", NIXOS_RECORD_PATH)
        self.assertIsNotNone(spec)
        assert spec is not None and spec.loader is not None
        module = module_from_spec(spec)
        spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "record.json"
            output.write_text("previous", encoding="utf-8")
            values = {
                "id": "bad", "status": "PASSED", "build_status": "PASSED",
                "artifact_status": "PASSED", "checksum_status": "PASSED",
                "complete": True, "stage": "", "revision": "rev", "actual": "ok",
                "error": "none", "relative_iso": "", "checksum": "",
            }
            with self.assertRaises(ValueError):
                module.write_validated_record(
                    output, ROOT / "schemas/experiment-record.schema.json", values
                )
            self.assertEqual("previous", output.read_text(encoding="utf-8"))

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
