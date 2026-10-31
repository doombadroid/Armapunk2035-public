"use client";

import { useState } from "react";
import { Copy, Check } from "lucide-react";
import { toast } from "sonner";

export default function CopyButton({ value, label }: { value: string; label?: string }) {
  const [done, setDone] = useState(false);
  return (
    <button
      className="p-1 text-gray-500 hover:text-th-400 transition"
      title={label ?? "Copy"}
      onClick={async () => {
        try {
          await navigator.clipboard.writeText(value);
          setDone(true);
          toast.success(`${label ?? "Copied"}`);
          setTimeout(() => setDone(false), 1500);
        } catch {
          toast.error("Copy failed");
        }
      }}
    >
      {done ? <Check className="w-3 h-3 text-green-400" /> : <Copy className="w-3 h-3" />}
    </button>
  );
}
