# Architecture

Three independent layers with strict boundaries:

```
JS source → [Parser] → AST → [Transpiler] → cg.* calls → [Codegen] → Lua source
```

1. **Parser** — JS source → AST. No dependencies. Knows nothing about Lua.
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

Variables (`let`/`const`; `var` normalized to `let`), functions, arrow functions (expression bodies desugared to `BlockStatement` wrapping `ReturnStatement`), `this` keyword (with correct lexical binding for arrow functions), objects, arrays, arithmetic (`+` `-` `*` `/` `%`), exponentiation (`**`, right-associative), strict equality (`===`/`!==`; `==` rejected at tokenizer level), comparison (`<` `>` `<=` `>=`), `in`, bitwise (`&` `|` `^` `<<` `>>` `>>>`), logical (`&&` `||`), ternary (`? :`), assignment (`=`), compound assignment (`+=` `-=` `*=` `/=` `%=` `**=` `&=` `|=` `^=` `<<=` `>>=` `>>>=`), unary (`!` `-` `+` `~`), `delete`, `typeof`, update (`++`/`--`, prefix and postfix), hex literals (`0xFF`, `0X1A`), `if`/`else`, `while`, `do...while`, `for...of`, `for...in`, `for(;;)` (C-style for with optional init/test/update), `switch`/`case`/`default`/`break`, `continue`, `throw`, `try`/`catch`, `return`, `console.log` (parsed as regular `CallExpression` with `MemberExpression` callee).

### Rejected (parse error)

`async`/`await`, `instanceof`, `==`, regex literals, Promises.

### Known gaps

- **`typeof null`**: Returns `"undefined"` instead of `"object"`. The transpiler maps JS `null` → Lua `nil`, which `_ljs_typeof` maps to `"undefined"`. All other `typeof` results match JS semantics.

### Runtime call ABI

All JS functions follow a hidden-this calling convention:

- **FunctionDeclaration / FunctionExpression / ArrowFunctionExpression**: receive `_ljs_this` as their first parameter. The `this` keyword compiles to `_ljs_arrow_this`.
- **Lexical `this`**: Every function body begins with `local _ljs_arrow_this = _ljs_this` (for regular functions) or `local _ljs_arrow_this = _ljs_arrow_this` (for arrow functions). Arrow functions capture the enclosing scope's `_ljs_arrow_this` via closure, matching JS semantics.
- **Direct calls** (`f(a, b)`): compile to `_ljs_call(f, a, b)`, which passes `nil` as `_ljs_this`.
- **Member calls** (`obj.m(a, b)`): compile to `_ljs_call_member(obj, "m", a, b)`, which resolves `obj["m"]` and calls it with `obj` as `_ljs_this`.
- **Object literals** (`{a: 1}`): compile to `_ljs_object({a = 1})`, which currently returns the table as-is but establishes a factory boundary for future prototype support.

Reserved prefix: `_ljs_*` is reserved for compiler/runtime internals.

## Prototypes

Objects created via `Object.create(proto)` have a prototype chain implemented using Lua metatables (`__index`). Property reads walk the chain automatically. Property writes always set own properties (Lua default, no `__newindex` needed). `delete` uses `rawset` to remove own properties without affecting the prototype.

**Prototype creation:**
- `Object.create(proto)` → `_ljs_object_create(Object, proto)` → `setmetatable({}, {__index = proto})`
- Object literals (`{a: 1}`) produce plain tables via `_ljs_object({a = 1})` — no default `Object.prototype` inheritance yet.

**Property access semantics:**
- Inherited read: walks `__index` chain. ✓
- Own write shadows: sets on own table. ✓
- `delete`: removes own only, reveals inherited. ✓
- `in`: walks chain (changed from `rawget` to normal table access). ✓
- Method calls: `_ljs_call_member(obj, key, ...)` → `obj[key](obj, ...)`. `obj[key]` walks `__index`; `obj` is always the original receiver. ✓

**Known gaps:**
- `for...in` does not walk prototype chain (Lua `pairs()` only sees own properties). A `_ljs_pairs` iterator is deferred.
- Object literals do not inherit from `Object.prototype` by default. `{}.toString()` is not yet available.
- nil/null confusion: Lua tables cannot store `nil` as a value. Properties set to `null` are indistinguishable from missing properties.
- Multi-level `__index` chaining is correct for prototype inheritance but may conflict with future metatable-based getters/descriptors. Migration to explicit `_ljs_get`/`_ljs_set` helpers is expected when descriptors are added.

## Runtime objects

Standard library globals (`Object`, `console`) are real JS objects created in a runtime initialization block emitted between helpers and user code. They are not compiler special cases. Members like `Object.create` and `console.log` are ordinary JS functions stored on these objects, accessed via normal `_ljs_call_member` dispatch.

To add a new standard library function:
1. Define a JS-ABI helper (`function(_ljs_this, ...)`) in `HELPERS`
2. Assign it to the runtime object in the init block
3. No transpiler changes required
