import type { ReactNode } from "react";

import { cn } from "@/lib/utils";

export function Chip({
  children,
  tone = "neutral"
}: {
  children: ReactNode;
  tone?: "neutral" | "green" | "amber" | "red";
}) {
  return (
    <span
      className={cn(
        "inline-flex items-center rounded-full px-2.5 py-1 text-xs font-medium",
        tone === "neutral" && "bg-sand text-ink",
        tone === "green" && "bg-emerald-100 text-emerald-800",
        tone === "amber" && "bg-amber-100 text-amber-800",
        tone === "red" && "bg-rose-100 text-rose-800",
      )}
    >
      {children}
    </span>
  );
}
