import { useMemo } from "react";
import CodeMirror from "@uiw/react-codemirror";
import type { Extension } from "@codemirror/state";
import { StreamLanguage } from "@codemirror/language";
import { lua } from "@codemirror/legacy-modes/mode/lua";
import { flexokiDark } from "../theme/flexoki";
import { vim } from "@replit/codemirror-vim";
import type { ParseError } from "../lib/ljs-core";
import { preambleFold } from "../lib/preamble-fold";

const cmSetup = {
  lineNumbers: true,
  highlightActiveLine: false,
  bracketMatching: true,
  foldGutter: false,
  highlightActiveLineGutter: false,
};

const luaLang = StreamLanguage.define(lua);

interface LuaOutputProps {
  code: string;
  error?: ParseError | null;
  preambleLines: number;
  vimMode: boolean;
}

export default function LuaOutput({ code, error, preambleLines, vimMode }: LuaOutputProps) {
  const extensions = useMemo(() => {
    const exts: Extension[] = [luaLang];
    if (preambleLines > 0) {
      exts.push(preambleFold(preambleLines));
    }
    if (vimMode) {
      exts.push(vim());
    }
    return exts;
  }, [preambleLines, vimMode]);

  return (
    <div className="h-full min-h-0">
      {error && (
        <div className="shrink-0 border-b border-base-850 px-3 py-1 text-xs text-red-400">
          {error.message}
          {error.line > 0 && (
            <span className="text-red-400/60">
              {" "}
              (line {error.line}, col {error.col})
            </span>
          )}
        </div>
      )}
      <CodeMirror
        className="h-full"
        value={code}
        height="100%"
        theme={flexokiDark}
        extensions={extensions}
        editable={false}
        basicSetup={cmSetup}
      />
    </div>
  );
}
