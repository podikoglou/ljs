# Architecture

Three independent layers with strict boundaries:

```
JS source → [Parser] → AST → [Transpiler] → cg.* calls → [Codegen] → Lua source
```

1. **Parser** — JS source → AST. No dependencies. Knows nothing about Lua. All errors are `ParseError` tables `{message, line, col}` thrown via `error()`/`pcall()`. The public API (`ljs.parse()`, `ljs.tokenize()`) catches and returns `nil, ParseError`.
2. **Codegen** — Pure Lua source code builder. No dependencies. Knows nothing about JavaScript or ASTs. Every function takes strings and returns formatted Lua source strings. Module is returned as `cg`.
3. **Transpiler** — AST → Lua source via codegen. Depends on both parser and codegen. Makes all semantic decisions but never does raw string concatenation to produce Lua syntax. Every Lua syntax construct goes through `cg.*`.

## Transpiler boundary rule

The transpiler decides **what** to emit based on the AST. Codegen decides **how** to format it as Lua source. The transpiler must not:

- Concatenate strings to produce Lua keywords, operators, or delimiters (e.g. `.. "goto "`, `.. "function()"`)
- Use `cg.pad()` directly — use `cg.*` functions that accept indent parameters
- Build IIFE wrappers manually — use `cg.iife()`
- Construct goto/label strings manually — use `cg.goto_stmt()` and `cg.label()`
- Build inline Lua statements manually — use `cg.local_inline()`, `cg.return_inline()`, `cg.inline_if_return()`
- Join parameter/name lists with `", "` manually — use `cg.join()`

**Exception**: prepending a single `;` character to a codegen-produced expression (to prevent Lua ambiguous function call parsing) is acceptable: `cg.expr_stmt(";" .. codegen_expr, indent)`.

If you find yourself writing `.. "goto "` or `.. "(function()"` in the transpiler, add a new codegen function instead.

## JS Subset

### Supported

Variables (`let`/`const`; `var` normalized to `let`), functions, arrow functions (expression bodies desugared to `BlockStatement` wrapping `ReturnStatement`), `this` keyword (with correct lexical binding for arrow functions), objects, arrays (with `Array.prototype.push`/`pop`), arithmetic (`+` `-` `*` `/` `%`), exponentiation (`**`, right-associative), strict equality (`===`/`!==`; `==` rejected at tokenizer level), comparison (`<` `>` `<=` `>=`), `in`, `instanceof`, bitwise (`&` `|` `^` `<<` `>>` `>>>`), logical (`&&` `||`), ternary (`? :`), assignment (`=`), compound assignment (`+=` `-=` `*=` `/=` `%=` `**=` `&=` `|=` `^=` `<<=` `>>=` `>>>=`), unary (`!` `-` `+` `~`), `delete`, `typeof`, update (`++`/`--`, prefix and postfix), hex literals (`0xFF`, `0X1A`), `new`, `if`/`else`, `while`, `do...while`, `for...of`, `for...in`, `for(;;)` (C-style for with optional init/test/update), `switch`/`case`/`default`/`break`, `continue`, `throw`, `try`/`catch`, `return`, `console.log` (parsed as regular `CallExpression` with `MemberExpression` callee), constructors (`new Foo()`), `instanceof`, `typeof` on constructors returns `"function"`, `class` declarations and expressions with `extends`, `super()` (constructor) and `super.method()` (method), `static` methods, `Object.prototype.toString`/`hasOwnProperty`/`valueOf`, `Array.prototype.push`/`pop`, `Function.prototype.call`/`apply`.

### Rejected (parse error)

`async`/`await`, `==`, regex literals, Promises.

### Known gaps

- **`typeof null`**: Returns `"undefined"` instead of `"object"`. The transpiler maps JS `null` → Lua `nil`, which `_ljs_typeof` maps to `"undefined"`. All other `typeof` results match JS semantics.
- **`f instanceof Object`**: Returns `false` for instances of user-defined constructors. `_ljs_ctor`-created prototypes inherit from `_ljs_object_prototype`, but `Object.prototype` identity checks (e.g., `Foo.prototype === Object.prototype`) return `false`.
- **`console.log.prototype`**: Returns `nil` — `console.log` is wrapped in `_ljs_fn` (a callable table with `Function.prototype` chain), not `_ljs_ctor`. It has `.call` and `.apply` but no `.prototype`.

### Runtime call ABI

All JS functions follow a hidden-this calling convention:

- **FunctionDeclaration / FunctionExpression / ArrowFunctionExpression**: receive `_ljs_this` as their first parameter. The `this` keyword compiles to `_ljs_arrow_this`.
- **Lexical `this`**: Every function body begins with `local _ljs_arrow_this = _ljs_this` (for regular functions) or `local _ljs_arrow_this = _ljs_arrow_this` (for arrow functions). Arrow functions capture the enclosing scope's `_ljs_arrow_this` via closure, matching JS semantics.
- **Direct calls** (`f(a, b)`): compile to `_ljs_call(f, a, b)`, which passes `nil` as `_ljs_this`.
- **Member calls** (`obj.m(a, b)`): compile to `_ljs_call_member(obj, "m", a, b)`, which resolves `obj["m"]` and calls it with `obj` as `_ljs_this`.
- **Object literals** (`{a: 1}`): compile to `_ljs_object({a = 1})`, which wraps the table with `__index = _ljs_object_prototype` so all objects inherit from `Object.prototype`.
- **Array literals** (`[1, 2, 3]`): compile to `_ljs_new(Array, 1, 2, 3)`, producing proper Array instances with `.length`, `.push()`, `.pop()` via `Array.prototype`.

Reserved prefix: `_ljs_*` is reserved for compiler/runtime internals.

## Prototypes

Objects created via `Object.create(proto)` have a prototype chain implemented using Lua metatables (`__index`). Property reads walk the chain automatically. Property writes always set own properties (Lua default, no `__newindex` needed). `delete` uses `rawset` to remove own properties without affecting the prototype.

**Prototype creation:**
- `Object.create(proto)` → `_ljs_object_create(Object, proto)` → `setmetatable({}, {__index = proto})`
- Object literals (`{a: 1}`) produce `_ljs_object({a = 1})` → `setmetatable({a = 1}, {__index = _ljs_object_prototype})`
- Array literals (`[1, 2, 3]`) produce `_ljs_new(Array, 1, 2, 3)` → Array instance with `Array.prototype` chain

**Property access semantics:**
- Inherited read: walks `__index` chain. ✓
- Own write shadows: sets on own table. ✓
- `delete`: removes own only, reveals inherited. ✓
- `in`: walks chain (changed from `rawget` to normal table access). ✓
- Method calls: `_ljs_call_member(obj, key, ...)` → `obj[key](obj, ...)`. `obj[key]` walks `__index`; `obj` is always the original receiver. ✓

**Known gaps:**
- `for...in` does not walk prototype chain (Lua `pairs()` only sees own properties). A `_ljs_pairs` iterator is deferred.
- nil/null confusion: Lua tables cannot store `nil` as a value. Properties set to `null` are indistinguishable from missing properties.
- Multi-level `__index` chaining is correct for prototype inheritance but may conflict with future metatable-based getters/descriptors. Migration to explicit `_ljs_get`/`_ljs_set` helpers is expected when descriptors are added.

## Constructors

Functions (`FunctionDeclaration`, `FunctionExpression`) are wrapped in `_ljs_ctor`, which returns a callable table with a `.prototype` property inheriting from `_ljs_object_prototype`. Arrow functions and method shorthand are wrapped in `_ljs_fn` (callable table without `.prototype` but with `Function.prototype` chain).

**`_ljs_fn(fn)`:**
- Returns a callable table with `__call` metamethod delegating to `fn`
- Has `__index = _ljs_function_prototype` so `.call` and `.apply` are available
- Used for arrow functions, method shorthand, and any function that doesn't need `.prototype`

**`_ljs_ctor(fn)`:**
- Builds on `_ljs_fn`: creates callable table with `__call` + `__index = Function.prototype`
- Adds `.prototype = setmetatable({ constructor = ctor }, { __index = _ljs_object_prototype })` as own key
- `type(ctor)` is `"table"`, but `_ljs_typeof` detects `__call` and returns `"function"`

**`new Foo(args)`:**
- `_ljs_new(Foo, args...)` → `ctor(instance, args...)` via `__call` → `fn(instance, args...)`
- Instance created via `_ljs_object_create(nil, Foo.prototype)` → `setmetatable({}, {__index = Foo.prototype})`
- If constructor returns a table, that object is returned instead of the instance

**`x instanceof Foo`:**
- `_ljs_instanceof(x, Foo)` walks `x`'s `__index` chain, checking for `Foo.prototype`
- Primitives (`nil`, `number`, `string`) return `false`

**Method shorthand (`is_method` flag):**
- `{ m() {} }` creates `FunctionExpression` with `is_method = true`
- Wrapped in `_ljs_fn` (not `_ljs_ctor`) — methods get `.call`/`.apply` but no `.prototype`

**Runtime constructors:**
- `Object` is wrapped in `_ljs_ctor`, making it callable with `.prototype = _ljs_object_prototype`
- `Array` is wrapped in `_ljs_ctor` with `.prototype.push`, `.prototype.pop`
- `Function` is wrapped in `_ljs_ctor` with `.prototype = _ljs_function_prototype` (`.call`, `.apply`)
- `console` is wrapped in `_ljs_object` (not `_ljs_ctor`) — plain object with `Object.prototype` chain

## Class syntax

`class` is syntactic sugar over the constructor + prototype model. The transpiler lowers class declarations to `_ljs_ctor`-wrapped constructors + prototype method assignments.

**Lowering of `class Foo { constructor(x) {} method() {} static create() {} }`:**
1. `local Foo = _ljs_ctor(function(_ljs_this, x) ... end)` — constructor wrapped in `_ljs_ctor`
2. `Foo.prototype["method"] = function(_ljs_this) ... end` — prototype methods
3. `Foo["create"] = function(_ljs_this) ... end` — static methods assigned directly to constructor

**Lowering of `class Dog extends Animal {}`:**
1. Constructor wraps in `_ljs_ctor` with default body that calls `Animal(_ljs_arrow_this, ...)` (forwards all args)
2. `Dog.prototype = _ljs_object_create(nil, Animal.prototype)` — prototype chain
3. `Dog.prototype.constructor = Dog` — restore constructor property

**`super()` in constructor:**
- Lowers to direct call: `ParentCtor(_ljs_arrow_this, args...)`
- `ParentCtor` is the `_ljs_ctor`-wrapped callable table; `__call` dispatches to the underlying function with the instance as `_ljs_this`

**`super.method()` in methods:**
- Lowers to `_ljs_super_call(Parent.prototype, "method", _ljs_arrow_this, args...)`
- `_ljs_super_call` looks up `proto[key]` and calls it with the current instance as `_ljs_this`

**`super.prop` (property access):**
- Lowers to `Parent.prototype.prop` (via `cg.member_dot`)

**Class expressions:**
- Wrapped in IIFE because lowering produces multiple statements
- Anonymous classes use `_ljs_class` as internal name; named classes use the provided name

**Default constructor:**
- Without `extends`: empty body
- With `extends`: `function(_ljs_this, ...) ParentCtor(_ljs_arrow_this, ...) end`

## Runtime objects

Standard library globals (`Object`, `Array`, `Function`, `console`) are real JS objects created in a runtime initialization block emitted between helpers and user code. They are not compiler special cases.

**Prototype infrastructure:**
- `_ljs_object_prototype` — root prototype declared before helpers, populated with `toString`, `hasOwnProperty`, `valueOf` during runtime init. Assigned to `Object.prototype`.
- `_ljs_function_prototype` — root function prototype declared before helpers, populated with `call`, `apply` during runtime init. Assigned to `Function.prototype`.
- All `_ljs_ctor`-created prototypes inherit from `_ljs_object_prototype` via `__index`.
- All `_ljs_fn`-wrapped functions inherit from `_ljs_function_prototype` via `__index`.
- All `_ljs_object`-wrapped objects inherit from `_ljs_object_prototype` via `__index`.
- All `_ljs_new`-created instances inherit from their constructor's prototype, which inherits from `_ljs_object_prototype`.

**Variable declaration pattern:**
- Functions assigned to variables use `local x; x = _ljs_fn(...)` instead of `local x = _ljs_fn(...)` to work around a Lua 5.5 closure upvalue issue where the function's self-reference would resolve to `nil`.

To add a new standard library function (e.g. `Array.prototype.forEach`, `String.prototype.trim`):
1. Define the function in the runtime init block as a method on the target prototype or object
2. Use the JS-ABI convention: `function(_ljs_this, ...)` for all methods
3. No transpiler changes required — member calls compile to `_ljs_call_member(obj, key, ...)` which resolves the method at runtime via the prototype chain

Internal operator/expression helpers (e.g. `_ljs_add`, `_ljs_ctor`, `_ljs_bnot`) follow a different pattern:
1. Define the helper in the `HELPERS` table (used for conditional emission via `needed_helpers` analysis)
2. Add tracking in `analyze_node()` to set `meta.needed_helpers[helper_name] = true` when the relevant AST node is encountered
3. The helper is automatically emitted in the output when needed
