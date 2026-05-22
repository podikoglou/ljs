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

export async function transpile(
  source: string,
): Promise<{ code: string | null; error: string | null }> {
  try {
    await getVM().setGlobal("__ljs_input", source);
    const code = await getVM().eval(`
      local ljs = require("ljs")
      local code, err = ljs.transpile(__ljs_input)
      if code then
        return code
      else
        error(err)
      end
    `);
    return { code: code ?? null, error: null };
  } catch (err: unknown) {
    return { code: null, error: err instanceof Error ? err.message : String(err) };
  }
}

export interface RunResult {
  output: string[];
  result: unknown;
  error: string | null;
}

export async function run(source: string): Promise<RunResult> {
  const logs = await getVM().overridePrint();
  await getVM().setGlobal("__ljs_input", source);

  try {
    const result = await getVM().eval(`
      local ljs = require("ljs")
      return ljs.run(__ljs_input)
    `);
    return { output: logs, result, error: null };
  } catch (err: unknown) {
    return { output: logs, result: null, error: err instanceof Error ? err.message : String(err) };
  }
}
