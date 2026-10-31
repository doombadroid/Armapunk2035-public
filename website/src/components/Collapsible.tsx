"use client";

import { useState } from "react";
import { ChevronDown } from "lucide-react";

export default function Collapsible({
  title, icon, count, right, defaultOpen = false, children,
}: {
  title: string;
  icon?: React.ReactNode;
  count?: number;
  right?: React.ReactNode;
  defaultOpen?: boolean;
  children: React.ReactNode;
}) {
  const [open, setOpen] = useState(defaultOpen);
  return (
    <div className="bg-gray-900 border border-th-700/30 rounded-xl overflow-hidden">
      <button
        onClick={() => setOpen((o) => !o)}
        className="w-full flex items-center justify-between px-5 py-4 hover:bg-gray-800/30 transition"
      >
        <div className="flex items-center gap-2.5">
          {icon}
          <span className="text-sm font-bold text-th-400 uppercase tracking-widest">{title}</span>
          {count !== undefined && <span className="text-xs text-gray-500">({count})</span>}
        </div>
        <div className="flex items-center gap-3">
          {right}
          <ChevronDown className={`w-4 h-4 text-gray-500 transition-transform ${open ? "rotate-180" : ""}`} />
        </div>
      </button>
      {open && <div className="border-t border-gray-800">{children}</div>}
    </div>
  );
}
