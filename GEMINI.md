# Flutter Development Guidelines

## Efficient Workflow
- **LSP first**: Use `mcp_dart_lsp` (`hover`, `resolveWorkspaceSymbol`) to understand types and documentation without reading whole files.
- **DTD loop**: Use `mcp_dart_hot_reload` or `mcp_dart_hot_restart` after edits to verify changes in the running app.
- **Surgical edits**: Use `replace` for precise changes. Check `analyze_files` immediately after.
- **Testing**: Run `mcp_dart_pub` with `get` if dependencies change. Use `mcp_dart_analyze_files` before `run_shell_command` with `flutter test`.

## AI-Specific Optimization
- **Context Efficiency**: Keep file reads minimal. Use `grep_search` to find symbols.
- **Sub-Agents**: Delegate batch tasks (e.g., refactoring multiple widgets) to `generalist`.
- **Validation**: Always verify UI changes by checking `mcp_dart_get_runtime_errors` after a hot reload.

## Project Git Policy
- ChessWarss work should leave a visible Git trail: make scoped commits after validated changes and push them to `origin` when the user asks for git/push.
- Never stage unrelated dirty files just because they are present.
- Keep experimental mechanics in `Tabulae Probationis` until they are tested enough to become real game rules.
- Test/prototype screens should say what works, what is not proven, and what direction they are testing.
