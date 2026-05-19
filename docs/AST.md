# ljs_parser AST Reference

Every AST node is a Lua table with a `type` string field. This document covers every node type, its fields, and the JavaScript source that produces it.

## Root

### Program

The top-level node returned by `parser.parse()`.

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"Program"` | |
| `body` | `table[]` | Array of statement nodes |

**Source:** any JS input  
**Example:**
```js
let x = 1; x;
```
```lua
{
  type = "Program",
  body = {
    { type = "VariableDeclaration", ... },
    { type = "ExpressionStatement", ... },
  }
}
```

---

## Literals

### NumberLiteral

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"NumberLiteral"` | |
| `value` | `number` | Integer or float |

**Source:** `42`, `3.14`, `0`

### StringLiteral

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"StringLiteral"` | |
| `value` | `string` | Unescaped string content |

**Source:** `"hello"`, `'world'`  
Escape sequences (`\n`, `\t`, `\\`, etc.) are resolved during tokenization.

### BooleanLiteral

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"BooleanLiteral"` | |
| `value` | `boolean` | `true` or `false` |

**Source:** `true`, `false`

### NullLiteral

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"NullLiteral"` | |

**Source:** `null`

### UndefinedLiteral

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"UndefinedLiteral"` | |

**Source:** `undefined`

---

## Identifiers

### Identifier

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"Identifier"` | |
| `name` | `string` | Variable/parameter name |

**Source:** any identifier (`x`, `myVar`, `_foo`)

---

## Declarations

### VariableDeclaration

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"VariableDeclaration"` | |
| `kind` | `string` | `"let"` or `"const"` |
| `declarations` | `VariableDeclarator[]` | One or more declarators |

`var` is normalized to `"let"`.

**Source:** `let x = 1;`, `const y = 2, z = 3;`, `var v = 4;`

### VariableDeclarator

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"VariableDeclarator"` | |
| `name` | `Identifier` | The variable name |
| `init` | `node?` | Initializer expression, or `nil` |

**Source:** `let x;` (init is nil), `let x = 42;`

---

## Functions

### FunctionDeclaration

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"FunctionDeclaration"` | |
| `name` | `string` | Function name |
| `params` | `Identifier[]` | Parameter list |
| `body` | `BlockStatement` | Function body |

**Source:** `function add(a, b) { return a + b; }`

### FunctionExpression

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"FunctionExpression"` | |
| `name` | `string?` | Name (present for named expressions like `function fact(n) {...}`), absent for anonymous |
| `params` | `Identifier[]` | Parameter list |
| `body` | `BlockStatement` | Function body |

**Source:** `function(x) { return x; }` (anonymous), `function fact(n) { return n; }` (named)

### ArrowFunctionExpression

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"ArrowFunctionExpression"` | |
| `params` | `Identifier[]` | Parameter list |
| `body` | `BlockStatement` | Always a BlockStatement |

Expression bodies are desugared: `x => x + 1` becomes a `BlockStatement` containing a single `ReturnStatement`.

**Source:** `x => x + 1`, `(a, b) => a + b`, `(x) => { return x; }`

---

## Expressions

### BinaryExpression

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"BinaryExpression"` | |
| `operator` | `string` | One of the operators below |
| `left` | `node` | Left operand |
| `right` | `node` | Right operand |

**Operators by precedence (highest to lowest):**

| Precedence | Operators | Associativity |
|-----------|-----------|--------------|
| 5 | `*` `/` `%` | Left |
| 4 | `+` `-` | Left |
| 3 | `===` `!==` `<` `>` `<=` `>=` | Left |
| 2 | `&&` | Left |
| 1 | `\|\|` | Left |
| 0.75 | `? :` (ternary) | Right |
| 0.5 | `=` `+=` `-=` `*=` `/=` `%=` | Right |

Assignment (`=`) and compound assignment operators are right-associative: `a = b = c` parses as `a = (b = c)`; `x += y += 1` parses as `x += (y += 1)`.  
All other binary operators are left-associative: `1 + 2 + 3` parses as `(1 + 2) + 3`.

### UnaryExpression

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"UnaryExpression"` | |
| `operator` | `string` | `"!"`, `"-"`, or `"+"` |
| `argument` | `node` | The operand |

Unary operators have the highest precedence (6) and are right-recursive: `!!x` parses as `!(!(x))`.

**Source:** `!x`, `-y`, `+z`, `!!flag`, `+"5"`

### UpdateExpression

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"UpdateExpression"` | |
| `operator` | `string` | `"++"` or `"--"` |
| `argument` | `node` | The operand (Identifier or MemberExpression) |
| `prefix` | `boolean` | `true` for prefix (`++x`), `false` for postfix (`x++`) |

Postfix has the highest precedence (applied during primary expression parsing). Prefix has the same precedence as unary operators (6). Both are right-recursive for prefix: `++ ++ x` parses as `++(++x)`.

Postfix is only valid after identifiers and member/call chains: `x++`, `a.b++`, `a[b]++`, `f()++`. It does not apply to literals or parenthesized expressions: `5++`, `(x)++` are parse errors.

**Source:** `++x`, `x++`, `--y`, `y--`, `a.b++`, `++obj[prop]`, `i++` in for-loop update

### ConditionalExpression

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"ConditionalExpression"` | |
| `test` | `node` | Condition expression |
| `consequent` | `node` | Expression if truthy |
| `alternate` | `node` | Expression if falsy |

The ternary operator `? :` has precedence 0.75 (between `\|\|` and assignment) and is right-associative: `a ? b : c ? d : e` parses as `a ? b : (c ? d : e)`.

Both branches allow full expressions including assignment and nested ternaries. The `:` delimiter naturally ends the consequent expression.

**Source:** `x ? 1 : 0`, `a ? b ? 1 : 2 : 3`, `let x = flag ? "yes" : "no"`, `a || b ? 1 : 0`

### CallExpression

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"CallExpression"` | |
| `callee` | `node` | Expression being called |
| `arguments` | `node[]` | Argument list (can be empty) |

**Source:** `f()`, `f(a, b)`, `console.log("hello")`

`console.log` is not a special node — it parses as a `CallExpression` whose `callee` is a `MemberExpression`.

### MemberExpression

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"MemberExpression"` | |
| `object` | `node` | The object being accessed |
| `property` | `node` | The property name or computed expression |
| `computed` | `boolean` | `false` for dot notation, `true` for bracket notation |

**Source:** `obj.prop` (computed=false), `obj[key]` (computed=true)

Member access chains are left-nested: `a.b.c` parses as `(a.b).c`.

### ExpressionStatement

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"ExpressionStatement"` | |
| `expression` | `node` | The expression being evaluated |

Wraps any expression used as a statement. Semicolons are optional.

**Source:** `42;`, `f();`, `obj.prop;`

---

## Objects and Arrays

### ObjectExpression

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"ObjectExpression"` | |
| `properties` | `Property[]` | Property list (can be empty) |

**Source:** `{}`, `{a: 1, b: 2}`

### Property

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"Property"` | |
| `key` | `Identifier` or `StringLiteral` | Property key |
| `value` | `node` | Property value expression |
| `computed` | `boolean` | Always `false` in the current parser |

**Source:** `{a: 1}` (key is Identifier), `{"key": 2}` (key is StringLiteral)

### ArrayExpression

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"ArrayExpression"` | |
| `elements` | `node[]` | Element list (can be empty) |

**Source:** `[]`, `[1, 2, 3]`

---

## Control Flow

### IfStatement

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"IfStatement"` | |
| `test` | `node` | Condition expression |
| `consequent` | `node` | Statement to run if truthy |
| `alternate` | `node?` | Else branch, or `nil` |

**Source:** `if (x) { y; }`, `if (x) { y; } else { z; }`

### WhileStatement

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"WhileStatement"` | |
| `test` | `node` | Condition expression |
| `body` | `node` | Statement to repeat |

**Source:** `while (x) { y; }`

### DoWhileStatement

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"DoWhileStatement"` | |
| `body` | `node` | Statement to repeat (executes at least once) |
| `test` | `node` | Condition expression (checked after body) |

**Source:** `do { y; } while (x);`

### ForOfStatement

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"ForOfStatement"` | |
| `left` | `VariableDeclaration` or `node` | Loop variable (declaration or expression) |
| `right` | `node` | Iterable expression |
| `body` | `node` | Statement to repeat |

**Source:** `for (let x of arr) { console.log(x); }`

### ForInStatement

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"ForInStatement"` | |
| `left` | `VariableDeclaration` or `node` | Loop variable (declaration or expression) |
| `right` | `node` | Object expression to iterate keys of |
| `body` | `node` | Statement to repeat |

**Source:** `for (let key in obj) { console.log(key); }`

The left-hand side must be a single variable with no initializer (matching JS semantics). Multiple declarators or initializers produce a parse error.

### ForStatement

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"ForStatement"` | |
| `init` | `VariableDeclaration` or `ExpressionStatement` or `nil` | Initialization (declaration or expression), or nil |
| `test` | `node` or `nil` | Loop condition, or nil (infinite) |
| `update` | `node` or `nil` | Update expression, or nil |
| `body` | `node` | Statement to repeat |

**Source:** `for (let i = 0; i < 10; i = i + 1) { ... }`, `for (;;) { ... }`, `for (; x < 5; ) { ... }`

All three clauses (`init`, `test`, `update`) can be nil independently. When `init` is a `VariableDeclaration`, its semicolon serves as the first separator. When `init` is an expression, the separator is an `ExpressionStatement` wrapper.

### BlockStatement

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"BlockStatement"` | |
| `body` | `node[]` | Array of statements (can be empty) |

**Source:** `{ x; y; }`

---

### SwitchStatement

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"SwitchStatement"` | |
| `discriminant` | `node` | Expression to match against |
| `cases` | `SwitchCase[]` | Array of case clauses (can be empty) |

**Source:** `switch (x) { case 1: break; default: y; }`

### SwitchCase

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"SwitchCase"` | |
| `test` | `node?` | Test expression for `case`, or `nil` for `default` |
| `consequent` | `node[]` | Array of statements (can be empty for fallthrough) |

**Source:** `case 1: break;` (test is NumberLiteral), `default: y;` (test is nil)

### BreakStatement

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"BreakStatement"` | |

**Source:** `break;`

---

## Exception Handling

### ThrowStatement

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"ThrowStatement"` | |
| `argument` | `node` | The value to throw |

**Source:** `throw "error";`

### TryStatement

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"TryStatement"` | |
| `block` | `BlockStatement` | The try body |
| `handler` | `CatchClause?` | Catch handler, or `nil` |

**Source:** `try { x; } catch (e) { y; }`

### CatchClause

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"CatchClause"` | |
| `param` | `Identifier` | The caught error variable |
| `body` | `BlockStatement` | Catch body |

**Source:** `catch (e) { y; }`

---

## Return

### ReturnStatement

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"ReturnStatement"` | |
| `argument` | `node?` | Return value, or `nil` for bare `return` |

**Source:** `return x;`, `return;`

---

## Full Example

**JavaScript:**
```js
let double = (x) => x * 2;
console.log(double(5));
```

**AST:**
```lua
{
  type = "Program",
  body = {
    {
      type = "VariableDeclaration",
      kind = "let",
      declarations = {
        {
          type = "VariableDeclarator",
          name = { type = "Identifier", name = "double" },
          init = {
            type = "ArrowFunctionExpression",
            params = {
              { type = "Identifier", name = "x" }
            },
            body = {
              type = "BlockStatement",
              body = {
                {
                  type = "ReturnStatement",
                  argument = {
                    type = "BinaryExpression",
                    operator = "*",
                    left = { type = "Identifier", name = "x" },
                    right = { type = "NumberLiteral", value = 2 }
                  }
                }
              }
            }
          }
        }
      }
    },
    {
      type = "ExpressionStatement",
      expression = {
        type = "CallExpression",
        callee = {
          type = "MemberExpression",
          object = { type = "Identifier", name = "console" },
          property = { type = "Identifier", name = "log" },
          computed = false
        },
        arguments = {
          {
            type = "CallExpression",
            callee = { type = "Identifier", name = "double" },
            arguments = {
              { type = "NumberLiteral", value = 5 }
            }
          }
        }
      }
    }
  }
}
```
