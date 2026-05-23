# Preamble Refactor — Design Decisions

## Goal

Delete the `analyze_node` two-pass architecture. Always emit all helpers unconditionally as a preamble. Single-pass codegen. Future-proof the multi-file API.

## Terminology

- **Helpers** — compiler ABI. Invisible to JS source. The transpiler inserts calls to these. Examples: `_ljs_add`, `_ljs_call`, `_ljs_ctor`, `_ljs_typeof`, `_ljs_new`, `_ljs_instanceof`. 19 helpers total, ~110 lines of Lua.
- **Standard library** — JS-visible builtins. User writes `console.log()`, `new Array()`, `obj.toString()`. Resolved at runtime via prototype chain. Lives in `ljs_runtime/` files.
- **Preamble** — everything emitted before user code: proto declarations, helpers, runtime std lib files.
- **BUILTINS** — a dispatch table for compile-time recognition of known builtin calls (empty, never used). Being deleted.

## Decisions

### 1. Always emit all helpers unconditionally

No more helper detection via `analyze_node`. All 19 helpers go in the preamble every time. ~260 lines of analysis/walker code deleted. Output grows by at most ~60 lines for programs that didn't use all helpers. Tree-shaking optimizations can be done later as a separate pass.

### 2. Delete BUILTINS and lookup_builtin

BUILTINS table is empty. `lookup_builtin` always returns nil. Both deleted. `gen.CallExpression` loses the builtin branch — all calls go through generic `_ljs_call` / `_ljs_call_member`. Can be reintroduced later as an optimization if needed.

### 3. Delete analyze_node and analyze

The entire pass 1 (scope tracking + helper detection) is removed. Scope tracking was redundant — `gen.*` already tracks scopes during codegen. Helper detection is replaced by unconditional emission.

### 4. Preamble assembly order

```
1. Proto declarations (_ljs_object_prototype, _ljs_function_prototype) — from ljs_runtime/proto.lua
2. local _ljs_arrow_this = nil   — top-level `this` binding
3. Helpers — to_int32 first, _ljs_fn second, rest alphabetical
4. Runtime std lib files — object, function, array, console (in that order)
5. User code
```

Dependency chain: proto → helpers → runtime files → user code. Each layer depends only on previous.

### 5. `_ljs_arrow_this = nil` moved to preamble

Currently `gen.Program` emits this. Moved to preamble after proto declarations. It belongs in the runtime environment setup, not in user code emission. Fixes multi-file duplication for free.

### 6. `gen.Program` stays as-is (minus arrow_this init)

Every AST node type has a corresponding `gen.*` handler. Program is distinct from BlockStatement — it has eval-mode (return last expression statement). Symmetry with the AST is intentional and idiomatic.

### 7. `has_continue` stays as a lookahead utility

No change. Called during codegen from loop `gen.*` handlers. Bounded (stops at loop/function boundaries). No pre-computation pass needed.

### 8. `super_stack` and `eval_mode` stay on `ctx`

No change. Both already correctly scoped to codegen context. `ctx` construction moves from `generate()` to `emit()`.

### 9. `read_runtime()` kept as-is (debug.getinfo)

Fine for LuaRocks distribution. Single-file distribution would need an amalgamation build step (separate concern).

### 10. `HELPERS` table stays exported on `ljs_transpile`

Read-only for debugging/inspection. No functional change.

### 11. Hardcoded runtime file loading, not a manifest list

At 5 files, hardcoded `read_runtime("proto") .. read_runtime("object") ...` is simpler than a manifest list with iteration. Revisit when there are 50+ runtime files.

### 12. DOCS: Distinguish helpers vs std lib in ARCHITECTURE.md

Current doc describes helpers as conditionally emitted (lines 164-167). Update to document the helper/std-lib distinction and that both are always emitted as the preamble.

## Public API (ljs.lua)

```lua
-- Parse (unchanged)
ljs.parse(source)          -- → ast | nil, ParseError
ljs.parse_tokens(tokens)   -- → ast | nil, ParseError
ljs.tokenize(source)       -- → tokens | nil, ParseError

-- Preamble (new)
ljs.preamble()             -- → string  (helpers + std lib, cached, idempotent)

-- Codegen (new)
ljs.emit(ast)              -- → string  (AST → user code only, no preamble)

-- Transpile (convenience)
ljs.transpile(source)      -- → string | nil, err  (parse + preamble + emit)
ljs.transpile_ast(ast)     -- → string             (preamble + emit)

-- Execute (unchanged)
ljs.load(source)           -- → fn | nil, err
ljs.run(source)            -- → result | nil, err
```

## Use cases covered

| Use case | API |
|----------|-----|
| Transpile JS string to Lua | `ljs.transpile(source)` |
| Parse, modify AST, transpile | `ljs.parse()` + `ljs.transpile_ast(ast)` |
| Run JS in Lua | `ljs.run(source)` |
| Multi-file into one Lua file | `ljs.preamble()` once + `ljs.emit(ast)` per file |
| REPL / dynamic eval | `ljs.preamble()` once + `ljs.load(source)` per snippet |
| AST tooling | `ljs.parse(source)` |
| Tokenize only | `ljs.tokenize(source)` |

## Changes summary

### ljs_transpile.lua
- **Add**: `preamble()` — assemble + cache preamble string (all helpers + runtime, idempotent)
- **Add**: `emit(ast, opts)` — construct ctx, emit user code only (no preamble)
- **Change**: `transpile(ast, opts)` — now = `preamble() .. emit(ast, opts)`
- **Keep**: `transpile_source(source, opts)` — unchanged wrapper
- **Delete**: `analyze_node()` (~260 lines)
- **Delete**: `analyze()` (4 lines)
- **Delete**: `BUILTINS` table
- **Delete**: `lookup_builtin()`
- **Delete**: `generate()` — replaced by `preamble()` + `emit()`
- **Change**: `gen.Program` — drop `local _ljs_arrow_this = nil` (moved to preamble)
- **Change**: `gen.CallExpression` — remove builtin dispatch branch
- **Change**: preamble always includes all 19 helpers + all 5 runtime files
- **Keep**: `HELPERS` exported
- **Keep**: `read_runtime()`, `super_stack`, `eval_mode` — unchanged
- **Add**: `HELPER_ORDER` table for deterministic helper ordering
- **Add**: `scope_push`, `scope_pop`, `scope_declare` as local functions operating on `ctx.scopes`

### ljs.lua
- **Add**: `ljs.preamble()` — delegates to `ljs_transpile.preamble()`
- **Add**: `ljs.emit(ast)` — delegates to `ljs_transpile.emit()`
- **Change**: `ljs.transpile_ast(ast)` — now = `preamble() .. emit(ast)`
- **Keep**: `parse`, `parse_tokens`, `tokenize`, `transpile`, `load`, `run` — unchanged

### ljs_runtime/
- No changes. All files kept as-is.

### docs/ARCHITECTURE.md
- Updated helper section to document unconditional emission and preamble structure
- Added public API and multi-file pattern docs

### Test changes
- Removed BUILTINS test (no longer exported)
- Updated "no helpers when unused" tests to "all helpers always in preamble"
- Added 14 new tests for `ljs.preamble()` and `ljs.emit()` API
- Total: 1535 tests pass (was 1522)
