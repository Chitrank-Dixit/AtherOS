"""Extract and validate the package database produced by mkarchiso."""

from __future__ import annotations

import sys
from pathlib import Path


class ManifestError(ValueError):
    """Raised when Archiso did not leave a complete package manifest."""


def read_desc(path: Path) -> tuple[str, str]:
    """Read package name and version fields from one pacman desc file."""
    lines = path.read_text(encoding="utf-8").splitlines()
    fields: dict[str, str] = {}
    for index, line in enumerate(lines[:-1]):
        if line in {"%NAME%", "%VERSION%"}:
            value = lines[index + 1].strip()
            if value:
                fields[line] = value
    name = fields.get("%NAME%")
    version = fields.get("%VERSION%")
    if not name or not version:
        raise ManifestError(f"{path}: package name or version field is missing")
    return name, version


def extract_manifest(database: Path) -> list[tuple[str, str]]:
    """Read all package records; reject absent, empty, or malformed databases."""
    if not database.is_dir():
        raise ManifestError(f"package database is missing: {database}")
    desc_files = sorted(database.glob("*/desc"))
    if not desc_files:
        raise ManifestError(f"no package desc files found under {database}")
    packages = [read_desc(path) for path in desc_files]
    packages.sort()
    return packages


def main() -> int:
    if len(sys.argv) != 3:
        print("Usage: arch_evidence.py PACMAN_LOCAL_DATABASE OUTPUT_MANIFEST", file=sys.stderr)
        return 2
    database, output = map(Path, sys.argv[1:])
    try:
        packages = extract_manifest(database)
        manifest = "".join(f"{name} {version}\n" for name, version in packages)
        output.write_text(manifest, encoding="utf-8")
    except (OSError, UnicodeError, ManifestError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    print(f"Extracted {len(packages)} package records to {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
