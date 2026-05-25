# ljs

![CI](https://github.com/podikoglou/ljs/actions/workflows/ci.yml/badge.svg?branch=develop)
![tests](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/podikoglou/b09d93dbfcbd7570565f5702d4f57412/raw/tests.json)

Parse and transpile a well-defined subset of JavaScript into Lua. No external dependencies, Lua 5.2+.

```lua
local ljs = require("ljs")

-- parse
local ast = ljs.parse("let x = 1 + 2;")

-- transpile to lua
local code = ljs.transpile("let x = 1 + 2;")

-- run directly
ljs.run("console.log('hello')")
-- → prints "hello"

ljs.run("[1,2,3].map(x => x * 2)")
-- → doesn't work, but:
ljs.run("1 + 2")
-- → 3
```

## Install

```sh
luarocks install ljs
```

Or from source:

```sh
git clone https://github.com/podikoglou/ljs.git
cd ljs && make install
```

## API

```lua
local ljs = require("ljs")

-- tokenize
local tokens, err = ljs.tokenize("let x = 42;")

-- parse to AST
local ast, err = ljs.parse("let x = 42;")

-- transpile to lua source
local code, err = ljs.transpile("let x = 42;")

-- compile to callable lua function
local fn, err = ljs.load("function add(a,b) { return a + b; }; add")
local add = fn()
print(add(3, 4))  -- → 7

-- transpile + execute
local result = ljs.run("let x = 5; x * 2")  -- → 10
```

Lower-level modules available for advanced use:

```lua
local parser    = require("ljs.parser")
local codegen   = require("ljs.codegen")
local transpile = require("ljs.transpile")
```

## JS subset

**Variables:** `let`, `const`, `var`

**Types:** numbers, strings, booleans, `null`, `undefined`, objects, arrays

**Operators:** arithmetic, comparison, logical, bitwise (`& | ^ << >> >>>`), ternary, `in`, `instanceof`, `typeof`, `delete`, `new`, compound assignment, update (`++`/`--`)

**Control flow:** `if`/`else`, `while`, `do...while`, `for`, `for...in`, `for...of`, `switch`/`case`, `break`, `continue`, `return`, `throw`, `try`/`catch`

**Functions:** declarations, expressions, arrow functions, `this` with correct lexical binding, rest parameters, default parameters

**OOP:** `class` with `extends`, `super()`, `super.method()`, `static` methods, constructors, prototype chain, `Object.create`, `Object.prototype.toString`/`hasOwnProperty`/`valueOf`, `Array.prototype.push`/`pop`, `Function.prototype.call`/`apply`

**Built-ins:** `console.log`, `typeof`, `instanceof`, `delete`

## Error handling

All functions return `result, err`. Check `err ~= nil` for failures.

```lua
local ast, err = ljs.parse("let = bad;")
if err then
  print(ljs.format_error(err, source))
end
-- Expected identifier, got '=' at line 1, col 5
--   let = bad;
--        ^
```

## CLI tools

```sh
# dump AST as JSON
lua src/ljs/parser_dump.lua file.js

# dump transpiled lua
lua src/ljs/transpile_dump.lua file.js
```

## Development

```sh
make test    # run tests
make lint    # lua-language-server check
make rock    # local luarocks install
make pack    # create .rock file
```

## License

MIT
