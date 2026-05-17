# ljs - Lua JS Parser

## Project Overview

**ljs** (Lua JS) is a single-file Lua library that parses a well-defined subset of JavaScript into a Lua table-based AST.

**Current Status**: Parser-only. Transformation/transpilation to Lua is planned for future work.

## Scope

### Included (Must Parse)

| Feature | Notes |
|--------|-------|
| Variables | `let`/`const` only; `var` ignored |
| Functions | Regular functions, closures |
| Arrow Functions | Desugared to regular functions in AST |
| Objects | As Lua tables; property access (`obj.prop`, `obj[prop]`) |
| Method Calls | `obj.method()` |
| Arrays | Parsed as tables; 1-indexed internally (boundary hidden later) |
| Arithmetic | `+`, `-`, `*`, `/` |
| Equality | `===` only (strict); `==` rejected |
| Control Flow | `if`/`else`, `while`, `for...of` (arrays only) |
| `console.log` | Recognized as special form |
| Exceptions | `throw`, `try`/`catch` (parsed; `pcall` mapping happens later) |

### Explicitly Excluded (Will Error or Ignore)

| Feature | Handling |
|--------|----------|
| `this` | Error |
| Prototypal inheritance | Flat objects only; `__proto__` ignored |
| `async`/`await` | Error |
| Promises | Error |
| `==` coercion | Error (use `===`) |
| `typeof`, `instanceof` | Error |
| Regex literals | Error |
| Standard library | Not parsed (except `console.log`) |
| `var` | Ignored (treated as `let`) |

## Implementation

### File Structure

```
ljs/
├── AGENTS.md          # This file
└── ljs.lua            # Single-file parser library
```

### AST Format

All nodes are Lua tables with a `type` string field.

```lua
-- Literals
{type = "NumberLiteral", value = 42}
{type = "StringLiteral", value = "hello"}
{type = "BooleanLiteral", value = true}
{type = "NullLiteral"}
{type = "Identifier", name = "x"}

-- Variables
{type = "VariableDeclaration", kind = "let" | "const", declarations = {{...}, ...}}
{type = "VariableDeclarator", name = "x", init = {...}}

-- Functions
{type = "FunctionDeclaration", name = "f", params = {{...}, ...}, body = {...}}
{type = "FunctionExpression", params = {{...}, ...}, body = {...}}
{type = "ArrowFunctionExpression", params = {{...}, ...}, body = {...}}
{type = "CallExpression", callee = {...}, arguments = {{...}, ...}}

-- Objects & Arrays
{type = "ObjectExpression", properties = {{...}, ...}}
{type = "Property", key = {...}, value = {...}, computed = true | false}
{type = "ArrayExpression", elements = {{...}, ...}}
{type = "MemberExpression", object = {...}, property = {...}, computed = true | false}

-- Expressions
{type = "BinaryExpression", operator = "+" | "-" | "*" | "/" | "===", left = {...}, right = {...}}
{type = "UnaryExpression", operator = "-" | "!", argument = {...}}

-- Control Flow
{type = "IfStatement", test = {...}, consequent = {...}, alternate = {...}}
{type = "WhileStatement", test = {...}, body = {...}}
{type = "ForOfStatement", left = {...}, right = {...}, body = {...}}
{type = "BlockStatement", body = {{...}, ...}}

-- Exception Handling
{type = "ThrowStatement", argument = {...}}
{type = "TryStatement", block = {...}, handler = {...}}
{type = "CatchClause", param = {...}, body = {...}}

-- Special Forms
{type = "CallExpression", callee = {type = "MemberExpression", ...}, ...}  -- console.log
```

### Parser Interface

```lua
local ljs = require("ljs")

-- Parse a JS source string into AST
local ast, err = ljs.parse(js_source)
-- Returns: AST table on success, nil + error string on failure
```

### Error Handling

- Strict parsing: fails on first syntax error
- Returns `nil, "parse error: <message> at line X"`
- No error recovery attempted

## Conventions

1. **Code Style**: Lua 5.1+ compatible, 2-space indents, snake_case for internal functions
2. **Documentation**: Every exported function has a Lua comment block
3. **Tests**: None yet (parser-only phase). Future: add test file
4. **Single File**: All code in `ljs.lua`. No external dependencies

## Future Work

1. Add `ljs.lua` - the parser implementation
2. Add transformation layer (JS AST → Lua AST → Lua source)
3. Add comprehensive tests
4. Consider source location tracking in AST
