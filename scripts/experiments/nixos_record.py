"""Serialize and validate NixOS experiment records without shell interpolation."""

from __future__ import annotations

import argparse
import json
import os
import tempfile
from pathlib import Path
from typing import Any

from jsonschema import Draft202012Validator
from jsonschema.exceptions import SchemaError


def create_record(values: dict[str, Any]) -> dict[str, Any]:
    """Build a schema-compatible record from explicit scalar inputs."""
    status = values["status"]
    record: dict[str, Any] = {
        "id": values["id"],
        "status": status,
        "distribution": "NixOS",
        "distribution_revision": values["revision"],
        "builder_environment": "see environment.txt",
        "environment": "Disposable Linux builder; see environment.txt",
        "os_revision": f"nixpkgs {values['revision']}",
        "package_revisions": [],
        "commands": ["nix flake metadata", "nix eval", "nix build"],
        "expected": "Evaluate and build one NixOS ISO from the committed flake lock",
        "actual": values["actual"],
        "evidence": ["metadata.log", "build.log"],
        "limitations": ["Builder details and complete logs are stored alongside this record"],
        "logs": [
            "metadata.log", "build.log", "artifact-discovery.log", "checksum.log",
            "lock-revision.log", "environment.txt", "nix-version.txt", "git-commit.txt",
        ],
        "build_status": values["build_status"],
        "artifact_status": values["artifact_status"],
        "checksum_status": values["checksum_status"],
        "evidence_complete": values["complete"],
        "build_stage": values["stage"],
        "error": values["error"],
    }
    if values["checksum_status"] == "PASSED":
        record["logs"].extend(["SHA256SUMS", "SHA512SUMS"])
    if values["relative_iso"]:
        record["artifact_relative_path"] = values["relative_iso"]
    if values["checksum"]:
        record["iso_sha256"] = values["checksum"]
    if status == "BLOCKED":
        record["blockers"] = [values["error"] or "Prerequisite prevented execution"]
    return record


def write_validated_record(path: Path, schema_path: Path, values: dict[str, Any]) -> None:
    """Validate first, then atomically replace the record with valid JSON."""
    schema = json.loads(schema_path.read_text(encoding="utf-8"))
    Draft202012Validator.check_schema(schema)
    record = create_record(values)
    errors = list(Draft202012Validator(schema).iter_errors(record))
    if errors:
        details = "; ".join(error.message for error in errors)
        raise ValueError(f"Generated experiment record does not match schema: {details}")

    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as stream:
            json.dump(record, stream, ensure_ascii=False, indent=2)
            stream.write("\n")
        Path(temporary).replace(path)
    except BaseException:
        Path(temporary).unlink(missing_ok=True)
        raise


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("record", type=Path)
    parser.add_argument("schema", type=Path)
    parser.add_argument("id")
    parser.add_argument("status", choices=["PASSED", "FAILED", "BLOCKED", "NOT TESTED"])
    parser.add_argument("build_status", choices=["PASSED", "FAILED", "BLOCKED", "NOT TESTED"])
    parser.add_argument("artifact_status", choices=["PASSED", "FAILED", "BLOCKED", "NOT TESTED"])
    parser.add_argument("checksum_status", choices=["PASSED", "FAILED", "BLOCKED", "NOT TESTED"])
    parser.add_argument("complete", choices=["true", "false"])
    parser.add_argument("stage")
    parser.add_argument("revision")
    parser.add_argument("actual")
    parser.add_argument("error")
    parser.add_argument("relative_iso")
    parser.add_argument("checksum")
    args = parser.parse_args()
    values = vars(args)
    values.update(complete=args.complete == "true", revision=args.revision)
    try:
        write_validated_record(args.record, args.schema, values)
    except (OSError, UnicodeError, json.JSONDecodeError, SchemaError, ValueError) as exc:
        parser.error(str(exc))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
