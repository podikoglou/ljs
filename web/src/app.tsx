import { useCallback, useEffect, useRef, useState } from 'react'
import CodeMirror from '@uiw/react-codemirror'
import { javascript } from '@codemirror/lang-javascript'
import { StreamLanguage } from '@codemirror/language'
import { lua } from '@codemirror/legacy-modes/mode/lua'
import { flexokiDark } from './theme/flexoki'
import { transpile, run, type RunResult } from './lib/ljs'
import Panel from './components/panel'

const DEFAULT_CODE = `function greet(name) {
  return "Hello, " + name + "!";
}

console.log(greet("world"));
console.log(1 + 2);
`

const cmSetup = {
  lineNumbers: true,
  highlightActiveLine: false,
  bracketMatching: true,
  foldGutter: false,
  highlightActiveLineGutter: false,
}

export default function App() {
  const [jsSource, setJsSource] = useState(DEFAULT_CODE)
  const [luaOutput, setLuaOutput] = useState('')
  const [consoleOutput, setConsoleOutput] = useState<string[]>([])
  const [error, setError] = useState<string | null>(null)
  const [ready, setReady] = useState(false)
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null)

  useEffect(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current)
    debounceRef.current = setTimeout(() => {
      transpile(jsSource)
        .then((result) => {
          if (result.code !== null) {
            setLuaOutput(result.code)
            setError(null)
          } else {
            setLuaOutput('')
            setError(result.error)
          }
          setReady(true)
        })
        .catch((err: unknown) => {
          setError(err instanceof Error ? err.message : String(err))
          setReady(true)
        })
    }, 300)
    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current)
    }
  }, [jsSource])

  const handleRun = useCallback(() => {
    setConsoleOutput([])
    run(jsSource).then((result: RunResult) => {
      setConsoleOutput(result.output)
      if (result.error) setError(result.error)
      else setError(null)
    })
  }, [jsSource])

  return (
    <div className="grid h-full grid-cols-2 grid-rows-[1fr_auto]">
      <div className="flex min-h-0 border-r border-base-850">
        <Panel
          label="JavaScript"
          action={
            <button
              type="button"
              disabled={!ready}
              onClick={handleRun}
              className="bg-base-850 px-3 py-0.5 text-xs text-base-300 hover:text-base-200 disabled:opacity-50"
            >
              Run
            </button>
          }
        >
          <CodeMirror
            value={jsSource}
            height="100%"
            theme={flexokiDark}
            extensions={[javascript()]}
            onChange={setJsSource}
            basicSetup={{ ...cmSetup, closeBrackets: true, indentOnInput: true }}
          />
        </Panel>
      </div>
      <div className="flex min-h-0">
        <Panel label="Lua">
          <CodeMirror
            value={luaOutput}
            height="100%"
            theme={flexokiDark}
            extensions={[StreamLanguage.define(lua)]}
            editable={false}
            basicSetup={cmSetup}
          />
        </Panel>
      </div>
      <div className="col-span-2 flex min-h-[160px] flex-col border-t border-base-850">
        <div className="shrink-0 border-b border-base-850 px-3 py-1">
          <span className="text-xs text-base-400">Console</span>
        </div>
        <div className="flex-1 overflow-auto bg-base-950 p-3 font-mono text-xs leading-relaxed text-base-300">
          {error && <div className="text-red-400">{error}</div>}
          {consoleOutput.map((line, i) => (
            <div key={i}>{line}</div>
          ))}
        </div>
      </div>
    </div>
  )
}
