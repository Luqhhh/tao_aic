#!/usr/bin/env bash
# Restore the original layout from checksum-verified organizer archives.
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$project_root"
python3 scripts/verify_assets.py
for directory in contest-source contest-data; do
  if [[ -e materials/$directory ]]; then
    echo "Destination already exists: materials/$directory. Use the existing materials or a fresh project directory." >&2
    exit 1
  fi
done
if [[ -e materials/open3dbench-contest-runtime.tar.gz || -L materials/open3dbench-contest-runtime.tar.gz ]]; then
  echo 'The runtime compatibility path already exists.' >&2
  exit 1
fi
tar --no-same-owner -xzf materials/archives/contest-source.tar.gz -C materials
tar --no-same-owner -xzf materials/archives/contest-data.tar.gz -C materials
# The official launcher requires a regular file, so use a hard link.
ln materials/archives/open3dbench-contest-runtime.tar.gz materials/open3dbench-contest-runtime.tar.gz
