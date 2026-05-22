import { Terminal, useTerminal, type TerminalHandle } from "@wterm/react";
import "@wterm/react/css";
import "../theme/wterm-flexoki.css";

export { useTerminal, type TerminalHandle };

interface ConsoleProps {
  terminalRef: React.RefObject<TerminalHandle | null>;
}

export default function Console({ terminalRef }: ConsoleProps) {
  return (
    <Terminal
      ref={terminalRef}
      autoResize
      onData={() => {}}
      className="theme-flexoki"
      style={{ height: "100%" }}
    />
  );
}
