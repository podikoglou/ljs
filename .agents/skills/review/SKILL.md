---
name: review
description: Review PRs, branches, or commits. Checks out the target locally, reads PR context via gh CLI, validates JS semantics against the ECMAScript spec using ecma-query, tests against Node.js as reference, and audits test coverage. Use when asked to review a PR, branch, commit, or any code change.
---

# Code Review

## Determining what to review

Parse the input. If it looks like a PR (number, `#57`, URL) → fetch and checkout the PR. Branch name → diff against main and checkout. Commit hash → show that commit. No input → uncommitted changes.

**Always check out the target** so you're reading the actual code, not just a diff. For PRs, use `gh pr view` to read the description first — it states intent, which frames whether the code does the right thing.

## Review workflow

### 1. Context first, diff second

Read the PR description or commit message **before** the diff. Then read the full files that were changed — diffs are insufficient. Code that looks wrong in isolation may be correct given surrounding logic, and vice versa. Identify new files via `git status --short` and read them in full.

### 2. Ground truth: the spec

This is a JS → Lua transpiler. When a change touches JS semantics (operators, coercion, built-ins, grammar), **confirm against the ECMAScript spec** using the `ecma-query` skill. Don't guess at JS behavior — look it up. If the implementation diverges from the spec, flag it unless it's already documented as a known gap.

### 3. Ground truth: the reference implementation

Test the behavior against Node.js. Write a small JS snippet exercising the changed feature, run it in Node, then run it through ljs and compare. Semantics must match, not just output format.

### 4. Audit tests

Check that the change has tests and that they cover:
- Empty / zero / nil / null inputs
- Boundary values
- Nesting and interactions with other features
- Error cases and syntax rejection
- Every branch of conditionals in the implementation

Run the test suite to confirm everything passes.

### 5. Architecture and conventions

Check the project's `AGENTS.md`, `docs/ARCHITECTURE.md`, and `docs/CONTRIBUTING.md` for layer boundaries, naming rules, and code style. Flag violations of documented conventions, not personal preferences.

## What to flag

**Bugs** — primary focus. Logic errors, missing guards, unreachable paths, broken error handling, edge cases that crash or produce wrong results.

**Spec deviations** — behavior that doesn't match ECMAScript and isn't documented as a known gap.

**Missing or weak tests** — happy-path-only coverage, untested edge cases, missing error tests.

**Architecture violations** — breaking documented layer boundaries or conventions.

**Performance** — only if obviously problematic.

## Incidental findings

If you notice unrelated issues while reading code (pre-existing bugs, missing features, stale docs), don't include them in the review. Instead, create a GitHub issue via `gh issue create` — but first check that an issue for it doesn't already exist (`gh issue list --search ...`). Keep review output focused on the changes under review.

## Before flagging something

- Only review **changed code**, not pre-existing code
- Be certain. Investigate before calling something a bug
- Check documented known gaps before flagging a spec deviation
- Don't invent hypothetical problems — explain the realistic scenario that triggers it
- Don't flag style unless it violates **documented** conventions
- If unsure, say "I'm not sure about X" rather than flagging it

## Output

1. Direct and clear about **why** something is wrong
2. Precise severity — don't overstate
3. Include the specific scenario/input that triggers the issue
4. Matter-of-fact tone, no flattery, no filler
5. Scannable — reader understands the issue at a glance
