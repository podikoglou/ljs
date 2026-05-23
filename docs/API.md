# Public API

Single entry point: `require("ljs")` returns a table with all public functions.

Lower-level modules (`ljs.parser`, `ljs.transpile`, `ljs.codegen`) remain
directly requireable for advanced use (pre-parsing, AST manipulation).

```lua
local ljs = require("ljs")
```

---

## Parse

### `ljs.parse(source)`

Parse JavaScript source into an AST.

```lua
local ast, err = ljs.parse("let x = 42; console.log(x);")
if not ast then
  print("parse error: " .. err)
end
-- ast = { type = "Program", body = { ... } }
```

**Parameters:**
- `source` (`string`) — JavaScript source code

**Returns:**
- `ast` (`table|nil`) — AST root node (Program), or `nil` on failure
- `err` (`string|nil`) — error message, or `nil` on success

---

### `ljs.parse_tokens(tokens)`

Parse a pre-built token array into an AST (bypasses the tokenizer).

```lua
local tokens = ljs.tokenize("let x = 1;")
local ast, err = ljs.parse_tokens(tokens)
```

**Parameters:**
- `tokens` (`table`) — array of `{ type, value?, line, col }` token tables

**Returns:**
- `ast` (`table|nil`)
- `err` (`string|nil`)

---

### `ljs.tokenize(source)`

Tokenize JavaScript source (low-level).

```lua
local tokens, err = ljs.tokenize("let x = 1;")
-- tokens = {
--   { type = "let", line = 1, col = 1 },
--   { type = "Identifier", value = "x", line = 1, col = 5 },
--   ...
-- }
```

**Parameters:**
- `source` (`string`) — JavaScript source code

**Returns:**
- `tokens` (`table|nil`) — array of token tables, or `nil` on failure
- `err` (`string|nil`)

---

## Transpile

Transpile functions produce Lua source code. The default mode is `"script"` —
no implicit returns, suitable for scripts with side effects.

### `ljs.transpile(source)`

Transpile JavaScript source to Lua source code (script mode).

```lua
local code, err = ljs.transpile("let x = 42; console.log(x);")
if not code then
  print("transpile error: " .. err)
end
-- code = "-- ljs runtime...\nlocal _ljs_arrow_this = nil\n..."
```

**Parameters:**
- `source` (`string`) — JavaScript source code

**Returns:**
- `code` (`string|nil`) — Lua source code, or `nil` on failure
- `err` (`string|nil`)

---

### `ljs.transpile_ast(ast)`

Transpile an AST directly to Lua source code. Use after `ljs.parse()` when
you need to inspect or modify the AST before transpilation.

```lua
local ast = ljs.parse("let x = 42;")
-- ... modify ast ...
local code = ljs.transpile_ast(ast)
```

**Parameters:**
- `ast` (`table`) — AST root node (Program)

**Returns:**
- `code` (`string`) — Lua source code

---

## Execute

Execute functions use **eval mode**: if the last statement in the program is
an ExpressionStatement, its value is implicitly returned. This matches the
completion-value semantics of JavaScript's `eval()`.

### `ljs.run(source)`

Transpile, compile, and execute JavaScript code. Returns the completion value.

```lua
-- Expression evaluation
local n = ljs.run("1 + 2")           -- → 3

-- Side-effect scripts
ljs.run("console.log('hello')")      -- prints "hello" to stdout

-- Multi-statement: last expression is returned
local n = ljs.run("let x = 5; x * 2")  -- → 10

-- Last statement is not an expression: returns nil
local r = ljs.run("let x = 5;")      -- → nil
```

**Parameters:**
- `source` (`string`) — JavaScript source code

**Returns:**
- `result` (`any`) — completion value of the script
- `err` (`nil|string`) — `nil` on success, error message on failure

---

### `ljs.load(source)`

Transpile JavaScript source and compile it into a callable Lua function.
Does **not** execute — returns the function for later use.

```lua
-- Compile an expression to a reusable function
local fn = ljs.load("1 + 2")
print(fn())  -- → 3

-- Compile a function definition
local fn = ljs.load("function add(a, b) { return a + b; }; add")
local add = fn()
print(add(3, 4))  -- → 7
```

**Parameters:**
- `source` (`string`) — JavaScript source code

**Returns:**
- `fn` (`function|nil`) — callable Lua function, or `nil` on failure
- `err` (`string|nil`)

**Note:** The compiled function includes all runtime helpers. Call it as many
times as needed — each call is a fresh execution of the script.

---

## Modes: script vs eval

| Mode | Implicit returns | Used by |
|---|---|---|
| `"script"` | None — executes for side effects | `transpile()`, `transpile_ast()` |
| `"eval"` | Last ExpressionStatement gets `return` | `run()`, `load()` |

The mode determines how the final expression statement is emitted. In script
mode, `1 + 2` transpiles to `_ljs_add(1, 2)` (discarded). In eval mode, it
transpiles to `return _ljs_add(1, 2)` (returned as completion value).

For advanced use, eval mode can be used directly through the lower-level
transpiler:

```lua
local transpiler = require("ljs.transpile")
local code = transpiler.transpile(ast, { mode = "eval" })
```

---

## Error handling

All public functions that can fail follow the same convention:
`result, err` — check `err ~= nil` to detect failures.

```lua
local result, err = ljs.run(source)
if err then
  print("error: " .. err)
  return
end
-- use result safely
```

Note that `nil` is a valid result (e.g. `ljs.run("let x = 5;")` → `nil, nil`).
`result = nil, err = nil` means "success, no value". Only `err ~= nil` means
failure.
