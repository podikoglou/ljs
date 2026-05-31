---
name: review
description: Review PRs, branches, or commits. Checks out the target locally, reads PR context via gh CLI, validates JS semantics against the ECMAScript spec using ecma-query, tests against Node.js as reference, and audits test coverage. Use when asked to review a PR, branch, commit, or any code change.
---

# Code Review

## Setup

Parse the input. PR number/URL → `gh pr checkout`. Branch name → diff against `develop` and checkout. Commit hash → show that commit. No input → uncommitted changes.

**Always check out the target.** For PRs, read `gh pr view` first for intent. If a handoff artifact exists at `/tmp/ljs-handoff-<issue>.md`, read it — the planning subagent already did analysis.

Read every changed file **in full** — diffs are insufficient.

## Checks

Run these in order. **A single blocking finding in any check means the verdict is "needs fixes".** There is no "merge with suggestions". If something should be fixed, it blocks merge.

### 1. Architecture and separation of concerns

Read `docs/ARCHITECTURE.md`. It defines strict layer boundaries for this codebase. Verify every changed file respects them. The layers are:

- **Parser** — JS source → AST. Knows nothing about Lua.
- **Codegen** — pure Lua source builder. Takes strings, returns strings. No AST knowledge, no dependencies.
- **Transpiler** — AST → Lua via codegen calls. Makes semantic decisions but never produces Lua syntax directly.

The most common serious defect is **cross-layer contamination** — logic that belongs in one layer appearing in another. When the transpiler needs a new Lua construct, the answer is always "add a codegen function", never "inline it". When codegen needs to understand JS semantics, the answer is "the transpiler should handle that", never "add JS knowledge to codegen".

Any violation of documented layer boundaries is **blocking**. No exceptions.

Also check `docs/CONTRIBUTING.md` for naming, test structure, doc conventions, and error handling patterns.

### 2. DRY

Read every changed file and look for:

- Logic duplicated within a file that should be a local helper
- Logic that already exists elsewhere being reimplemented instead of reused
- Copy-paste with minor variations that should be parameterized

DRY violations are **blocking**. Extract the shared logic.

### 3. Spec correctness

When changes touch JS semantics, **look up the ECMAScript spec** using `ecma-query`. Never rely on memory. If the implementation diverges from the spec and it's not a documented known gap in `docs/ARCHITECTURE.md`, it's **blocking**.

### 4. Node.js verification

Write a small JS snippet exercising the changed behavior, run it in Node, run it through ljs, compare. Behavioral differences are **blocking**.

### 5. Test coverage

**This is the check that most often gets hand-waved. Do not let it slide.** Insufficient test coverage is always **blocking**.

For every changed behavior, verify tests exist for:

- Happy path
- Empty / zero / nil / null / undefined inputs
- Boundary values
- Nesting and interactions with other features
- Error cases and syntax rejection
- Every conditional branch in the implementation

If tests are missing, enumerate exactly what's needed:

```
MISSING TESTS:
1. test/transpile/foo.lua: empty input case
2. test/transpile/foo.lua: nesting inside try/catch
3. test/transpile/foo.lua: error case — for-of on non-iterable
```

Do not say "we could add more tests but merge it". Write the tests or block.

### 6. Bugs

Logic errors, missing guards, unreachable paths, broken error handling, edge cases that crash or produce wrong results. **Blocking.**

## Before flagging

- Only review **changed code**, not pre-existing code
- Be certain — investigate before calling something a bug
- Don't invent hypothetical problems — explain the realistic scenario
- If unsure, say "I'm not sure about X" rather than flagging confidently

## Incidental findings

Pre-existing bugs or unrelated issues noticed during review → create a GitHub issue (`gh issue create`), check for duplicates first (`gh issue list --search ...`). Keep review output focused on changes under review.

## Output

### Ready to merge

```
VERDICT: ready to merge
```

### Needs fixes

```
VERDICT: needs fixes

BLOCKING ISSUES:
1. [architecture] file:line — description of the violation
2. [dry] file:line — description of the duplication
3. [tests] missing coverage for X, Y, Z
4. [spec] description of spec deviation
```

Every issue gets the tag and the specific location. Fix these and re-request review.

## General output rules

- Direct and clear about why something is wrong
- Every issue is blocking or non-blocking — never "suggested" or "nice to have"
- Include file, line, and the realistic scenario that triggers it
- No flattery, no filler, no hedging
