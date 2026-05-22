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

interface LuaOutputProps {
  code: string
}

export default function LuaOutput({ code }: LuaOutputProps) {
  return (
    <div className="flex min-h-0">
      <Panel label="Lua">
        <CodeMirror
          value={code}
          height="100%"
          theme={flexokiDark}
          extensions={[StreamLanguage.define(lua)]}
          editable={false}
          basicSetup={cmSetup}
        />
      </Panel>
    </div>
  )
}
