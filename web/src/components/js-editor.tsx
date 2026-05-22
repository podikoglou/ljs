import type { ReactNode } from "react";
import CodeMirror from "@uiw/react-codemirror";
import { javascript } from "@codemirror/lang-javascript";
import { EditorView } from "@codemirror/view";
import { flexokiDark } from "../theme/flexoki";
import Panel from "./panel";
import Button from "./button";

const scrollbar = EditorView.theme({
  ".cm-scroller": { overflow: "auto" },
});

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
    <Panel
      label="JavaScript"
      className="min-h-0 border-r border-base-850"
      action={
        action ?? (
          <Button disabled={!ready} onClick={onRun}>
            Run
          </Button>
        )
      }
    >
      <CodeMirror
        className="h-full"
        value={source}
        height="100%"
        theme={flexokiDark}
        extensions={[javascript(), scrollbar]}
        onChange={onSourceChange}
        basicSetup={cmSetup}
      />
    </Panel>
  );
}
