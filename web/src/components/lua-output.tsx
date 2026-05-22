import CodeMirror from '@uiw/react-codemirror'
import { StreamLanguage } from '@codemirror/language'
import { lua } from '@codemirror/legacy-modes/mode/lua'
import { flexokiDark } from '../theme/flexoki'
import Panel from './panel'

const cmSetup = {
  lineNumbers: true,
  highlightActiveLine: false,
  bracketMatching: true,
  foldGutter: false,
  highlightActiveLineGutter: false,
}

const luaExtensions = [StreamLanguage.define(lua)]

interface LuaOutputProps {
  code: string
  error?: string | null
}

export default function LuaOutput({ code, error }: LuaOutputProps) {
  return (
    <div className="flex min-h-0">
      <Panel label="Lua">
        {error && (
          <div className="shrink-0 border-b border-base-850 bg-base-950 px-3 py-1 text-xs text-red-400">
            {error}
          </div>
        )}
        <CodeMirror
          className="h-full"
          value={code}
          height="100%"
          theme={flexokiDark}
          extensions={luaExtensions}
          editable={false}
          basicSetup={cmSetup}
        />
      </Panel>
    </div>
  )
}
