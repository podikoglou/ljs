import { useState, useLayoutEffect, useRef } from 'react'
import CodeMirror, { type ReactCodeMirrorRef } from '@uiw/react-codemirror'
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
  const cmRef = useRef<ReactCodeMirrorRef>(null)
  const [initialValue] = useState(code)

  useLayoutEffect(() => {
    const view = cmRef.current?.view
    if (!view) return
    if (view.state.doc.toString() === code) return
    view.dispatch({
      changes: { from: 0, to: view.state.doc.length, insert: code },
    })
  }, [code])

  return (
    <div className="flex min-h-0">
      <Panel label="Lua">
        <CodeMirror
          ref={cmRef}
          value={initialValue}
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
