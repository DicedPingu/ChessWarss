#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# Keep desktop responsive during long debug sessions.
export MALLOC_ARENA_MAX=2

# Usage:
#   ./tool/dev_linux_safe.sh                 # GPU backend (default)
#   RENDERER=software ./tool/dev_linux_safe.sh  # software rendering fallback
renderer="${RENDERER:-gpu}"

run_args=(run -d linux --debug)
if [[ "$renderer" == "software" ]]; then
  run_args+=(--enable-software-rendering)
  export LIBGL_ALWAYS_SOFTWARE=1
fi

exec nice -n 10 flutter "${run_args[@]}" "$@"
