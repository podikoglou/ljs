import type { ReactNode } from "react";

interface PanelProps {
  label: string;
  action?: ReactNode;
  children: ReactNode;
  className?: string;
}

export default function Panel({ label, action, children, className }: PanelProps) {
  return (
    <div className={`flex min-h-0 flex-col${className ? ` ${className}` : ""}`}>
      <div className="flex shrink-0 items-center justify-between border-b border-base-850 px-3 py-1">
        <span className="text-xs text-base-400">{label}</span>
        {action}
      </div>
      <div className="min-h-0 flex-1 overflow-hidden">{children}</div>
    </div>
  );
}
