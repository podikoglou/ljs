# ljs.parser AST Reference

Every AST node is a Lua table with a `type` string field. This document covers every node type, its fields, and the JavaScript source that produces it.

> **Location info:** Every node also has `line` (number, 1-based) and `col` (number, 1-based) fields representing the source position of the construct's first token. These are omitted from individual node tables below for brevity.

> **Compatibility:** Transpilation requires Lua 5.2+ (uses `goto` for `continue` statements).

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

**Source:** `42`, `3.14`, `0`, `0xFF`, `0X1A`

### StringLiteral

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"StringLiteral"` | |
| `value` | `string` | Unescaped string content |

**Source:** `"hello"`, `'world'`  
Escape sequences (`\n`, `\t`, `\\`, etc.) are resolved during tokenization.

### TemplateLiteral

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"TemplateLiteral"` | |
| `quasis` | `TemplateElement[]` | String segments (always one more than expressions) |
| `expressions` | `node[]` | Interpolated expressions |

**Source:** `` `hello` ``, `` `hello ${name}` ``, `` `${a} and ${b}` ``

Multi-line content is supported. Escape sequences follow the same rules as `StringLiteral`, plus `` \` `` for literal backticks and `\$` for literal dollar signs.

### TemplateElement

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"TemplateElement"` | |
| `value` | `string` | Unescaped text of this segment |
| `tail` | `boolean` | `true` if this is the final (closing) quasi |

**Example:** `` `hello ${world}!` `` produces:
```lua
{
  type = "TemplateLiteral",
  quasis = {
    { type = "TemplateElement", value = "hello ", tail = false },
    { type = "TemplateElement", value = "!", tail = true },
  },
  expressions = {
    { type = "Identifier", name = "world" }
  }
}
```

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

### ThisExpression

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"ThisExpression"` | |

**Source:** `this`

Represents the `this` keyword. Binds to the calling context at runtime: the receiver object in member calls, or undefined in direct calls.

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
| `name` | `Identifier \| ObjectPattern \| ArrayPattern` | The variable name or destructuring pattern |
| `init` | `node?` | Initializer expression, or `nil` |

**Source:** `let x;` (init is nil), `let x = 42;`, `let [a, b] = arr;`, `let {x, y} = obj;`

---

## Functions

### FunctionDeclaration

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"FunctionDeclaration"` | |
| `name` | `string` | Function name |
| `params` | `(Identifier | AssignmentPattern | RestElement)[]` | Parameter list |
| `body` | `BlockStatement` | Function body |

**Source:** `function add(a, b) { return a + b; }`

### FunctionExpression

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"FunctionExpression"` | |
| `name` | `string?` | Name (present for named expressions like `function fact(n) {...}`), absent for anonymous |
| `params` | `(Identifier | AssignmentPattern | RestElement)[]` | Parameter list |
| `body` | `BlockStatement` | Function body |
| `is_method` | `boolean?` | `true` when created by method shorthand `{ m() {} }` — skips `_ljs_ctor` wrapping |

**Source:** `function(x) { return x; }` (anonymous), `function fact(n) { return n; }` (named)

### ArrowFunctionExpression

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"ArrowFunctionExpression"` | |
| `params` | `(Identifier | AssignmentPattern | RestElement)[]` | Parameter list |
| `body` | `BlockStatement` | Always a BlockStatement |

Expression bodies are desugared: `x => x + 1` becomes a `BlockStatement` containing a single `ReturnStatement`.

**Source:** `x => x + 1`, `(a, b) => a + b`, `(x) => { return x; }`

### AssignmentPattern

Default parameter value.

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"AssignmentPattern"` | |
| `left` | `Identifier` | Parameter name |
| `right` | `node` | Default value expression |

**Source:** `function f(x = 10) {}`, `(s = "hi") => s`

### RestElement

Rest parameter (must be the last parameter).

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"RestElement"` | |
| `argument` | `Identifier` | Parameter name |

**Source:** `function f(...args) {}`, `(...rest) => rest`

### SpreadElement

Spread element in array literals or function call arguments.

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"SpreadElement"` | |
| `argument` | `node` | Expression to spread |

**Source:** `[...a]`, `fn(...args)`, `new F(...a)`

### ObjectPattern

Object destructuring pattern (used in variable declarations).

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"ObjectPattern"` | |
| `properties` | `(Property \| RestElement)[]` | Pattern properties |

Properties use the existing `Property` node with an additional `shorthand` field.
Shorthand `{x}` produces `Property(key=Identifier("x"), value=Identifier("x"), shorthand=true)`.
Renamed `{x: y}` produces `Property(key=Identifier("x"), value=Identifier("y"), shorthand=false)`.
Default `{x = 10}` produces `Property(key=Identifier("x"), value=AssignmentPattern(Identifier("x"), 10), shorthand=true)`.
Rest `{...rest}` produces `RestElement(Identifier("rest"))`.

**Source:** `let {x, y: z, a = 10, ...rest} = obj;`

### ArrayPattern

Array destructuring pattern (used in variable declarations).

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"ArrayPattern"` | |
| `elements` | `(Identifier \| AssignmentPattern \| ObjectPattern \| ArrayPattern \| RestElement \| nil)[]` | Pattern elements (nil = hole) |
| `count` | `number` | Element count including holes |

Holes are represented as `nil` (Lua sparse table). The `count` field tracks the total number of positional slots (including holes) so the transpiler can iterate correctly without `ipairs` stopping at the first nil.

**Source:** `let [a, , b, ...rest] = arr;`

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
| 5.5 | `**` | Right |
| 5 | `*` `/` `%` | Left |
| 4 | `+` `-` | Left |
| 3.5 | `<<` `>>` `>>>` | Left |
| 3 | `===` `!==` `<` `>` `<=` `>=` `in` | Left |
| 2.75 | `&` | Left |
| 2.5 | `^` | Left |
| 2.25 | `\|` | Left |
| 2 | `&&` | Left |
| 1 | `\|\|` | Left |
| 0.75 | `? :` (ternary) | Right |
| 0.5 | `=` `+=` `-=` `*=` `/=` `%=` `**=` `&=` `\|=` `^=` `<<=` `>>=` `>>>=` | Right |

Assignment (`=`) and compound assignment operators are right-associative: `a = b = c` parses as `a = (b = c)`; `x += y += 1` parses as `x += (y += 1)`.  
`**` (exponentiation) is also right-associative: `2 ** 3 ** 4` parses as `2 ** (3 ** 4)`.  
All other binary operators (including bitwise `&` `^` `|` and shifts `<<` `>>` `>>>` and `in`) are left-associative: `1 + 2 + 3` parses as `(1 + 2) + 3`.

### UnaryExpression

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"UnaryExpression"` | |
| `operator` | `string` | `"!"`, `"-"`, `"+"`, or `"~"` |
| `argument` | `node` | The operand |

Unary operators have the highest precedence (6) and are right-recursive: `!!x` parses as `!(!(x))`.

**Source:** `!x`, `-y`, `+z`, `~w`, `!!flag`, `+"5"`, `~~5.7`

The `~` (bitwise NOT) operator coerces its operand to a 32-bit integer via `ToInt32`, then computes `-(x+1)`. The transpiler emits a runtime helper `_ljs_bnot` that simulates this using pure math (`math.floor` + modular arithmetic).

### DeleteExpression

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"DeleteExpression"` | |
| `argument` | `node` | The expression to delete |

`delete` is a unary prefix keyword operator with the same precedence as other unary operators (6). It is right-recursive: `delete delete x` parses as `delete (delete x)`.

**Source:** `delete obj.prop`, `delete arr[i]`, `delete x`

### TypeofExpression

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"TypeofExpression"` | |
| `argument` | `node` | The expression to check the type of |

`typeof` is a unary prefix keyword operator with the same precedence as other unary operators (6). It is right-recursive: `typeof typeof x` parses as `typeof (typeof x)`.

**Source:** `typeof x`, `typeof 42`, `typeof obj.prop`, `typeof f()`

**Transpilation note:** `_ljs_typeof` returns `"object"` for `_ljs_null` and `"undefined"` for `nil`/`_ljs_undefined`, matching JS semantics exactly.

### UpdateExpression

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"UpdateExpression"` | |
| `operator` | `string` | `"++"` or `"--"` |
| `argument` | `node` | The operand (Identifier, MemberExpression, or CallExpression) |
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
| `arguments` | `(node | SpreadElement)[]` | Argument list (can be empty) |

**Source:** `f()`, `f(a, b)`, `console.log("hello")`, `fn(...args)`

`console.log` is not a special node — it parses as a `CallExpression` whose `callee` is a `MemberExpression`.

### NewExpression

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"NewExpression"` | |
| `callee` | `node` | Constructor expression (identifier or member expression) |
| `arguments` | `(node | SpreadElement)[]` | Argument list (can be empty) |

**Source:** `new Foo()`, `new Foo(a, b)`, `new Foo`, `new Foo.bar()`

Parsing rules follow JS semantics: after `new`, a member expression is parsed (identifiers + `.`/`[]` chains, no call parens), then optional `(args)`. Postfix `.prop`, `[key]`, and `(args)` chains apply to the result.

**Example:**
```js
new Foo().bar
```
```lua
{ type = "MemberExpression", object = { type = "NewExpression", callee = { type = "Identifier", name = "Foo" }, arguments = {} }, property = { type = "Identifier", name = "bar" }, computed = false }
```

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

### EmptyStatement

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"EmptyStatement"` | |

A bare semicolon. No-op at runtime — the transpiler emits nothing.

**Source:** `;`

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
| `elements` | `(node | SpreadElement)[]` | Element list (can be empty) |

**Source:** `[]`, `[1, 2, 3]`, `[...a, 1]`

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

### ContinueStatement

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"ContinueStatement"` | |

**Source:** `continue;`

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
| `finalizer` | `BlockStatement?` | Finally body, or `nil` |

At least one of `handler` or `finalizer` must be present.

**Source:** `try { x; } catch (e) { y; }`, `try { x; } finally { z; }`, `try { x; } catch (e) { y; } finally { z; }`

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

## Classes

### ClassDeclaration

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"ClassDeclaration"` | |
| `name` | `string` | Class name (required) |
| `superClass` | `node?` | Parent class expression, or `nil` |
| `body` | `MethodDefinition[]` | Array of method definitions |

**Source:** `class Foo { constructor() {} method() {} }`, `class Bar extends Foo {}`

### ClassExpression

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"ClassExpression"` | |
| `name` | `string?` | Class name (optional for anonymous classes) |
| `superClass` | `node?` | Parent class expression, or `nil` |
| `body` | `MethodDefinition[]` | Array of method definitions |

**Source:** `let F = class {}`, `let F = class Foo extends Bar {}`

### MethodDefinition

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"MethodDefinition"` | |
| `kind` | `string` | `"constructor"` or `"method"` |
| `key` | `Identifier` or `StringLiteral` | Method name |
| `value` | `FunctionExpression` | Method body (with `is_method` set appropriately) |
| `static` | `boolean` | `true` for static methods |

**Source:** `method() {}`, `static create() {}`, `"computed-name"() {}`

For constructor methods, `value.is_method` is `false`. For all other methods, `value.is_method` is `true`.

### SuperExpression

| Field | Type | Description |
|-------|------|-------------|
| `type` | `"SuperExpression"` | |

**Source:** `super()`, `super.method()`, `super.prop`

Appears as the `callee` of a `CallExpression` for `super(args)`, or as the `object` of a `MemberExpression` for `super.method()` / `super.prop`.

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
