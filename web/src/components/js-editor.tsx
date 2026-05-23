import { useCallback, useEffect, useRef, useMemo } from "react";
import CodeMirror from "@uiw/react-codemirror";
import { javascript } from "@codemirror/lang-javascript";
import { keymap, type EditorView } from "@codemirror/view";
import { Prec } from "@codemirror/state";
import { lintGutter, setDiagnostics } from "@codemirror/lint";
import { flexokiDark } from "../theme/flexoki";
import type { ParseError } from "../lib/ljs-core";

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
  error: ParseError | null;
}

function errorToDiagnostic(error: ParseError, doc: string) {
  if (error.line <= 0 && error.col <= 0) return null;
  const lines = doc.split("\n");
  const lineIdx = Math.min(error.line - 1, lines.length - 1);
  const line = lines[lineIdx] ?? "";
  const col = Math.max(0, Math.min(error.col - 1, line.length));
  const from = lines.slice(0, lineIdx).reduce((acc, l) => acc + l.length + 1, 0) + col;
  const to = Math.min(from + 1, doc.length);
  return { from, to, severity: "error" as const, message: error.message };
}

export default function JsEditor({ source, onSourceChange, onRun, error }: JsEditorProps) {
  const viewRef = useRef<EditorView | null>(null);

  const extensions = useMemo(
    () => [
      javascript(),
      lintGutter(),
      Prec.high(
        keymap.of([
          {
            key: "Mod-Enter",
            preventDefault: true,
            run() {
              onRun();
              return true;
            },
          },
        ]),
      ),
    ],
    [onRun],
  );

  const onCreateEditor = useCallback((view: EditorView) => {
    viewRef.current = view;
  }, []);

  useEffect(() => {
    const view = viewRef.current;
    if (!view) return;
    const diag = error ? errorToDiagnostic(error, source) : null;
    const diags = diag ? [diag] : [];
    view.dispatch(setDiagnostics(view.state, diags));
  }, [error, source]);

  return (
    <div className="h-full min-h-0 border-r border-base-850">
      <CodeMirror
        className="h-full"
        value={source}
        height="100%"
        theme={flexokiDark}
        extensions={extensions}
        onCreateEditor={onCreateEditor}
        onChange={onSourceChange}
        basicSetup={cmSetup}
      />
    </div>
  );
}
