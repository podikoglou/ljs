import type { ReactNode } from "react";
import CodeMirror from "@uiw/react-codemirror";
import { javascript } from "@codemirror/lang-javascript";
import { flexokiDark } from "../theme/flexoki";
import Button from "./button";

const cmSetup = {
  lineNumbers: true,
  highlightActiveLine: false,
  bracketMatching: true,
  foldGutter: false,
  highlightActiveLineGutter: false,
  closeBrackets: true,
  indentOnInput: true,
};

interface JsEditorProps {
  source: string;
  onSourceChange: (source: string) => void;
  ready: boolean;
  onRun: () => void;
  action?: ReactNode;
}

export default function JsEditor({ source, onSourceChange, ready, onRun, action }: JsEditorProps) {
  return (
    <div className="relative h-full min-h-0 border-r border-base-850">
      <CodeMirror
        className="h-full"
        value={source}
        height="100%"
        theme={flexokiDark}
        extensions={[javascript()]}
        onChange={onSourceChange}
        basicSetup={cmSetup}
      />
      <div className="absolute right-2 top-2">
        {action ?? (
          <Button disabled={!ready} onClick={onRun}>
            Run
          </Button>
        )}
      </div>
    </div>
  );
}
