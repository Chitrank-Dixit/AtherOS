#!/usr/bin/env python3
"""Validate experiment records against the complete repository JSON Schema."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

from jsonschema import Draft202012Validator
from jsonschema.exceptions import SchemaError, ValidationError

ROOT = Path(__file__).resolve().parents[2]
SCHEMA_PATH = ROOT / "schemas/experiment-record.schema.json"


def load_schema() -> dict[str, Any]:
    """Load and check the schema itself before validating any records."""
    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    Draft202012Validator.check_schema(schema)
    return schema


def validate(path: Path, schema: dict[str, Any]) -> list[str]:
    """Return all file-specific JSON parsing or schema validation errors."""
    try:
        record = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        return [f"{path}: invalid JSON or unreadable file: {exc}"]

    validator = Draft202012Validator(schema)
    issues = sorted(
        validator.iter_errors(record),
        key=lambda error: tuple(str(part) for part in error.absolute_path),
    )
    return [_format_error(path, issue) for issue in issues]


def _format_error(path: Path, issue: ValidationError) -> str:
    location = ".".join(str(part) for part in issue.absolute_path) or "<root>"
    return f"{path}: {location}: {issue.message}"


def main() -> int:
    try:
        schema = load_schema()
    except (OSError, UnicodeError, json.JSONDecodeError, SchemaError) as exc:
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
    print(f"Validated {len(paths)} experiment record fixture(s) with Draft 2020-12.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
