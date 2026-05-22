import CodeMirror from "@uiw/react-codemirror";
import { javascript } from "@codemirror/lang-javascript";
import { keymap, type EditorView } from "@codemirror/view";
import { Prec } from "@codemirror/state";
import { flexokiDark } from "../theme/flexoki";

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
  onRun: () => void;
}

export default function JsEditor({ source, onSourceChange, onRun }: JsEditorProps) {
  return (
    <div className="h-full min-h-0 border-r border-base-850">
      <CodeMirror
        className="h-full"
        value={source}
        height="100%"
        theme={flexokiDark}
        extensions={[
          javascript(),
          Prec.high(
            keymap.of([
              {
                key: "Mod-Enter",
                preventDefault: true,
                run(_view: EditorView) {
                  onRun();
                  return true;
                },
              },
            ]),
          ),
        ]}
        onChange={onSourceChange}
        basicSetup={cmSetup}
      />
    </div>
  );
}
