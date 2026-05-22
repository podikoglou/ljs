import { describe, it, expect, beforeEach } from 'vitest'
import { transpile, run, setVM, type LuaVM, type RunResult } from './ljs-core'

class StubVM implements LuaVM {
  evalResult: unknown = null
  evalError: Error | null = null
  evalCalls: string[] = []
  globals: Record<string, unknown> = {}
  logs: string[] = []

  async eval(luaCode: string): Promise<unknown> {
    this.evalCalls.push(luaCode)
    if (this.evalError) throw this.evalError
    return this.evalResult
  }

  async setGlobal(name: string, value: unknown): Promise<void> {
    this.globals[name] = value
  }

  async overridePrint(): Promise<string[]> {
    return this.logs
  }
}

describe('transpile', () => {
  let stub: StubVM

  beforeEach(() => {
    stub = new StubVM()
    setVM(stub)
  })

  it('returns code on success', async () => {
    stub.evalResult = 'local x = 1'
    const result = await transpile('let x = 1')
    expect(result).toEqual({ code: 'local x = 1', error: null })
    expect(stub.globals['__ljs_input']).toBe('let x = 1')
  })

  it('returns error when eval throws', async () => {
    stub.evalError = new Error('parse failure')
    const result = await transpile('bad {')
    expect(result).toEqual({ code: null, error: 'parse failure' })
  })

  it('returns stringified non-Error throws', async () => {
    stub.evalError = 'raw string' as unknown as Error
    const result = await transpile('x')
    expect(result).toEqual({ code: null, error: 'raw string' })
  })
})

describe('run', () => {
  let stub: StubVM

  beforeEach(() => {
    stub = new StubVM()
    setVM(stub)
  })

  it('returns output and result on success', async () => {
    stub.evalResult = 42
    stub.logs = ['hello', 'world']
    const result: RunResult = await run('console.log("hello")')
    expect(result).toEqual({ output: ['hello', 'world'], result: 42, error: null })
    expect(stub.globals['__ljs_input']).toBe('console.log("hello")')
  })

  it('returns error when eval throws', async () => {
    stub.evalError = new Error('runtime boom')
    stub.logs = ['before crash']
    const result = await run('throw 1')
    expect(result.output).toEqual(['before crash'])
    expect(result.result).toBeNull()
    expect(result.error).toBe('runtime boom')
  })
})
