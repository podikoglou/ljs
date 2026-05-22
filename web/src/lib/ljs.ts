export { transpile, run, setVM, type LuaVM, type RunResult } from './ljs-core'
export { WasmoonAdapter } from './wasmoon-adapter'

import { setVM } from './ljs-core'
import { WasmoonAdapter } from './wasmoon-adapter'

setVM(new WasmoonAdapter())
