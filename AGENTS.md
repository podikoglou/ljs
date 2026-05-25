# ljs - Lua JS Toolkit

Lua libraries that parse a well-defined subset of JavaScript into a Lua table-based AST and transpile it to Lua source code. Lua 5.2+ (uses `goto` in generated code), 2-space indents, snake_case internals, no external dependencies.

Source is in `src/ljs/` with hierarchical module names (`ljs.parser`, `ljs.codegen`, `ljs.transpile`). Runtime templates in `src/ljs/runtime/`. Rockspec in `rockspec/`.

This is a ~16k line codebase. No need for subagents or careful file loading — just read the relevant file, make the change, run the tests.

Tests: `make test`

## Git Flow
- `develop` is the default branch — branch off it for all work
- `main` only receives merges from `develop`
- Always create PRs targeting `develop`
- When starting work: `git checkout develop && git pull && git checkout -b <branch>`
- Tests are skipped by lefthook on `develop` — CI catches failures

For architecture and layer boundaries, see docs/ARCHITECTURE.md
For AST node reference, see docs/AST.md
For feature checklist and LuaDoc conventions, see docs/CONTRIBUTING.md
