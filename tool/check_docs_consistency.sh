#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

failures=0

pass() {
  printf 'PASS: %s\n' "$1"
}

fail() {
  printf 'FAIL: %s\n' "$1"
  failures=$((failures + 1))
}

require_heading_once() {
  local file="$1"
  local heading="$2"
  local count
  count="$(rg -c "^## ${heading}$" "$file" || true)"
  if [[ "$count" == "1" ]]; then
    pass "$file has heading: ## ${heading}"
  else
    fail "$file must contain heading '## ${heading}' exactly once (found: ${count:-0})"
  fi
}

check_readme_reference() {
  local ref="$1"
  if rg -Fq "$ref" README.md; then
    pass "README.md references ${ref}"
  else
    fail "README.md must reference ${ref}"
  fi
}

check_markdown_links_in_file() {
  local file="$1"
  local target
  local link_path
  local normalized
  local base_dir

  while IFS= read -r target; do
    [[ -z "$target" ]] && continue

    normalized="${target%%#*}"
    normalized="${normalized%%\?*}"
    normalized="${normalized%% *}"
    normalized="${normalized#<}"
    normalized="${normalized%>}"

    case "$normalized" in
      "" | "#"*)
        continue
        ;;
      http://* | https://* | mailto:* | tel:* | data:* | file:* | ftp://*)
        continue
        ;;
      /*)
        continue
        ;;
    esac

    base_dir="$(dirname "$file")"
    link_path="${base_dir}/${normalized}"
    if [[ ! -e "$link_path" ]]; then
      fail "Broken markdown link in ${file}: (${target})"
    fi
  done < <(rg -No '\[[^]]+\]\(([^)]+)\)' "$file" -r '$1' || true)
}

require_heading_once "TODO.md" "Vision Source"
require_heading_once "TODO.md" "Definitions"
require_heading_once "TODO.md" "Now"
require_heading_once "TODO.md" "Next"
require_heading_once "TODO.md" "Later"
require_heading_once "TODO.md" "Open Questions"
require_heading_once "TODO.md" "Dev Tools"
require_heading_once "TODO.md" "Done Recently"

check_readme_reference "TODO.md"
check_readme_reference "docs/GAME_VISION.md"
check_readme_reference "docs/GAME_WIKI.md"

if rg -q "^## Validation Mapping" docs/GAME_VISION.md; then
  pass "docs/GAME_VISION.md contains Validation Mapping section"
else
  fail "docs/GAME_VISION.md must contain a '## Validation Mapping' section"
fi

while IFS= read -r file; do
  check_markdown_links_in_file "$file"
done < <(rg --files -g '*.md')

if (( failures > 0 )); then
  printf '\nDocs consistency check failed with %d issue(s).\n' "$failures"
  exit 1
fi

printf '\nDocs consistency check passed.\n'
