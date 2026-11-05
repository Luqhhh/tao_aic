#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
if [[ ! -x $project_root/.venv/bin/python ]]; then
  echo 'Create .venv and install requirements-host.txt first.' >&2
  exit 1
fi
cd "$project_root/materials/contest-source/AgenticBench"
exec "$project_root/.venv/bin/python" -m contest2 "$@"
