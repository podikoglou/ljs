# ljs - Lua JS Toolkit

This is a **tiny** codebase (~5k lines total across all files). No need for subagents, careful file loading, or complex workflows. Just read the relevant file, make the change, run the tests. The whole thing fits in your context easily.

Single-file Lua library that parses a well-defined subset of JavaScript into a Lua table-based AST.

**Status**: Parser complete. Transpilation to Lua is planned.

## Files

```
ljs/
├── ljs_parser.lua        # Parser library (single file, no deps) ~1600 lines
├── ljs_parser_dump.lua   # CLI: reads JS, prints AST as JSON ~150 lines
├── ljs_test.lua          # Minimal test harness (shared by all test files)
├── test_ljs_parser.lua   # Parser test suite (run with `lua test_ljs_parser.lua`) ~2000 lines
├── test_ljs_transpile.lua # Transpile test suite (run with `lua test_ljs_transpile.lua`) ~630 lines
├── examples/             # Example JS programs in the supported subset
├── docs/
│   └── AST.md            # Full AST node reference
└── AGENTS.md             # This file
```

## JS Subset

### Supported

Variables (`let`/`const`; `var` normalized to `let`), functions, arrow functions (expression bodies desugared to `BlockStatement` wrapping `ReturnStatement`), objects, arrays, arithmetic (`+` `-` `*` `/` `%`), strict equality (`===`/`!==`; `==` rejected at tokenizer level), comparison (`<` `>` `<=` `>=`), logical (`&&` `||`), ternary (`? :`), assignment (`=`), compound assignment (`+=` `-=` `*=` `/=` `%=`), unary (`!` `-` `+`), update (`++`/`--`, prefix and postfix), `if`/`else`, `while`, `do...while`, `for...of`, `for...in`, `for(;;)` (C-style for with optional init/test/update), `switch`/`case`/`default`/`break`, `throw`, `try`/`catch`, `return`, `console.log` (parsed as regular `CallExpression` with `MemberExpression` callee).

### Rejected (parse error)

`this`, `async`/`await`, `typeof`, `instanceof`, `==`, regex literals, Promises.

## Parser API

```lua
local parser = require("ljs_parser")

local ast, err = parser.parse("let x = 42;")
-- ast = {type="Program", body={...}}, err = nil

local ast, err = parser.parse("this.x")
-- ast = nil, err = "parse error: 'this' is not supported at line 1"
```

Also exposes `parser.tokenize(source)`, `parser.parse_tokens(tokens)`, and `parser.TOKEN` for testing.

## AST

All nodes are Lua tables with a `type` string field. See **docs/AST.md** for the full reference with fields, types, and examples for every node.

## Conventions

- Lua 5.1+ compatible, 2-space indents, snake_case internals
- No external dependencies
- Strict parsing: fails on first error, no recovery
- Tests: `lua test_ljs_parser.lua` and `lua test_ljs_transpile.lua` (exit code 0 = all pass)
- **Keep it simple.** This is a small library — don't over-engineer, don't add abstractions, don't split files. Just read the code, understand it, and make the change.

### LuaDoc conventions

All functions MUST have LuaDoc comments. Two styles are used depending on context:

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
- Every function gets a `---` doc block
- `@param` always includes type in parentheses: `@param stream (table) ...`
- `@return` includes type: `@return (table|nil) ...` or `@return table {type="..."}`
- Use `---` to start a doc block, `--` for continuation lines
- Never add comments inside function bodies unless asked

## Future Work

- Transformation layer (JS AST → Lua source)
- Source location tracking in AST nodes
- More operators (nullish coalescing `??`)
