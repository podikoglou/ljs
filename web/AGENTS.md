Try ljs — browser playground for the ljs Lua JS Toolkit.

Uses bun. Build: `bun run build`. Lint: `bun run lint`.

Commits should be scoped to `web` (example: `chore(web): ...`)

## Architecture

Single wasmoon VM loads ljs Lua modules at startup via `factory.mountFile`. Lua source
files are imported as raw strings from the parent repo using Vite's `?raw` with the `@ljs`
path alias (resolves to repo root). Transpilation and execution happen client-side in the
same VM — `ljs.transpile()` for the Lua output panel, `ljs.run()` for execution.

## Layout

Three-panel grid — JS editor (left) | Lua output (right) on top, full-width console below.
JS editor is live with 300ms debounce. Run button executes via wasmoon. Lua panel is
read-only. All panels use the shared `Panel` component for consistent headers.

## Style

Dark mode only. Flexoki palette (MIT, attributed in `index.css` and `flexoki.ts`) defined
as Tailwind theme variables. No decoration — no rounded corners, gradients, or glow effects.
JetBrains Mono for everything. kebab-case filenames. No hardcoded hex colors in components.

## CodeMirror

Theme is `src/theme/flexoki.ts`. JS uses `@codemirror/lang-javascript`, Lua uses the
legacy StreamLanguage mode. Built on `@uiw/react-codemirror`.
