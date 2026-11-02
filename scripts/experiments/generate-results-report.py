#!/usr/bin/env python3
"""Render a deterministic Markdown summary from validated JSON experiment records."""

import argparse
import importlib.util
import json
from pathlib import Path
import sys

VALIDATOR = Path(__file__).with_name("validate-records.py")
SPEC = importlib.util.spec_from_file_location("record_validator", VALIDATOR)
assert SPEC is not None and SPEC.loader is not None
validator = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(validator)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("records", type=Path, help="directory containing experiment JSON records")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    schema = json.loads((root / "schemas/experiment-record.schema.json").read_text(encoding="utf-8"))
    paths = sorted(args.records.rglob("*.json"))
    if not paths:
        print("No records found", file=sys.stderr)
        return 1
    records = []
    for path in paths:
        issues = validator.validate(path, schema)
        if issues:
            print("\n".join(issues), file=sys.stderr)
            return 1
        records.append(json.loads(path.read_text(encoding="utf-8")))
    print("# Experiment results\n")
    print("Generated deterministically from validated records. `fixture_only` examples are excluded from outcome counts.\n")
    print("| ID | Status | Environment | OS revision | Actual result |")
    print("| --- | --- | --- | --- | --- |")
    for record in sorted(records, key=lambda item: item["id"]):
        if record.get("fixture_only"):
            continue
        values = [record["id"], record["status"], record["environment"], record["os_revision"], record["actual"]]
        print("| " + " | ".join(value.replace("|", "\\|").replace("\n", " ") for value in values) + " |")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
