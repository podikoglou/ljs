interface ConsoleProps {
  lines: string[];
  error: string | null;
}

export default function Console({ lines, error }: ConsoleProps) {
  return (
    <div className="flex h-full min-h-0 flex-col">
      <div className="shrink-0 border-b border-base-850 px-3 py-1">
        <span className="text-xs text-base-400">Console</span>
      </div>
      <div className="min-h-0 flex-1 overflow-auto p-3 font-mono text-xs leading-relaxed text-base-300">
        {error && <div className="text-red-400">{error}</div>}
        {lines.map((line, i) => (
          <div key={i}>{line}</div>
        ))}
      </div>
    </div>
  );
}
