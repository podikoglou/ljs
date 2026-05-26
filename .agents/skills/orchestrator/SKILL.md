---
name: orchestrator
description: Orchestrate multi-phase development work using sequential subagents. Each phase covers one or a few closely-related GitHub issues, running them through plan → implement → review → fix → merge, and looping on any new issues discovered. Use when the user provides a list of phases/issues to work through, asks to "work through these issues", or describes batch work across multiple PRs.
---

# Orchestrator

## Overview

A workflow for processing GitHub issues through sequential subagent rounds. The main context is an **orchestration layer only** — you may read issues, PRs, and GitHub comments here, but no code analysis, no spec reading, no implementation. All real work happens in subagents.

## Quick Start

1. User provides phases (each phase = one or a few closely-related GitHub issue numbers)
2. For each phase, spawn subagents sequentially: plan → implement → review → fix (if needed) → merge
3. Loop on any new issues created by subagents
4. Notify the user after each merge

## Workflow

### Per-Phase Checklist

Run these steps **strictly in order**. No parallel subagents within a phase.

- [ ] **1. Planning subagent**
  - Pull `develop`, create branch (naming: `fix/`, `refactor/`, `feat/` as appropriate)
  - Study code + ECMA spec + Node.js behavior
  - Determine if issue is still valid
  - Determine if TDD is the right approach, or if a different methodology fits better
  - Classify issue as **AFK** (agent can complete autonomously) or **HITL** (needs human checkpoint)
  - Write handoff artifact to `/tmp/ljs-handoff-<issue>.md` with: findings, spec references, plan, AFK/HITL classification, suggested skills
  - Report technical plan + recommended implementation approach (or invalidity)

- [ ] **2. Implementation subagent**
  - Read handoff artifact from `/tmp/ljs-handoff-<issue>.md`
  - Use the methodology recommended by the planning subagent (TDD, refactor-first, etc.)
  - If TDD: load `tdd` skill
  - If unsupported features encountered: create GitHub issue, use `--no-verify` to commit
  - Push branch, create PR targeting `develop`
  - If issue was classified **HITL**: stop and notify user for checkpoint before proceeding

- [ ] **3. Review subagent**
  - Read handoff artifact from `/tmp/ljs-handoff-<issue>.md` (avoids redundant spec lookups)
  - Load `review` skill
  - Thorough spec + Node.js verification
  - Report findings: ready to merge or needs fixes

- [ ] **4. Fix subagent** (only if review found issues)
  - Address review findings
  - Re-run tests, commit, push

- [ ] **5. Merge** (in main context, NOT in subagent)
  - `gh pr merge <number> --merge --delete-branch`
  - `git pull` on develop
  - `gh issue close <number>` for each issue in phase
  - Notify the user with PR link
  - Update todo list

### After All Phases

- Check for issues created by subagents during work
- If found: create new phases and loop (same workflow)
- If none: done

## Subagent Prompt Templates

Each subagent must receive these universal instructions:

```
## CRITICAL INSTRUCTIONS
- If you come across language features that ljs doesn't support yet, CONTINUE
  using them despite tests not passing. Create a GitHub issue if one doesn't
  already exist. Use git commit --no-verify to commit.
- If you discover ANY issues or missing features in ljs, create a GitHub issue.
```

### Planning Subagent

```
Your task is to create a branch from develop and analyze issue #X.
- git checkout develop && git pull
- git checkout -b <appropriate-prefix>/<name>
- Read source files, check ECMA spec, verify with Node.js
- Do NOT make code changes. Just study and report.
- If issue is invalid, report why.
- Determine if TDD is the right approach or if a different methodology fits better.
- Classify as AFK (agent can complete autonomously) or HITL (needs human checkpoint). Prefer AFK.
- Write a handoff artifact to /tmp/ljs-handoff-<X>.md containing:
  - Issue summary and validity
  - Key findings from code/spec analysis
  - Technical plan + implementation approach
  - AFK or HITL classification (and why)
  - Suggested skills for the implementation subagent
- Return full technical plan + recommended implementation approach.
```

### Implementation Subagent (TDD)

```
Branch already exists. Read /tmp/ljs-handoff-<X>.md for context.
Implement fix for issue #X using strict TDD.
- Load tdd skill first.
- After all work: commit, push, create PR targeting develop.
- PR title: "<type>: description (#X)"
```

### Implementation Subagent (refactor / other)

```
Branch already exists. Read /tmp/ljs-handoff-<X>.md for context.
Implement changes for issue #X.
- Write tests first where applicable, but adapt methodology to the task.
- After all work: commit, push, create PR targeting develop.
- PR title: "<type>: description (#X)"
```

### Review Subagent

```
Read /tmp/ljs-handoff-<X>.md for planning context (avoids redundant spec lookups).
Load review skill. Review PR #N.
- Checkout PR locally, review changes, run make test
- Check ECMA spec compliance, verify against Node.js
- Report: ready to merge or needs fixes
```

### Fix Subagent

```
Branch has PR #N open. Review found these issues: <issues>.
- Fix them, run make test, commit --no-verify, push.
```

## Rules

- **Main context is orchestration only** — you may read issues, PRs, and GitHub comments, but no code/spec analysis
- **No parallel subagents** — sequential within a phase
- **Must pull develop** before creating each new branch (previous PR may have just been merged)
- **Always spawn all subagents** — even if planning seems trivial
- **Handoff artifacts** — planning subagent writes `/tmp/ljs-handoff-<issue>.md`; implementation and review subagents read it instead of re-discovering context
- **AFK vs HITL** — planning classifies each issue; HITL issues pause after implementation for human checkpoint before review
- **Merge in main context** — never in a subagent
- **Conventional commit messages** — `fix:`, `feat:`, `refactor:`, `test:`
- **Close issues** after merge
- **Notify the user** after each phase with PR link

## Grouping Guidance

**Keep phases small.** One issue per phase is the default. Only group issues together when they are very closely related:

- They share the exact same code area and the fix is intertwined
- One issue is a direct prerequisite of the other
- They are two aspects of the same bug

When in doubt, keep them separate. Larger groups mean larger PRs, harder reviews, and more risk.
