# ljs - Lua JS Parser

Single-file Lua library that parses a well-defined subset of JavaScript into a Lua table-based AST.

**Status**: Parser complete. Transpilation to Lua is planned.

## Files

```
ljs/
├── ljs.lua        # Parser library (single file, no deps)
├── ljsdump.lua    # CLI: reads JS, prints AST as JSON
├── test_ljs.lua   # Test suite (run with `lua test_ljs.lua`)
├── examples/      # Example JS programs in the supported subset
├── docs/
│   └── AST.md     # Full AST node reference
└── AGENTS.md      # This file
```

## JS Subset

### Supported

Variables (`let`/`const`; `var` normalized to `let`), functions, arrow functions (expression bodies desugared to `BlockStatement`), objects, arrays, arithmetic (`+` `-` `*` `/` `%`), strict equality (`===`/`!==`; `==` rejected at tokenizer level), comparison (`<` `>` `<=` `>=`), logical (`&&` `||`), assignment (`=`), unary (`!` `-`), `if`/`else`, `while`, `for...of`, `throw`, `try`/`catch`, `return`, `console.log` (parsed as regular `CallExpression` with `MemberExpression` callee).

### Rejected (parse error)

`this`, `async`/`await`, `typeof`, `instanceof`, `==`, regex literals, Promises.

## Parser API

```lua
local ljs = require("ljs")

local ast, err = ljs.parse("let x = 42;")
-- ast = {type="Program", body={...}}, err = nil

local ast, err = ljs.parse("this.x")
-- ast = nil, err = "parse error: 'this' is not supported at line 1"
```

Also exposes `ljs.tokenize(source)`, `ljs.parse_tokens(tokens)`, and `ljs.TOKEN` for testing.

## AST

All nodes are Lua tables with a `type` string field. See **docs/AST.md** for the full reference with fields, types, and examples for every node.

## Conventions

- Lua 5.1+ compatible, 2-space indents, snake_case internals
- No external dependencies
- Strict parsing: fails on first error, no recovery
- Tests: `lua test_ljs.lua` (exit code 0 = all pass)

## Future Work

- Transformation layer (JS AST → Lua source)
- Source location tracking in AST nodes
- More operators (ternary `?:`, nullish coalescing `??`)
