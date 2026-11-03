"""Validate Arch Archive snapshot and immutable base-image inputs."""

from __future__ import annotations

import json
import re
import sys
from datetime import datetime
from pathlib import Path

BASE_IMAGE_PATTERN = re.compile(
    r"^(?P<repository>archlinux/archlinux):(?P<tag>[A-Za-z0-9._-]+)"
    r"@sha256:(?P<digest>[a-f0-9]{64})$"
)
TAG_DATE_PATTERN = re.compile(r"(?:^|[-.])(?P<date>[0-9]{8})(?:\.|$)")


def validate_snapshot(snapshot: str) -> bool:
    """Accept only real Gregorian dates in the required YYYY/MM/DD form."""
    try:
        parsed = datetime.strptime(snapshot, "%Y/%m/%d")
    except ValueError:
        return False
    return parsed.strftime("%Y/%m/%d") == snapshot


def parse_base_image(reference: str) -> tuple[str, str] | None:
    """Return the dated tag and immutable digest from a strict official ref."""
    match = BASE_IMAGE_PATTERN.fullmatch(reference)
    if match is None:
        return None
    return match.group("tag"), f"sha256:{match.group('digest')}"


def base_matches_snapshot(reference: str, snapshot: str) -> bool:
    """Require a digest-pinned dated base image from the chosen snapshot date."""
    if not validate_snapshot(snapshot):
        return False
    parsed = parse_base_image(reference)
    if parsed is None:
        return False
    tag, _ = parsed
    match = TAG_DATE_PATTERN.search(tag)
    return match is not None and match.group("date") == snapshot.replace("/", "")


def build_metadata(
    snapshot: str,
    base_reference: str,
    base_digest: str,
    builder_digest: str,
    archiso_version: str,
    package_manifest: str,
) -> dict[str, str | None]:
    """Return provenance metadata without claiming a coherent package snapshot."""
    if not validate_snapshot(snapshot):
        raise ValueError("snapshot must be a valid date in YYYY/MM/DD format")
    if base_reference != "not-applicable":
        parsed = parse_base_image(base_reference)
        if parsed is None or not base_matches_snapshot(base_reference, snapshot):
            raise ValueError("base image must be digest-pinned and match the snapshot date")
        if parsed[1] != base_digest:
            raise ValueError("base image digest does not match its immutable reference")
        base_reference_value: str | None = base_reference
        base_digest_value: str | None = base_digest
    else:
        base_reference_value = None
        base_digest_value = None
    if builder_digest and not re.fullmatch(r"sha256:[a-f0-9]{64}", builder_digest):
        raise ValueError("builder image digest must be a sha256 OCI digest when supplied")
    return {
        "archive_snapshot": snapshot,
        "base_image_reference": base_reference_value,
        "base_image_digest": base_digest_value,
        "builder_image_digest": builder_digest or None,
        "archiso_version": archiso_version.strip() or "unavailable",
        "package_manifest": package_manifest,
        "reproducibility": "EXPERIMENTAL",
        "reproducibility_limitation": (
            "Bootstrap image or VM package state may differ from the Archive; "
            "pacman is not used to downgrade it."
        ),
    }


def write_metadata(args: list[str]) -> int:
    if len(args) != 6:
        print(
            "Usage: arch_snapshot.py --write-metadata OUTPUT DATE BASE_REF BASE_DIGEST "
            "BUILDER_DIGEST ARCHISO_VERSION",
            file=sys.stderr,
        )
        return 2
    output, snapshot, base_ref, base_digest, builder_digest, archiso_version = args
    try:
        metadata = build_metadata(
            snapshot,
            base_ref,
            base_digest,
            builder_digest,
            archiso_version,
            "package-manifest.txt",
        )
        rendered = json.dumps(metadata, indent=2, sort_keys=True) + "\n"
        Path(output).write_text(rendered, encoding="utf-8")
    except (OSError, ValueError) as exc:
        print(f"ERROR: cannot write Arch build provenance: {exc}", file=sys.stderr)
        return 1
    return 0


def main() -> int:
    if len(sys.argv) > 1 and sys.argv[1] == "--write-metadata":
        return write_metadata(sys.argv[2:])
    if len(sys.argv) == 3 and sys.argv[1] == "--validate-date":
        if validate_snapshot(sys.argv[2]):
            return 0
        print("ERROR: snapshot must be a valid date in YYYY/MM/DD format", file=sys.stderr)
        return 1
    if len(sys.argv) != 3:
        print(
            "Usage: arch_snapshot.py YYYY/MM/DD BASE_IMAGE_REF "
            "| --validate-date YYYY/MM/DD",
            file=sys.stderr,
        )
        return 2
    snapshot, reference = sys.argv[1:]
    if not validate_snapshot(snapshot):
        print("ERROR: snapshot must be a valid date in YYYY/MM/DD format", file=sys.stderr)
        return 1
    parsed = parse_base_image(reference)
    if parsed is None:
        print(
            "ERROR: base image must be an official archlinux/archlinux dated tag "
            "pinned by sha256 digest",
            file=sys.stderr,
        )
        return 1
    if not base_matches_snapshot(reference, snapshot):
        print(
            "ERROR: base image tag date must match the selected Archive snapshot date",
            file=sys.stderr,
        )
        return 1
    tag, digest = parsed
    print(f"tag={tag}\ndigest={digest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
