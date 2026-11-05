#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
if [[ ! -x $project_root/.venv/bin/python ]]; then
  echo 'Create .venv and install requirements-host.txt first.' >&2
  exit 1
fi
# Pass only the credential path; the official runner reads the key when needed.
default_key_file="$HOME/.config/tao-aic/deepseek.key"
if [[ -z ${DEEPSEEK_API_KEY:-} && -z ${DEEPSEEK_API_KEY_FILE:-} && -f $default_key_file ]]; then
  export DEEPSEEK_API_KEY_FILE="$default_key_file"
fi
cd "$project_root/materials/contest-source/AgenticBench"
exec "$project_root/.venv/bin/python" -m contest2 "$@"
