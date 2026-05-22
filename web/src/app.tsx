import { useCallback, useEffect, useRef, useState } from "react";
import { transpile, run, type RunResult } from "./lib/ljs";
import JsEditor from "./components/js-editor";
import LuaOutput from "./components/lua-output";
import Console from "./components/console";

const DEFAULT_CODE = `function greet(name) {
  return "Hello, " + name + "!";
}

console.log(greet("world"));
console.log(1 + 2);
`;

export default function App() {
  const [jsSource, setJsSource] = useState(DEFAULT_CODE);
  const [luaOutput, setLuaOutput] = useState("");
  const [consoleOutput, setConsoleOutput] = useState<string[]>([]);
  const [transpileError, setTranspileError] = useState<string | null>(null);
  const [runError, setRunError] = useState<string | null>(null);
  const [ready, setReady] = useState(false);
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);

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
    }, 300);
    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
    };
  }, [jsSource]);

  const handleRun = useCallback(() => {
    setConsoleOutput([]);
    run(jsSource).then((result: RunResult) => {
      setConsoleOutput(result.output);
      if (result.error) setRunError(result.error);
      else setRunError(null);
    });
  }, [jsSource]);

  return (
    <div className="grid h-full grid-cols-2 grid-rows-[1fr_auto]">
      <JsEditor source={jsSource} onSourceChange={setJsSource} ready={ready} onRun={handleRun} />
      <LuaOutput code={luaOutput} error={transpileError} />
      <Console error={runError} lines={consoleOutput} />
    </div>
  );
}
