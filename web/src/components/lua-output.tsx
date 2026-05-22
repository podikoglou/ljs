import CodeMirror from "@uiw/react-codemirror";
import { StreamLanguage } from "@codemirror/language";
import { lua } from "@codemirror/legacy-modes/mode/lua";
import { flexokiDark } from "../theme/flexoki";

const cmSetup = {
  lineNumbers: true,
  highlightActiveLine: false,
  bracketMatching: true,
  foldGutter: false,
  highlightActiveLineGutter: false,
};

const luaExtensions = [StreamLanguage.define(lua)];

interface LuaOutputProps {
  code: string;
  error?: string | null;
}

export default function LuaOutput({ code, error }: LuaOutputProps) {
  return (
    <div className="h-full min-h-0">
      {error && (
        <div className="shrink-0 border-b border-base-850 px-3 py-1 text-xs text-red-400">
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
    </div>
  );
}
