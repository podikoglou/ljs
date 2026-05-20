# ljs - Lua JS Toolkit

This is a **tiny** codebase (~8k lines total across all files). No need for subagents, careful file loading, or complex workflows. Just read the relevant file, make the change, run the tests. The whole thing fits in your context easily.

Lua libraries that parse a well-defined subset of JavaScript into a Lua table-based AST and transpile it to Lua source code.

**Status**: Parser and transpiler complete.

## Files

```
ljs/
├── ljs_parser.lua          # Parser library (single file, no deps) ~1850 lines
├── ljs_parser_dump.lua     # CLI: reads JS, prints AST as JSON ~150 lines
├── ljs_codegen.lua         # Lua source code builder library (no deps) ~310 lines
├── ljs_transpile.lua       # JS AST → Lua transpiler (uses ljs_codegen) ~720 lines
├── ljs_transpile_dump.lua  # CLI: reads JS, prints Lua source ~40 lines
├── ljs_test.lua            # Minimal test harness (shared by all test files)
├── test_ljs_parser.lua     # Parser test suite (run with `lua test_ljs_parser.lua`)
├── test_ljs_transpile.lua  # Transpile test suite (run with `lua test_ljs_transpile.lua`)
├── test_ljs_codegen.lua    # Codegen test suite (run with `lua test_ljs_codegen.lua`)
├── examples/               # Example JS programs in the supported subset
├── docs/
│   └── AST.md              # Full AST node reference
└── AGENTS.md               # This file
```

## Architecture

The codebase has three independent layers with strict boundaries:

```
JS source → [Parser] → AST → [Transpiler] → cg.* calls → [Codegen] → Lua source
```

1. **Parser** (`ljs_parser.lua`) — JS source → AST. No dependencies. Knows nothing about Lua.
2. **Codegen** (`ljs_codegen.lua`) — Pure Lua source code builder. No dependencies. Knows nothing about JavaScript or ASTs. Every function takes strings and returns formatted Lua source strings.
3. **Transpiler** (`ljs_transpile.lua`) — AST → Lua source via codegen. Depends on both parser and codegen. Makes all semantic decisions (what Lua code to emit for each JS construct) but NEVER does raw string concatenation to produce Lua syntax. Every Lua syntax construct goes through `cg.*`.

### Design rule: transpiler never generates code directly

The transpiler decides **what** to emit based on the AST. Codegen decides **how** to format it as Lua source. The transpiler MUST NOT:

- Concatenate strings to produce Lua keywords, operators, or delimiters (e.g. `.. "goto "`, `.. "function()"`)
- Use `cg.pad()` directly — use `cg.*` functions that accept indent parameters
- Build IIFE wrappers manually — use `cg.iife()`
- Construct goto/label strings manually — use `cg.goto_stmt()` and `cg.label()`
- Build inline Lua statements manually — use `cg.local_inline()`, `cg.return_inline()`, `cg.inline_if_return()`

**Exception**: prepending a single `;` character to a codegen-produced expression (to prevent Lua ambiguous function call parsing) is acceptable: `cg.expr_stmt(";" .. codegen_expr, indent)`.

If you find yourself writing `.. "goto "` or `.. "(function()"` in the transpiler, add a new codegen function instead.

## JS Subset

### Supported

Variables (`let`/`const`; `var` normalized to `let`), functions, arrow functions (expression bodies desugared to `BlockStatement` wrapping `ReturnStatement`), objects, arrays, arithmetic (`+` `-` `*` `/` `%`), exponentiation (`**`, right-associative), strict equality (`===`/`!==`; `==` rejected at tokenizer level), comparison (`<` `>` `<=` `>=`), logical (`&&` `||`), ternary (`? :`), assignment (`=`), compound assignment (`+=` `-=` `*=` `/=` `%=` `**=`), unary (`!` `-` `+` `~`), update (`++`/`--`, prefix and postfix), hex literals (`0xFF`, `0X1A`), `if`/`else`, `while`, `do...while`, `for...of`, `for...in`, `for(;;)` (C-style for with optional init/test/update), `switch`/`case`/`default`/`break`, `continue`, `throw`, `try`/`catch`, `return`, `console.log` (parsed as regular `CallExpression` with `MemberExpression` callee).

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

## Codegen API (`ljs_codegen.lua`)

The codegen library provides pure string-building functions for Lua syntax. It has zero knowledge of JavaScript or ASTs. Every function takes string arguments and returns a formatted Lua source string. The module is returned as `cg`.

### Utilities

| Function | Returns |
|----------|---------|
| `cg.escape_string(s)` | Escaped string (without surrounding quotes) |
| `cg.pad(n)` | Indentation whitespace (2 spaces per level) |

### Statement builders

Produce indented output with trailing `\n`. All take an `indent` parameter.

| Function | Signature | Produces |
|----------|-----------|----------|
| `cg.local_decl` | `(name, init, indent)` | `local name = init\n` or `local name\n` |
| `cg.local_fn` | `(name, params, body, indent)` | `local function name(params)\nbody\nend\n` |
| `cg.fn_expr` | `(params, body, indent)` | `function(params)\nbody\nend` (no trailing `\n`) |
| `cg.return_stmt` | `(expr, indent)` | `return expr\n` or `return\n` |
| `cg.break_stmt` | `(indent)` | `break\n` |
| `cg.expr_stmt` | `(expr, indent)` | `expr\n` with indent |
| `cg.while_stmt` | `(test, body, indent)` | `while test do\nbody\nend\n` |
| `cg.for_in_stmt` | `(vars, iter, body, indent)` | `for vars in iter do\nbody\nend\n` |
| `cg.numeric_for` | `(var, start, stop, body, indent)` | `for var = start, stop do\nbody\nend\n` |
| `cg.if_stmt` | `(test, then, elseifs, else, indent)` | Full if/elseif/else/end |
| `cg.goto_stmt` | `(label, indent)` | `goto label\n` |
| `cg.label` | `(name, indent)` | `::name::\n` |

### Expression builders

No indentation, no trailing newlines. Pure expression strings.

| Function | Signature | Produces |
|----------|-----------|----------|
| `cg.number` | `(n)` | `tostring(n)` |
| `cg.string` | `(s)` | `"escaped"` |
| `cg.boolean` | `(b)` | `"true"` or `"false"` |
| `cg.nil_val` | `()` | `"nil"` |
| `cg.ident` | `(name)` | name as-is |
| `cg.binop` | `(op, left, right)` | `left op right` |
| `cg.unop` | `(op, expr)` | `not expr` or `op..expr` |
| `cg.call` | `(fn_expr, args)` | `fn_expr(arg1, arg2)` |
| `cg.member_dot` | `(obj, prop)` | `obj.prop` |
| `cg.member_index` | `(obj, index)` | `obj[index]` |
| `cg.object` | `(fields)` | `{key = val, ...}` |
| `cg.array` | `(elems)` | `{e1, e2, ...}` |

### Inline statement builders

Single-line, no trailing newlines. Used inside IIFE bodies where statements are joined with `; `.

| Function | Signature | Produces |
|----------|-----------|----------|
| `cg.local_inline` | `(name, init)` | `local name = init` |
| `cg.return_inline` | `(expr)` | `return expr` |
| `cg.inline_if_return` | `(test, cons, alt)` | `if test then return cons else return alt end` |

### Compound builders

| Function | Signature | Produces |
|----------|-----------|----------|
| `cg.iife` | `(stmts)` | `(function() s1; s2; ... end)()` |

## Conventions

- Lua 5.1+ compatible, 2-space indents, snake_case internals
- No external dependencies
- Strict parsing: fails on first error, no recovery
- Tests: `lua test_ljs_parser.lua`, `lua test_ljs_transpile.lua`, `lua test_ljs_codegen.lua` (exit code 0 = all pass)
- **Keep it simple.** This is a small library — don't over-engineer, don't add abstractions, don't split files. Just read the code, understand it, and make the change.

## Adding a new JS feature — checklist

Every new JS language feature touches a predictable set of files. Follow this in order:

1. **`ljs_parser.lua`** — add tokenizer support (new token type or keyword) and/or parser rule (new AST node type or field). Update the `JS Subset > Supported` section above if it's a new construct.
2. **`docs/AST.md`** — add or update the node reference. Every node type, field, and edge case must be documented. If you added a node type, add a new section. If you changed fields, update the table.
3. **`test_ljs_parser.lua`** — add tests for the new syntax: valid parses (check AST structure), error cases (rejected syntax), and edge cases.
4. **`ljs_codegen.lua`** — only if the feature needs a new *Lua syntax construct* that doesn't exist yet (e.g. `repeat...until` for `do...while`). Most features won't need this — the existing builders cover standard Lua patterns. If you add a builder, add tests in `test_ljs_codegen.lua`.
5. **`ljs_transpile.lua`** — add a `gen.NodeType` handler that maps the JS AST to Lua source using `cg.*` calls. **Never use raw string concatenation to produce Lua syntax** — if codegen doesn't have the right builder, add one (step 4). If the feature needs a runtime helper (like `_ljs_add`), add it to `HELPERS` and register detection in `analyze_node`. If it's a new builtin (like `console.log`), add to `BUILTINS`.
6. **`test_ljs_transpile.lua`** — add unit tests (source → expected Lua) and integration tests (transpile + run the Lua and check output). Test edge cases: empty variants, nesting, interactions with other features.
7. **Run all tests** — `lua test_ljs_parser.lua && lua test_ljs_transpile.lua && lua test_ljs_codegen.lua`

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

- Source location tracking in AST nodes
- More operators (nullish coalescing `??`)
