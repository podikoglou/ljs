# ljs Transpiler — Product Requirements Document

## Overview

JS → Lua transpiler that converts the parser's AST output into idiomatic Lua source code. Second major component of the ljs toolkit, after the parser.

## Goals

- Single-file transpiler library (`ljs_transpile.lua`), no external dependencies, Lua 5.1+ compatible
- Clean, readable Lua output that a Lua developer would write by hand
- CLI tool to transpile JS files to Lua (similar to `ljs_parser_dump.lua`)
- Test suite covering individual node types and full example programs

## Non-Goals (this phase)

- Runtime JS-in-Lua library (future phase)
- Type inference or type-directed translation
- Source map generation
- Optimization passes (dead code, constant folding)
- Full JS semantic fidelity (truthiness, `%` with negatives, const enforcement)

## Architecture

### Two-Pass Design

**Pass 1 — Analysis.** Walks the AST, collects:

- Scope information: tracks variable declarations per scope to detect shadowing of globals (e.g., `console`)
- Needed helpers: which runtime helpers are required based on AST node types present

Returns a metadata table, does not emit code.

**Pass 2 — Code Generation.** Walks the AST with metadata from Pass 1:

1. Emits needed runtime helper definitions at the top of output
2. Emits transpiled Lua code for each AST node

Clear boundary between passes — no mixing of analysis and emission.

### File Organization

Single file with distinct sections:

```
Section 1: Module header and locals
Section 2: Helper definitions (HELPERS registry)
Section 3: Pass 1 — Analysis (scope tracker, helper detection)
Section 4: Pass 2 — Code generation (recursive AST walk, Lua emission)
Section 5: Public API (transpile, transpile_source)
Section 6: Module return
```

### Runtime Helper System

Helpers are registered in a `HELPERS` table mapping name → Lua source string. Pass 1 flags needed helpers into a set. Pass 2 emits only flagged helpers at the top of output.

Properties:

- Set-based deduplication — flagging the same helper multiple times has no effect
- Extensible — adding a helper is one table entry + flag in Pass 1
- Zero cost if unused — helpers only emitted when flagged
- Order-independent — current helpers have no interdependencies

### Scope Tracking

Maintained as a stack of scope tables during Pass 1:

- Push on block entry (BlockStatement, function bodies, ForOfStatement, CatchClause)
- Pop on exit
- Record variable names declared in each scope (VariableDeclaration, FunctionDeclaration, params)
- Used to detect when `console` has been shadowed by a local declaration

## Semantic Mappings

### Operators

| JS | Lua | Notes |
|----|-----|-------|
| `+` | `_ljs_add(a, b)` | Runtime helper — dispatches to `..` for strings, `+` for numbers |
| `===` / `!==` | `==` / `~=` | Direct mapping |
| `<` `>` `<=` `>=` | same | Direct mapping |
| `&&` / `\|\|` | `and` / `or` | Same short-circuit-return-operand semantics |
| `!` | `not` | Direct mapping |
| `-` (unary) | `-` | Direct mapping |
| `=` (assignment) | `=` | Direct mapping |

### Literals

| JS | Lua | Notes |
|----|-----|-------|
| `42`, `3.14` | `42`, `3.14` | Direct |
| `"hello"` | `"hello"` | Re-escaped for Lua quoting |
| `true` / `false` | `true` / `false` | Direct |
| `null` | `nil` | Direct |

### Declarations

| JS | Lua | Notes |
|----|-----|-------|
| `let x = 1;` | `local x = 1` | `const` also maps to `local` |
| `let x;` | `local x` | Uninitialized |
| `let a = 1, b = 2;` | `local a = 1`<br>`local b = 2` | One declarator per line |

### Functions

| JS | Lua | Notes |
|----|-----|-------|
| `function foo(a, b) { ... }` | `local function foo(a, b) ... end` | Declaration |
| `function(x) { ... }` | `function(x) ... end` | Anonymous expression |
| `x => x + 1` | `function(x) return x + 1 end` | Arrow (desugared body) |

### Control Flow

| JS | Lua | Notes |
|----|-----|-------|
| `if (x) { a; }` | `if x then a end` | |
| `if/else` | `if/else` or `if/elseif` | Flatten `else { if }` to `elseif` when pattern matches |
| `while (x) { ... }` | `while x do ... end` | |
| `for (const x of arr) { ... }` | `for _, x in ipairs(arr) do ... end` | Loop variable implicitly local |
| `{ stmts }` | body with indent | BlockStatement emits body statements |

### Objects and Arrays

| JS | Lua | Notes |
|----|-----|-------|
| `{a: 1, b: 2}` | `{a = 1, b = 2}` | Identifier keys |
| `{"key": 1}` | `{["key"] = 1}` | StringLiteral keys |
| `[1, 2, 3]` | `{1, 2, 3}` | Direct |
| `obj.prop` | `obj.prop` | Dot access |
| `obj[key]` | `obj[(key) + 1]` | Computed: always offset by +1 for 0→1 index conversion |
| `obj["str"]` | `obj["str"]` | Computed string key: no offset |

### Exception Handling

| JS | Lua | Notes |
|----|-----|-------|
| `throw expr` | `error(expr, 0)` | Level 0 skips position prefix |
| `try { ... } catch(e) { ... }` | `local ok, e = pcall(function() ... end)`<br>`if not ok then ... end` | |

### Console

| JS | Lua | Notes |
|----|-----|-------|
| `console.log(x)` | `_ljs_log(x)` | Helper, only when `console` not shadowed |
| `console.log(...)` (shadowed) | `console.log(...)` | Normal member call if `console` is a local |

## Runtime Helpers

### `_ljs_add(a, b)`

Polymorphic `+` operator. Concatenates if either operand is a string, adds otherwise.

```lua
local function _ljs_add(a, b)
  if type(a) == "string" or type(b) == "string" then
    return tostring(a) .. tostring(b)
  end
  return a + b
end
```

Flagged when: any `BinaryExpression` with `operator = "+"` is present.

### `_ljs_log(...)`

Console output. Wraps `print()`.

```lua
local function _ljs_log(...)
  print(...)
end
```

Flagged when: `CallExpression` whose callee is `MemberExpression` on unshadowed `console` with property `log`.

## Accepted Semantic Mismatches

These JS behaviors differ from the Lua output. Accepted as part of the "idiomatic Lua" approach:

- **Truthiness**: `0`, `""` are falsy in JS but truthy in Lua. Conditions using comparison operators (the common case) are unaffected.
- **Modulo with negatives**: `-7 % 3` is `-1` in JS, `2` in Lua. No helper planned.
- **Const enforcement**: `const` maps to `local` with no reassignment protection.
- **Array identity**: No runtime wrapper — arrays are plain Lua tables with 1-based indexing. Manual index arithmetic that mixes counters with bracket access may produce incorrect results if not written with 1-based indexing in mind.

## File Layout

```
ljs_transpile.lua         # Transpiler library
ljs_transpile_dump.lua    # CLI: reads JS, prints Lua source
test_ljs_transpile.lua    # Test suite
```

Follows naming conventions of existing `ljs_parser.lua`, `ljs_parser_dump.lua`, `test_ljs_parser.lua`.

## Public API

```lua
local transpile = require("ljs_transpile")

-- Core: AST → Lua source string
local lua_code, err = transpile.transpile(ast)
-- lua_code = "local x = 42\nprint(x)\n", err = nil

-- Convenience: JS source → Lua source (parse + transpile)
local lua_code, err = transpile.transpile_source("let x = 42; console.log(x);")

-- Helper registry (for inspection/extensibility)
transpile.HELPERS  -- { _ljs_add = "...", _ljs_log = "..." }
```

## CLI Tool

`ljs_transpile_dump.lua` — reads JS from file argument or stdin, writes Lua source to stdout.

```
$ lua ljs_transpile_dump.lua examples/01_fibonacci.js
$ cat examples/01_fibonacci.js | lua ljs_transpile_dump.lua
```

## Testing Strategy

### Unit Tests

Test individual node type emissions with exact string matching. Quick, catches output regressions.

```lua
test("NumberLiteral emits as-is", function()
  local ast = { type = "Program", body = {
    { type = "ExpressionStatement", expression = { type = "NumberLiteral", value = 42 } }
  }}
  local code = assert_transpile_ok(ast)
  assert(code == "42\n", "expected '42\\n', got: " .. code)
end)
```

### Integration Tests

Transpile full example programs → run the Lua output → capture stdout → compare to expected output. Tests behavior, not formatting.

```lua
test("fibonacci example produces correct output", function()
  local js = read_file("examples/01_fibonacci.js")
  local lua_code = assert_transpile_source_ok(js)
  local output = run_lua(lua_code)
  assert(output:find("fib(0) = 0"), "expected fib(0) = 0 in output")
end)
```

## Example Output

**Input** (`examples/01_fibonacci.js`):
```js
const fib = (n) => {
  if (n <= 1) {
    return n;
  }
  return fib(n - 1) + fib(n - 2);
};
```

**Output**:
```lua
local function _ljs_add(a, b)
  if type(a) == "string" or type(b) == "string" then
    return tostring(a) .. tostring(b)
  end
  return a + b
end

local fib = function(n)
  if n <= 1 then
    return n
  end
  return _ljs_add(fib(n - 1), fib(n - 2))
end
```
