import { LuaFactory, type LuaEngine } from 'wasmoon'

import ljsSource from '../../ljs.lua?raw'
import ljsParserSource from '../../ljs_parser.lua?raw'
import ljsTranspileSource from '../../ljs_transpile.lua?raw'
import ljsCodegenSource from '../../ljs_codegen.lua?raw'
import runtimeArraySource from '../../ljs_runtime/array.lua?raw'
import runtimeConsoleSource from '../../ljs_runtime/console.lua?raw'
import runtimeFunctionSource from '../../ljs_runtime/function.lua?raw'
import runtimeObjectSource from '../../ljs_runtime/object.lua?raw'
import runtimeProtoSource from '../../ljs_runtime/proto.lua?raw'

const factory = new LuaFactory()

let engine: LuaEngine | null = null

async function getEngine(): Promise<LuaEngine> {
  if (engine) return engine

  const e = await factory.createEngine()

  await factory.mountFile('ljs.lua', ljsSource)
  await factory.mountFile('ljs_parser.lua', ljsParserSource)
  await factory.mountFile('ljs_transpile.lua', ljsTranspileSource)
  await factory.mountFile('ljs_codegen.lua', ljsCodegenSource)
  await factory.mountFile('ljs_runtime/array.lua', runtimeArraySource)
  await factory.mountFile('ljs_runtime/console.lua', runtimeConsoleSource)
  await factory.mountFile('ljs_runtime/function.lua', runtimeFunctionSource)
  await factory.mountFile('ljs_runtime/object.lua', runtimeObjectSource)
  await factory.mountFile('ljs_runtime/proto.lua', runtimeProtoSource)

  await e.doString('require("ljs")')

  engine = e
  return engine
}

export async function transpile(source: string): Promise<{ code: string | null; error: string | null }> {
  const e = await getEngine()
  e.global.set('__ljs_input', source)
  const code = await e.doString(`
    local ljs = require("ljs")
    local code, err = ljs.transpile(__ljs_input)
    if code then
      return code
    else
      error(err)
    end
  `)
  return { code: code ?? null, error: null }
}

export interface RunResult {
  output: string[]
  result: unknown
  error: string | null
}

export async function run(source: string): Promise<RunResult> {
  const e = await getEngine()
  const logs: string[] = []

  e.global.getTable(1, (index: number) => {
    e.global.setField(index, 'print', (...args: unknown[]) => {
      logs.push(args.map((a) => String(a)).join('\t'))
    })
  })

  e.global.set('__ljs_input', source)

  try {
    const result = await e.doString(`
      local ljs = require("ljs")
      return ljs.run(__ljs_input)
    `)
    return { output: logs, result, error: null }
  } catch (err: unknown) {
    return { output: logs, result: null, error: err instanceof Error ? err.message : String(err) }
  }
}
