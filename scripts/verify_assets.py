#!/usr/bin/env python3
"""Verify the migrated official files without invoking the contest evaluator."""

import hashlib
import json
from pathlib import Path


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    manifest = json.loads((root / "manifests/assets.json").read_text())
    failures = 0
    for record in manifest["files"]:
        path = root / record["path"]
        if not path.is_file():
            print(f"MISSING {record['path']}")
            failures += 1
            continue
        digest = hashlib.sha256()
        with path.open("rb") as stream:
            for block in iter(lambda: stream.read(16 * 1024 * 1024), b""):
                digest.update(block)
        valid = (
            path.stat().st_size == record["size_bytes"]
            and digest.hexdigest() == record["sha256"]
        )
        print(f"{'OK' if valid else 'MISMATCH'} {record['path']}")
        failures += not valid
    return int(failures > 0)


if __name__ == "__main__":
    raise SystemExit(main())
