"""Generate schema-validated Arch build evidence from measured stage outcomes."""

from __future__ import annotations

import argparse
import json
import os
import tempfile
from pathlib import Path
from typing import Any

import jsonschema.exceptions

STAGE_STATUSES = ("PASSED", "FAILED", "BLOCKED", "NOT TESTED")


def create_record(values: dict[str, Any]) -> dict[str, Any]:
    """Represent the build and evidence stages independently."""
    build = values["build"]
    artifact = values["artifact"]
    checksum = values["checksum"]
    manifest = values["manifest"]
    archiso = values["archiso"]
    complete = (
        all(stage == "PASSED" for stage in (build, artifact, checksum, manifest, archiso))
        and values["stage"] != "metadata-generation"
    )
    status = "PASSED" if complete else "FAILED"
    logs = ["build.log", "metadata.txt", "manifest.log", "provenance.log", "package-manifest.txt"]
    if checksum == "PASSED":
        logs.extend(["SHA256SUMS", "SHA512SUMS"])
    record: dict[str, Any] = {
        "id": values["id"],
        "status": status,
        "distribution": "Arch Linux",
        "distribution_revision": values["snapshot"],
        "builder_environment": values["builder"],
        "environment": "Disposable Linux builder; see build-inputs.txt",
        "os_revision": f"Arch Linux Archive {values['snapshot']}",
        "package_revisions": [],
        "commands": ["mkarchiso -v -C repo-config/pacman.conf -w work -o output profile"],
        "expected": "Build the profile and collect its manifest, Archiso version, and checksums",
        "actual": values["actual"],
        "evidence": ["build.log", "build-result.txt", "build-inputs.txt"],
        "limitations": [
            "Archive packages and builder bootstrap state are separate provenance inputs; "
            "binary reproducibility is not claimed"
        ],
        "logs": logs,
        "build_status": build,
        "artifact_status": artifact,
        "checksum_status": checksum,
        "package_manifest_status": manifest,
        "archiso_version_status": archiso,
        "evidence_complete": complete,
        "build_stage": values["stage"],
        "error": values["error"],
        "arch_archive_snapshot": values["snapshot"],
        "package_manifest": "package-manifest.txt",
    }
    if values["base_image"] != "not-applicable":
        record["arch_base_image"] = values["base_image"]
        record["arch_base_image_digest"] = values["base_digest"]
    if values["builder_digest"]:
        record["builder_image_digest"] = values["builder_digest"]
    if values["checksum_value"]:
        record["iso_sha256"] = values["checksum_value"]
    return record


def write_record(path: Path, schema_path: Path, values: dict[str, Any]) -> bool:
    """Validate the complete record before atomically writing it; return evidence completeness."""
    schema = json.loads(schema_path.read_text(encoding="utf-8"))
    jsonschema.Draft202012Validator.check_schema(schema)
    record = create_record(values)
    errors = list(jsonschema.Draft202012Validator(schema).iter_errors(record))
    if errors:
        raise ValueError("; ".join(error.message for error in errors))
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
    return record["evidence_complete"]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("record", type=Path)
    parser.add_argument("schema", type=Path)
    parser.add_argument("id")
    parser.add_argument("snapshot")
    parser.add_argument("builder")
    parser.add_argument("build", choices=STAGE_STATUSES)
    parser.add_argument("artifact", choices=STAGE_STATUSES)
    parser.add_argument("checksum", choices=STAGE_STATUSES)
    parser.add_argument("manifest", choices=STAGE_STATUSES)
    parser.add_argument("archiso", choices=STAGE_STATUSES)
    parser.add_argument("stage")
    parser.add_argument("actual")
    parser.add_argument("error")
    parser.add_argument("base_image")
    parser.add_argument("base_digest")
    parser.add_argument("builder_digest")
    parser.add_argument("checksum_value")
    args = parser.parse_args()
    try:
        complete = write_record(args.record, args.schema, vars(args))
    except (
        OSError,
        UnicodeError,
        json.JSONDecodeError,
        jsonschema.exceptions.SchemaError,
        ValueError,
    ) as exc:
        parser.error(f"record generation or schema validation failed: {exc}")
    return 0 if complete else 1


if __name__ == "__main__":
    raise SystemExit(main())
