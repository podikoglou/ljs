---
name: ecma-query
description: Query the ECMAScript specification from the CLI. Use when you need to look up spec sections, abstract operations, built-in methods, grammar productions, or cross-references — e.g. "what does ToNumber do?", "show me the Promise.all algorithm", "find the spec for Array.prototype.map", "what calls IsCallable?", or "show me the grammar for ArrowFunction".
---

# ecma-query

CLI for looking up the ECMAScript spec. All output is markdown.

Bare `ecma-query <id>` is shorthand for `ecma-query get <id>`.

## Commands

### `get <id>` — exact entity lookup

Resolution order: section number (`7.1.4`) → anchor ID (`sec-toprimitive`) → abstract operation (`ToNumber`) → built-in method (`Array.prototype.map`) → internal slot (`[[Prototype]]`) → spec type (`PropertyDescriptor`). Operation names are case-insensitive and normalized (spaces/parens stripped).

```
ecma-query get ToNumber
ecma-query get Array.prototype.map
ecma-query get 7.1.4
ecma-query get sec-toprimitive
```

| Flag | Default | What it does |
|------|---------|--------------|
| `--max-tokens N` | 0 (off) | Truncate output at ~N tokens (heuristic: word count / 0.75) |

### `search <query>` — fuzzy find

Full-text search with ranked results and snippets. Tokens shorter than 3 chars and common stop words are silently excluded. Use when you don't know the exact name.

```
ecma-query search "promise"
ecma-query search "promise" --kind operation
ecma-query search "promise" --kind grammar --limit 5
```

| Flag | Default | What it does |
|------|---------|--------------|
| `--limit N` | 10 | Max results |
| `--kind` | (all) | Filter: `operation`, `method`, `section`, `type`, `grammar`, `slot` |

### `toc [section]` — spec tree navigation

Without args: top-level chapters. With a section number: children of that section.

```
ecma-query toc
ecma-query toc 27.2
```

| Flag | Default | What it does |
|------|---------|--------------|
| `--depth N` | 2 | Nesting levels to show |

### `xref <id>` — cross-references

Shows incoming and outgoing references. Same resolution and normalization as `get`.

```
ecma-query xref ToNumber
ecma-query xref IsCallable --direction incoming
```

| Flag | Default | What it does |
|------|---------|--------------|
| `--direction` | `both` | `incoming` (who references this), `outgoing` (what this references), `both` |

### `grammar <ProductionName>` — grammar productions

Case-sensitive. Use `search --kind grammar` to discover production names.

```
ecma-query grammar Identifier
```

## Workflow

1. **Don't know the exact name?** → `search <query>`
2. **Need the full spec?** → `get <id>`
3. **Output too long?** → add `--max-tokens N`
4. **Need to see references?** → `xref <id>`
5. **Need a grammar rule?** → `grammar <Name>`
6. **Need to browse structure?** → `toc [section]`

## Notes

- Operation names are normalized: `get tonumber` works the same as `get ToNumber`.
