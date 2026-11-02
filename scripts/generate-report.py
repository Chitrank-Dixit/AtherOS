#!/usr/bin/env python3
"""Print the manually authored Sprint 0 report; see the report-generation notes."""

from pathlib import Path


def main() -> int:
    report = Path(__file__).resolve().parents[1] / "docs/research/sprint-0-report.md"
    if not report.is_file():
        print(f"Report not found: {report}")
        return 1
    print(report.read_text(encoding="utf-8"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
