# ljs - Lua JS Toolkit

Lua libraries that parse a well-defined subset of JavaScript into a Lua table-based AST and transpile it to Lua source code. Lua 5.1+, 2-space indents, snake_case internals, no external dependencies.

This is a tiny codebase (~8k lines). No need for subagents or careful file loading — just read the relevant file, make the change, run the tests.

Tests: `lua test_ljs_parser.lua && lua test_ljs_transpile.lua && lua test_ljs_codegen.lua`

For architecture and layer boundaries, see docs/ARCHITECTURE.md
For AST node reference, see docs/AST.md
For feature checklist and LuaDoc conventions, see docs/CONTRIBUTING.md
