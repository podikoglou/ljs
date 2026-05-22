import Panel from "./panel";

interface ConsoleProps {
  lines: string[];
  error: string | null;
}

export default function Console({ lines, error }: ConsoleProps) {
  return (
    <Panel label="Console" className="col-span-2 h-[30vh] shrink-0 border-t border-base-850">
      <div className="h-full overflow-auto whitespace-pre-wrap bg-base-950 p-3 font-mono text-xs leading-relaxed text-base-300">
        {error && <div className="text-red-400">{error}</div>}
        {lines.join("\n")}
      </div>
    </Panel>
  );
}
