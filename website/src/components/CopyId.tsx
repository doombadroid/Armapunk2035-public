"use client";

import { useState } from "react";
import { Copy, Check } from "lucide-react";

/** Small copy-to-clipboard button for a Steam/Player ID. */
export default function CopyId({ value }: { value: string }) {
  const [done, setDone] = useState(false);
  return (
    <button
      type="button"
      title="Copy Player ID"
      onClick={async () => {
        try {
          await navigator.clipboard.writeText(value);
          setDone(true);
          setTimeout(() => setDone(false), 1200);
        } catch { /* clipboard blocked — no-op */ }
      }}
      className="p-1 text-gray-500 hover:text-gray-300 transition"
    >
      {done ? <Check className="w-3.5 h-3.5 text-green-400" /> : <Copy className="w-3.5 h-3.5" />}
    </button>
  );
}
