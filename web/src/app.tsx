import { useCallback, useEffect, useRef, useState } from "react";
import { Allotment } from "allotment";
import { useHotkeys } from "react-hotkeys-hook";
import "allotment/dist/style.css";
import { transpile, run, type RunResult, type ParseError } from "./lib/ljs";
import JsEditor from "./components/js-editor";
import LuaOutput from "./components/lua-output";
import Console, { useTerminal } from "./components/console";
import Button from "./components/button";

const DEFAULT_CODE = `function greet(name) {
  return "Hello, " + name + "!";
}

console.log(greet("world"));
console.log(1 + 2);
`;

function loadSizes(key: string, fallback: number[]) {
  try {
    const saved = localStorage.getItem(key);
    return saved ? JSON.parse(saved) : fallback;
  } catch {
    return fallback;
  }
}

function saveSizes(key: string, sizes: number[]) {
  localStorage.setItem(key, JSON.stringify(sizes));
}

export default function App() {
  const [jsSource, setJsSource] = useState(DEFAULT_CODE);
  const [luaOutput, setLuaOutput] = useState("");
  const [transpileError, setTranspileError] = useState<ParseError | null>(null);
  const [ready, setReady] = useState(false);
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const { ref: termRef, write: termWrite } = useTerminal();

  useEffect(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(() => {
      transpile(jsSource).then((result) => {
        if (result.code !== null) {
          setLuaOutput(result.code);
          setTranspileError(null);
        } else {
          setLuaOutput("");
          setTranspileError(result.error);
        }
        setReady(true);
      });
    }, 150);
    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
    };
  }, [jsSource]);

  const handleRun = useCallback(() => {
    termWrite("\x1b[2J\x1b[H");
    run(jsSource).then((result: RunResult) => {
      if (result.output.length > 0) {
        termWrite(result.output.join("\r\n") + "\r\n");
      }
      if (result.error) {
        termWrite(`\x1b[31m${result.error.message}\x1b[0m\r\n`);
      }
    });
  }, [jsSource, termWrite]);

  useHotkeys(
    "ctrl+enter",
    handleRun,
    { enabled: false, enableOnFormTags: true, enableOnContentEditable: true },
    [handleRun],
  );

  return (
    <div className="flex h-full flex-col">
      <div className="flex shrink-0 items-center border-b border-base-850 px-3 py-0.5">
        <Button disabled={!ready} onClick={handleRun}>
          Run
        </Button>
      </div>
      <div className="min-h-0 flex-1">
        <Allotment
          vertical
          defaultSizes={loadSizes("allotment-vertical", [70, 30])}
          onChange={(s) => saveSizes("allotment-vertical", s)}
        >
          <Allotment
            defaultSizes={loadSizes("allotment-horizontal", [50, 50])}
            onChange={(s) => saveSizes("allotment-horizontal", s)}
          >
            <JsEditor
              source={jsSource}
              onSourceChange={setJsSource}
              onRun={handleRun}
              error={transpileError}
            />
            <LuaOutput code={luaOutput} error={transpileError} />
          </Allotment>
          <Console terminalRef={termRef} />
        </Allotment>
      </div>
    </div>
  );
}
