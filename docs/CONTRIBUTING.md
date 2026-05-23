# Contributing to ljs

## Running tests

```sh
make test
```

All tests must pass (exit code 0). The test runner automatically discovers and runs all test files in `test/` subdirectories.

## Test structure

Tests live under `test/` organized by module (parser, transpile, codegen). One file per feature, lowercase with underscores. Helpers are in `test/helpers/` — parser utilities (`assert_parse_ok`, `assert_parse_fail`, `assert_parse_error`, `assert_tok`, `assert_tokenize_error`) and transpile utilities (`transpile_ok`, `run_js`).

All parser/transpiler errors are `ParseError` tables with `message` (string), `line` (1-based number), and `col` (1-based number) fields. They have a `__tostring` metamethod for simple printing. Use `ljs.format_error(err, source)` to produce a multi-line terminal display with source context and a caret.

## Adding a new JS feature

Every new JS language feature touches a predictable set of files. Follow this in order:

1. **Parser** — add tokenizer support (new token type or keyword) and/or parser rule (new AST node type or field). Update the JS Subset section in docs/ARCHITECTURE.md.
2. **docs/AST.md** — add or update the node reference. Every node type, field, and edge case must be documented.
3. **Parser tests** — create a new test file in `test/parser/` or add to an existing one (e.g., `test/parser/expressions.lua` for expression-related tests). Use helpers from `test.helpers.parser` like `assert_parse_ok`, `assert_tok`. For AST table construction in tests, use the `A` builder module (`test.helpers.ast`) instead of raw table literals:
   ```lua
   local A = require("test.helpers.ast")
   -- Instead of: { type = "BinaryExpression", operator = "+", left = { type = "Identifier", name = "x" }, ... }
   -- Use:
   A.bin("+", A.id("x"), A.num(1))
   ```
   See `test/helpers/ast.lua` for the full API. Test valid parses (check AST structure), error cases (rejected syntax), and edge cases.
4. **Codegen** — only if the feature needs a new Lua syntax construct that doesn't exist yet (e.g. `repeat...until` for `do...while`). Most features won't need this. If you add a builder, add tests to `test/codegen.lua`.
5. **Transpiler** — add a `gen.NodeType` handler that maps the JS AST to Lua source using `cg.*` calls. Never use raw string concatenation to produce Lua syntax — if codegen doesn't have the right builder, add one (step 4). If the feature needs a runtime helper (like `_ljs_add`), add it to `HELPERS` and register detection in `analyze_node`. If it's a new builtin (like `console.log`), add to `BUILTINS`.
6. **Transpiler tests** — create a new test file in `test/transpile/` or add to an existing one (e.g., `test/transpile/control_flow.lua` for control flow tests). Use helpers from `test.helpers.transpile` like `transpile_ok`, `run_js`. Add unit tests (source → expected Lua) and integration tests (transpile + run the Lua and check output). Test edge cases: empty variants, nesting, interactions with other features.
7. **Run all tests** — `make test`

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

## Error handling

All parser and transpiler errors are `ParseError` tables:

```lua
{
  message = "Expected ';', got '}'",
  line = 5,       -- 1-based
  col = 10,       -- 1-based
}
```

- `tostring(err)` → `"Expected ';', got '}' at line 5, col 10"`
- `ljs.format_error(err, source)` → multi-line output with source line and caret
- `ljs.is_parse_error(val)` → check if a value is a ParseError

Use `assert_parse_error(source, line, col, msg)` to test error positions. Use `assert_parse_fail(source, substr)` for substring-only matching.
