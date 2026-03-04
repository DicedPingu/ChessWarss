#!/usr/bin/env bash
set -euo pipefail

required_servers=(dart github)
unexpected_ok_regex='^(dart|github)$'
failed=0

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: required command not found: $cmd" >&2
    exit 2
  fi
}

require_cmd codex
require_cmd awk
require_cmd rg

server_names="$(
  codex mcp list \
    | awk 'NR > 1 && $1 != "Name" && $1 != "" { print $1 }'
)"

echo "Configured MCP servers:"
if [[ -n "${server_names}" ]]; then
  printf '%s\n' "${server_names}" | sed 's/^/- /'
else
  echo "- (none)"
fi

for name in "${required_servers[@]}"; do
  if ! printf '%s\n' "${server_names}" | rg -q "^${name}$"; then
    echo "ERROR: missing required MCP server: ${name}" >&2
    failed=1
    continue
  fi

  if ! codex mcp get "${name}" | rg -q 'enabled: true'; then
    echo "ERROR: MCP server exists but is not enabled: ${name}" >&2
    failed=1
  fi
done

unexpected="$(
  printf '%s\n' "${server_names}" \
    | rg -v "${unexpected_ok_regex}" || true
)"
if [[ -n "${unexpected}" ]]; then
  echo "ERROR: unexpected MCP server(s) configured:" >&2
  printf '%s\n' "${unexpected}" | sed 's/^/- /' >&2
  failed=1
fi

if ! codex features list | rg -q '^apps\s+.*\strue$'; then
  echo "ERROR: Codex feature 'apps' is disabled. Enable it for app research tools." >&2
  failed=1
fi

if [[ -z "${GH_TOKEN:-}" ]]; then
  echo "WARN: GH_TOKEN is not set in this shell. GitHub MCP auth may fail."
else
  echo "GitHub auth env: GH_TOKEN is set."
fi

if [[ "${failed}" -ne 0 ]]; then
  echo "MCP stack check failed." >&2
  exit 1
fi

echo "MCP stack check passed: required servers present, enabled, and clean."
