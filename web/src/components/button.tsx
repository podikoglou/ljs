import type { ButtonHTMLAttributes, ReactNode } from "react";

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  children: ReactNode;
}

export default function Button({ children, className = "", ...props }: ButtonProps) {
  return (
    <button
      type="button"
      className={`bg-primary/15 px-3 py-1 text-xs text-primary hover:bg-primary/25 disabled:opacity-50${className ? ` ${className}` : ""}`}
      {...props}
    >
      {children}
    </button>
  );
}
