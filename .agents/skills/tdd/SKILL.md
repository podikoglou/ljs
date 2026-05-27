---
name: tdd
description: >
  ljs-specific TDD execution engine. Runs vertical Red-Green-Refactor loops
  with layer-awareness and commit checkpoints. Called by the orchestrator's
  implementation subagent after planning is done.
---

# TDD for ljs

Execute test-driven development on ljs. Planning is done — receive the plan, run the loop.

**Core loop**: ONE test → confirm RED → minimal implementation → confirm GREEN → commit → repeat.

Never horizontal. Never skip `make test`. Never assume.

## Layer Detection

Determine which layers a change touches. Read source to confirm — don't guess.

| Signal | Layers |
|--------|--------|
| New JS syntax or keyword | parser → transpiler (codegen only if new Lua construct needed) |
| Wrong AST output | parser only |
| Wrong Lua output, AST correct | transpiler only |
| New Lua syntax construct needed | codegen → transpiler |
| Runtime function missing/broken | runtime only |
| New builtin object/method | transpiler + runtime |
| Bug of unknown origin | read source at each layer to find where it diverges |

## Vertical Slicing

Work through ALL relevant layers for ONE behavior before moving to the next:

```
WRONG (horizontal):
  all parser tests → all transpiler tests → all runtime tests

RIGHT (vertical, tracer bullet first):
  parser test A → transpiler test A → commit
  parser test B → transpiler test B → commit
```

First slice is the tracer bullet — simplest happy path. Proves the pipeline before edge cases.

For single-layer bugs: tests in that layer only.

## Execution Loop

### RED

1. Read a few existing tests in the target layer to understand patterns and helpers.
2. Write ONE test for ONE behavior.
3. Run `make test`. Confirm the NEW test fails.
   - Acceptable: assertion failure, missing function, wrong output
   - Not acceptable: passes (bad test), unrelated failure
4. If the target function doesn't exist, create a stub returning zero/nil so the test
   asserts rather than errors on require.

### GREEN

1. Write minimal code to pass. Match surrounding style.
   - Transpiler: all Lua syntax through `cg.*` — never raw string concat.
     If `cg` lacks a builder, add one to codegen first with its own test.
   - Parser: follow existing patterns in the parser source.
2. Run `make test`. ALL tests must pass — new and existing.
3. Still failing? Diagnose from output, fix only what's needed, re-run.

### COMMIT

After each GREEN, commit specific files:
```
git add <files> && git commit -m "<type>: <description>"
```

Prefixes: `test:` (test-only), `feat:`, `fix:`, `refactor:`, `docs:`.

Separate RED and GREEN commits when practical. Combine when both touch the same file.

### REFACTOR (after all behaviors green)

Only for concrete reasons: duplication, poor naming, missed abstraction.
Run `make test` after each step. Commit with `refactor:`.

## Test File Management

Tests live in `test/<layer>/` — look at existing tests in the same layer to learn
conventions, helpers, and import patterns. When creating a new test file, register it
in `test/run.lua` following the existing pattern for that layer.

## Spec Verification

Before writing the first test for a behavior, verify expected JS semantics if there's
any ambiguity:

- ECMA-262 spec via the `ecma-query` skill
- `node -e 'console.log(...)'` for concrete confirmation

Do this once per behavior, not per test.

## Documentation

When adding or changing AST node types, update `docs/AST.md` and `docs/ARCHITECTURE.md`
as needed. Commit docs with the implementation they describe.

## Anti-Patterns

Never:
- Write implementation before tests
- Write multiple tests before any pass (horizontal slicing)
- Move to GREEN without confirming RED from actual `make test` output
- Write trivially-passing tests or tests coupled to implementation internals
- Skip `make test` — always run it
- Use raw string concat in the transpiler for Lua syntax
- Ask the user — the plan has answers. Read source/docs to fill gaps.
- Forget to register new test files in `test/run.lua`

## Reports

Minimal. Per cycle:

- **RED**: `RED: "<test name>" — fails as expected.`
- **GREEN**: `GREEN: <source file> — all pass. Committed.`
- **REFACTOR**: `REFACTOR: <what> — all pass.`

When done: `DONE: N behaviors, N commits, all green.`
