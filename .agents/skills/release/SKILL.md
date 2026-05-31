---
name: release
description: Perform a versioned release for ljs. Merges develop into main, tags, creates GitHub release with notes, and uploads rockspec. Use when the user says "release", "cut a release", "make a release", or "ship a version".
---

# Release

## Assess scope

Before any release work, determine whether a release is warranted and what version to use.

1. Run `git tag -l 'v*' --sort=-v:refname | head -5` to find the latest tag
2. Run `git log v<PREV>..HEAD --oneline | wc -l` for commit count since last release
3. Run `git log v<PREV>..HEAD --oneline | grep "feat"` for feature count
4. Compare scope against previous releases (e.g. `git log v0.1.0..v0.2.0 --oneline | wc -l`) to judge whether this is minor, patch, or not yet enough
5. Present summary to user and ask: should we release? what version?

## Pre-flight checks

Run these **before** starting any release work. Stop and report if anything fails.

1. **Working tree clean**: `git status --short` must be empty
2. **On develop**: `git branch --show-current` must be `develop`
3. **Tests pass**: `make test`
4. **Wasmoon adapter up to date**: compare `ls src/ljs/runtime/` against runtime imports in `web/src/lib/wasmoon-adapter.ts`. Every `.lua` file in `src/ljs/runtime/` must be imported and mounted. Also check `rockspec/ljs-*.rockspec` has the same modules.

## Draft release notes

1. Run `git log v<PREV>..HEAD --oneline` to collect changes
2. Categorize commits into: **features**, **spec compliance fixes**, **performance**, **infrastructure**
3. Group features by subsystem (e.g. Runtime, Scoping, Object, Array, Number, Console)
4. Get commit/PR counts: `git log v<PREV>..HEAD --oneline | wc -l`
5. Get test count from `make test` output
6. **Present draft to user for approval before proceeding**

## Release procedure

Execute these steps in order. Commit after each atomic change.

### 1. Create rockspec

```bash
cp rockspec/ljs-<PREV>-1.rockspec rockspec/ljs-<NEW>-1.rockspec
```

Edit the new rockspec:
- `version = "<NEW>-1"`
- `tag = "v<NEW>"`
- Ensure all runtime modules are listed in `build.modules`

Commit: `chore: add rockspec for v<NEW>`

### 2. Merge into main

```bash
git checkout main
git merge develop --no-ff -m "Release <NEW>"
```

### 3. Tag

```bash
git tag -a v<NEW> -m "Release <NEW>"
```

### 4. Push everything

```bash
git push origin main
git push origin v<NEW>
git push origin develop
```

### 5. Create GitHub release

```bash
gh release create v<NEW> \
  --title "v<NEW>" \
  --notes '<APPROVED_NOTES>'
```

### 6. Return to develop

```bash
git checkout develop
```

## Rollback

If anything fails after the tag is pushed:
```bash
git tag -d v<NEW>
git push origin :refs/tags/v<NEW>
```
Then reset main: `git checkout main && git reset --hard origin/main`

## Notes

- Do NOT upload to LuaRocks (not configured)
- Do NOT attach rockspec to the GitHub release
- If wasmoon adapter or rockspec is missing modules, fix on develop first and commit before the merge
- Follow the release notes format from v0.2.0 and v0.3.0 for consistency
