"use client";

import { ReactNode } from "react";

interface CodeWindowProps {
  title?: string;
  children: ReactNode;
  className?: string;
}

export function CodeWindow({ title = "code.js", children, className = "" }: CodeWindowProps) {
  return (
    <div
      className={`rounded-xl border border-white/[0.06] bg-[#0a0a0a] overflow-hidden ${className}`}
    >
      {/* Title bar */}
      <div className="flex items-center gap-2 px-4 py-3 border-b border-white/[0.06] bg-white/[0.02]">
        <div className="flex gap-1.5">
          <span className="h-3 w-3 rounded-full bg-white/10" />
          <span className="h-3 w-3 rounded-full bg-white/10" />
          <span className="h-3 w-3 rounded-full bg-white/10" />
        </div>
        <span className="ml-2 text-xs text-white/30 font-mono">{title}</span>
      </div>
      {/* Code content */}
      <div className="p-4 sm:p-6 overflow-x-auto">
        <pre className="text-sm leading-relaxed font-mono">{children}</pre>
      </div>
    </div>
  );
}
