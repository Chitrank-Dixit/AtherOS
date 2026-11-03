#!/usr/bin/env python3
"""Render a deterministic Markdown summary from schema-valid experiment records."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

from jsonschema import Draft202012Validator
from jsonschema.exceptions import SchemaError, ValidationError

ROOT = Path(__file__).resolve().parents[2]
SCHEMA_PATH = ROOT / "schemas/experiment-record.schema.json"


def _read_record(path: Path, validator: Draft202012Validator) -> dict[str, Any]:
    try:
        record = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise ValueError(f"{path}: invalid JSON or unreadable file: {exc}") from exc
    issues = sorted(
        validator.iter_errors(record),
        key=lambda error: tuple(str(part) for part in error.absolute_path),
    )
    if issues:
        raise ValueError("\n".join(_format_error(path, issue) for issue in issues))
    return record


def _format_error(path: Path, issue: ValidationError) -> str:
    location = ".".join(str(part) for part in issue.absolute_path) or "<root>"
    return f"{path}: {location}: {issue.message}"


def _render(records: list[dict[str, Any]]) -> str:
    lines = [
        "# Experiment results",
        "",
        "Generated deterministically from Draft 2020-12 schema-valid records. "
        "`fixture_only` examples are excluded from outcome counts.",
        "",
        "| ID | Status | Environment | OS revision | Actual result |",
        "| --- | --- | --- | --- | --- |",
    ]
    for record in sorted(records, key=lambda item: item["id"]):
        if record.get("fixture_only"):
            continue
        values = [
            record["id"],
            record["status"],
            record["environment"],
            record["os_revision"],
            record["actual"],
        ]
        escaped = [value.replace("|", "\\|").replace("\n", " ") for value in values]
        lines.append("| " + " | ".join(escaped) + " |")
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("records", type=Path, help="directory containing experiment JSON records")
    args = parser.parse_args()
    try:
        schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
        Draft202012Validator.check_schema(schema)
    except (OSError, UnicodeError, json.JSONDecodeError, SchemaError) as exc:
        print(f"Schema error: {exc}", file=sys.stderr)
        return 1

    paths = sorted(args.records.rglob("*.json"))
    if not paths:
        print(f"No records found under {args.records}", file=sys.stderr)
        return 1
    validator = Draft202012Validator(schema)
    try:
        records = [_read_record(path, validator) for path in paths]
    except ValueError as exc:
        print(exc, file=sys.stderr)
        return 1
    print(_render(records), end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
