interface ConsoleProps {
  lines: string[];
  error: string | null;
}

export default function Console({ lines, error }: ConsoleProps) {
  return (
    <div className="h-full min-h-0 overflow-auto p-3 font-mono text-xs leading-relaxed text-base-300">
      {error && <div className="text-red-400">{error}</div>}
      {lines.map((line, i) => (
        <div key={i}>{line}</div>
      ))}
    </div>
  );
}
