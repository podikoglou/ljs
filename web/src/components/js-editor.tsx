import CodeMirror from "@uiw/react-codemirror";
import { javascript } from "@codemirror/lang-javascript";
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
}

export default function JsEditor({ source, onSourceChange }: JsEditorProps) {
  return (
    <div className="h-full min-h-0 border-r border-base-850">
      <CodeMirror
        className="h-full"
        value={source}
        height="100%"
        theme={flexokiDark}
        extensions={[javascript()]}
        onChange={onSourceChange}
        basicSetup={cmSetup}
      />
    </div>
  );
}
