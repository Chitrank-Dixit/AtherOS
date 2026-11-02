#!/usr/bin/env python3
"""Validate experiment JSON fixtures against this repository's record contract."""

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCHEMA_PATH = ROOT / "schemas/experiment-record.schema.json"
STATUSES = {"PASSED", "FAILED", "BLOCKED", "NOT TESTED"}
REQUIRED = {
    "id", "status", "environment", "os_revision", "package_revisions",
    "commands", "expected", "actual", "evidence", "limitations",
}


def validate(path: Path, schema: dict) -> list[str]:
    errors: list[str] = []
    try:
        record = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"{path}: {exc}"]
    if not isinstance(record, dict):
        return [f"{path}: record must be a JSON object"]
    missing = REQUIRED - record.keys()
    if missing:
        errors.append(f"{path}: missing required fields: {', '.join(sorted(missing))}")
    allowed = set(schema["properties"])
    extra = record.keys() - allowed
    if extra:
        errors.append(f"{path}: unknown fields: {', '.join(sorted(extra))}")
    if record.get("status") not in STATUSES:
        errors.append(f"{path}: invalid status")
    for field in ("id", "environment", "os_revision", "expected", "actual"):
        if field in record and (not isinstance(record[field], str) or not record[field].strip()):
            errors.append(f"{path}: {field} must be a non-empty string")
    for field in ("commands", "evidence", "limitations"):
        if field in record and (not isinstance(record[field], list) or any(not isinstance(x, str) for x in record[field])):
            errors.append(f"{path}: {field} must be an array of strings")
    if record.get("status") in {"PASSED", "FAILED"} and not record.get("evidence"):
        errors.append(f"{path}: {record['status']} requires evidence")
    if record.get("status") == "BLOCKED" and not record.get("blockers"):
        errors.append(f"{path}: BLOCKED requires a non-empty blockers array")
    if record.get("status") == "NOT TESTED" and not record.get("limitations"):
        errors.append(f"{path}: NOT TESTED requires a reason in limitations")
    for field in ("build_status", "boot_status"):
        if field in record and record[field] not in STATUSES:
            errors.append(f"{path}: invalid {field}")
    if "iso_sha256" in record and (not isinstance(record["iso_sha256"], str) or len(record["iso_sha256"]) != 64 or any(char not in "0123456789abcdefABCDEF" for char in record["iso_sha256"])):
        errors.append(f"{path}: iso_sha256 must contain 64 hexadecimal characters")
    for package in record.get("package_revisions", []):
        if not isinstance(package, dict) or set(package) != {"name", "revision"} or not all(isinstance(package[k], str) and package[k] for k in package):
            errors.append(f"{path}: package_revisions entries require non-empty name and revision")
    if record.get("fixture_only") and not path.name.endswith(".example.json"):
        errors.append(f"{path}: fixture_only is reserved for *.example.json files")
    return errors


def main() -> int:
    try:
        schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"Schema error: {exc}", file=sys.stderr)
        return 1
    paths = sorted((ROOT / "tests/fixtures").rglob("*.json"))
    if not paths:
        print("No experiment record fixtures found", file=sys.stderr)
        return 1
    errors = [error for path in paths for error in validate(path, schema)]
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print(f"Validated {len(paths)} experiment record fixture(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
