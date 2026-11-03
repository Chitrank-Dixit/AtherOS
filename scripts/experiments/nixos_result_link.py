"""Identity-checked cleanup for a Nix result symlink owned by this invocation."""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path


def identity(path: Path) -> str:
    """Return a stable device/inode identity for an existing symlink."""
    metadata = path.lstat()
    if not path.is_symlink():
        raise ValueError(f"refusing to track a non-symlink result path: {path}")
    target_hex = os.fsencode(path.readlink()).hex()
    confirmed = path.lstat()
    if (metadata.st_dev, metadata.st_ino) != (confirmed.st_dev, confirmed.st_ino):
        raise ValueError(f"result link changed while checking its identity: {path}")
    return f"{metadata.st_dev}:{metadata.st_ino}:{target_hex}"


def remove_owned_symlink(path: Path, expected_identity: str) -> bool:
    """Unlink only the same symlink previously observed by this invocation."""
    try:
        current_identity = identity(path)
    except FileNotFoundError:
        return True
    if current_identity != expected_identity:
        raise ValueError(f"result link identity changed; refusing cleanup: {path}")
    path.unlink()
    return True


def main() -> int:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="operation", required=True)
    track = subparsers.add_parser("identity")
    track.add_argument("path", type=Path)
    cleanup = subparsers.add_parser("cleanup")
    cleanup.add_argument("path", type=Path)
    cleanup.add_argument("identity")
    args = parser.parse_args()
    try:
        if args.operation == "identity":
            print(identity(args.path))
        else:
            remove_owned_symlink(args.path, args.identity)
    except (OSError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
