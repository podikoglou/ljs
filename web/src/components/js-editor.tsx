import type { ReactNode } from 'react'
import CodeMirror from '@uiw/react-codemirror'
import { javascript } from '@codemirror/lang-javascript'
import { flexokiDark } from '../theme/flexoki'
import Panel from './panel'

const cmSetup = {
  lineNumbers: true,
  highlightActiveLine: false,
  bracketMatching: true,
  foldGutter: false,
  highlightActiveLineGutter: false,
  closeBrackets: true,
  indentOnInput: true,
}

interface JsEditorProps {
  source: string
  onSourceChange: (source: string) => void
  ready: boolean
  onRun: () => void
  error?: string | null
  action?: ReactNode
}

export default function JsEditor({ source, onSourceChange, ready, onRun, action }: JsEditorProps) {
  return (
    <div className="flex min-h-0 border-r border-base-850">
      <Panel
        label="JavaScript"
        action={
          action ?? (
            <button
              type="button"
              disabled={!ready}
              onClick={onRun}
              className="bg-base-850 px-3 py-0.5 text-xs text-base-300 hover:text-base-200 disabled:opacity-50"
            >
              Run
            </button>
          )
        }
      >
        <CodeMirror
          className="h-full"
          value={source}
          height="100%"
          theme={flexokiDark}
          extensions={[javascript()]}
          onChange={onSourceChange}
          basicSetup={cmSetup}
        />
      </Panel>
    </div>
  )
}
