# ChessWarss Agent Notes

## MCP Stack

- Keep the MCP stack minimal for this repo: `dart`, `github`.
- Keep `features.apps = true` in Codex config so app-based research tools are available.
- Do not add a `filesystem` MCP server for this repo. Local shell + repo tools already cover file access.

## Tool Routing Defaults

- Use `mcp__dart__*` first for Flutter/Dart development tasks.
- Prefer `mcp__dart__analyze_files` for analysis.
- Prefer `mcp__dart__run_tests` for tests.
- Prefer `mcp__dart__pub` for pub package operations.
- Prefer `mcp__dart__dart_format` for formatting.
- Prefer `mcp__dart__launch_app`, `mcp__dart__get_runtime_errors`, and `mcp__dart__hot_reload` for run/debug loops.
- Use `mcp__github__*` first for GitHub operations.
- Prefer `mcp__github__issue_*` and `mcp__github__pull_request_*` for issue/PR workflows.
- Prefer `mcp__github__list_branches`, `mcp__github__list_commits`, and `mcp__github__list_releases` for branch/commit/release introspection.
- Use app research tools (via `search_tool_bm25`) for external comparisons and discovery.
- Use shell/apply_patch for local files in this repository.

## Safety and Quality Defaults

- Before merge/review requests, run `mcp__dart__analyze_files`.
- Before merge/review requests, run `mcp__dart__run_tests`.
- Before merge/review requests, run `dart run tool/check_dependencies.dart`.
- Avoid destructive git commands unless the user explicitly requests them.

## Validation

- Use `./tool/check_mcp_stack.sh` to validate local Codex MCP configuration quickly.
