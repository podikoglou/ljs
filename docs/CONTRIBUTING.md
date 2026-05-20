# Contributing to ljs

## Running tests

```sh
lua test_ljs_parser.lua && lua test_ljs_transpile.lua && lua test_ljs_codegen.lua
```

All three must pass (exit code 0).

## Adding a new JS feature

Every new JS language feature touches a predictable set of files. Follow this in order:

1. **Parser** — add tokenizer support (new token type or keyword) and/or parser rule (new AST node type or field). Update the JS Subset section in docs/ARCHITECTURE.md.
2. **docs/AST.md** — add or update the node reference. Every node type, field, and edge case must be documented.
3. **Parser tests** — add tests for the new syntax: valid parses (check AST structure), error cases (rejected syntax), and edge cases.
4. **Codegen** — only if the feature needs a new Lua syntax construct that doesn't exist yet (e.g. `repeat...until` for `do...while`). Most features won't need this. If you add a builder, add tests.
5. **Transpiler** — add a `gen.NodeType` handler that maps the JS AST to Lua source using `cg.*` calls. Never use raw string concatenation to produce Lua syntax — if codegen doesn't have the right builder, add one (step 4). If the feature needs a runtime helper (like `_ljs_add`), add it to `HELPERS` and register detection in `analyze_node`. If it's a new builtin (like `console.log`), add to `BUILTINS`.
6. **Transpiler tests** — add unit tests (source → expected Lua) and integration tests (transpile + run the Lua and check output). Test edge cases: empty variants, nesting, interactions with other features.
7. **Run all tests**.

## LuaDoc conventions

All functions get a `---` doc block.

**AST builders** (simple factory functions) — param/return only, no summary:
```lua
--- @param name (string) Description
--- @return table {type="...", field=value}
local function foo(name, token)
```

**Public API, token stream methods, and parser functions** — summary + param/return:
```lua
--- One-line summary of what the function does.
-- Extended description if needed.
-- @param name (type) Description
-- @return (type) Description
function foo(stream)
```

Rules:
- `@param` always includes type in parentheses: `@param stream (table) ...`
- `@return` includes type: `@return (table|nil) ...` or `@return table {type="..."}`
- Use `---` to start a doc block, `--` for continuation lines
- No comments inside function bodies unless asked
