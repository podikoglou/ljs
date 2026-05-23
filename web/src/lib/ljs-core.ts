export interface LuaVM {
  eval(luaCode: string): Promise<unknown>;
  setGlobal(name: string, value: unknown): Promise<void>;
  overridePrint(): Promise<string[]>;
}

let vm: LuaVM | null = null;

export function setVM(adapter: LuaVM): void {
  vm = adapter;
}

export function getVM(): LuaVM {
  if (!vm) throw new Error("No LuaVM configured. Call setVM() or import ljs.ts first.");
  return vm;
}

export interface ParseError {
  message: string;
  line: number;
  col: number;
}

export interface TranspileResult {
  code: string | null;
  error: ParseError | null;
}

export async function transpile(source: string): Promise<TranspileResult> {
  try {
    await getVM().setGlobal("__ljs_input", source);
    const result = await getVM().eval(`
      local ljs = require("ljs")
      local code, err = ljs.transpile(__ljs_input)
      if code then
        return { code = code }
      else
        return { code = nil, error = { message = err.message, line = err.line, col = err.col } }
      end
    `);
    const table = result as Record<string, unknown> | null;
    if (table && typeof table["code"] === "string") {
      return { code: table["code"], error: null };
    }
    if (table && table["error"]) {
      const e = table["error"] as Record<string, unknown>;
      return {
        code: null,
        error: {
          message: String(e["message"] ?? "unknown error"),
          line: Number(e["line"] ?? 0),
          col: Number(e["col"] ?? 0),
        },
      };
    }
    return { code: null, error: null };
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    return { code: null, error: { message: msg, line: 0, col: 0 } };
  }
}

export interface RunResult {
  output: string[];
  result: unknown;
  error: ParseError | null;
}

export async function run(source: string): Promise<RunResult> {
  const logs = await getVM().overridePrint();
  await getVM().setGlobal("__ljs_input", source);

  try {
    const result = await getVM().eval(`
      local ljs = require("ljs")
      local ok, result = pcall(ljs.run, __ljs_input)
      if ok then
        return { result = result }
      else
        local err = result
        if type(err) == "table" and err.message then
          return { result = nil, error = { message = err.message, line = err.line, col = err.col } }
        else
          return { result = nil, error = { message = tostring(err), line = 0, col = 0 } }
        end
      end
    `);
    const table = result as Record<string, unknown> | null;
    if (table && table["error"]) {
      const e = table["error"] as Record<string, unknown>;
      return {
        output: logs,
        result: null,
        error: {
          message: String(e["message"] ?? "unknown error"),
          line: Number(e["line"] ?? 0),
          col: Number(e["col"] ?? 0),
        },
      };
    }
    return { output: logs, result: table?.["result"] ?? null, error: null };
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    return { output: logs, result: null, error: { message: msg, line: 0, col: 0 } };
  }
}
