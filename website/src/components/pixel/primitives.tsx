"use client";

import { cn } from "@/lib/utils";

// Reference U / _ / G / H / W: the progress bar, the titled panel, the stat cell and the empty note.

const BAR_TONES = {
  stamina: "bg-green-500",
  xp: "bg-primary",
  heat: "bg-red-500",
  weight: "bg-amber-500",
} as const;

export type BarTone = keyof typeof BAR_TONES;

export function Bar({ value, max, tone, className }: { value: number; max: number; tone: BarTone; className?: string }) {
  const n = max > 0 ? Math.max(0, Math.min(100, (value / max) * 100)) : 0;
  return (
    <div className={cn("h-1.5 w-full overflow-hidden rounded-full bg-muted", className)}>
      <div className={cn("h-full rounded-full transition-[width] duration-300", BAR_TONES[tone])} style={{ width: `${n}%` }} />
    </div>
  );
}

export function Panel({
  title,
  icon,
  right,
  children,
  className,
  bodyClassName,
}: {
  title?: React.ReactNode;
  icon?: React.ReactNode;
  right?: React.ReactNode;
  children?: React.ReactNode;
  className?: string;
  bodyClassName?: string;
}) {
  return (
    <section className={cn("rounded-xl border border-border bg-card", className)}>
      {null != title && (
        <header className="flex items-center gap-2 border-b border-border px-3 py-2">
          {icon}
          <h2 className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">{title}</h2>
          {null != right && <div className="ml-auto">{right}</div>}
        </header>
      )}
      <div className={cn("p-3", bodyClassName)}>{children}</div>
    </section>
  );
}

export function Stat({ label, value, tone, sub }: { label: React.ReactNode; value: React.ReactNode; tone?: string; sub?: React.ReactNode }) {
  return (
    <div className="min-w-0">
      <div className="truncate text-[10px] uppercase tracking-wide text-muted-foreground">{label}</div>
      <div className={cn("truncate font-mono text-sm font-semibold tabular-nums", tone ?? "text-foreground")}>{value}</div>
      {null != sub && <div className="truncate text-[10px] text-muted-foreground">{sub}</div>}
    </div>
  );
}

export function Empty({ children }: { children?: React.ReactNode }) {
  return <p className="px-1 py-6 text-center text-xs text-muted-foreground">{children}</p>;
}
