"use client";

import { Crown, UserMinus } from "lucide-react";
import { cn } from "@/lib/utils";
import type { GangMember } from "./types";

// Reference e1: one gang member row.
export function GangMemberRow({ m, onKick, disabled }: { m: GangMember; onKick?: () => void; disabled?: boolean }) {
  return (
    <li className="flex items-center gap-2 rounded-md bg-surface px-2 py-1.5">
      <span className={cn("h-1.5 w-1.5 shrink-0 rounded-full", m.online ? "bg-green-500" : "bg-muted-foreground/40")} title={m.online ? "Online" : "Offline"} />
      <span className="min-w-0 flex-1 truncate text-xs text-foreground">
        {m.name}
        {m.prestige > 0 && <span className="ml-1 font-mono text-[10px] font-bold text-amber-600 dark:text-amber-400">★{m.prestige}</span>}
      </span>
      <span className="shrink-0 font-mono text-[10px] text-muted-foreground">L{m.level}</span>
      {m.leader ? (
        <Crown className="h-3.5 w-3.5 shrink-0 text-amber-500" aria-label="Gang leader" />
      ) : onKick ? (
        <button type="button" disabled={disabled} onClick={onKick} className="shrink-0 text-muted-foreground transition hover:text-destructive disabled:opacity-40" aria-label={`Kick ${m.name}`}>
          <UserMinus className="h-3.5 w-3.5" />
        </button>
      ) : null}
    </li>
  );
}

// Reference e5: the gang XP bar.
export function GangXpBar({ level, xp, xpInto, xpNeeded, className }: { level: number; xp: number; xpInto: number; xpNeeded: number; className?: string }) {
  const i = xpNeeded > 0 ? Math.min(100, (xpInto / xpNeeded) * 100) : 100;
  return (
    <div className={className}>
      <div className="flex justify-between font-mono text-[10px] text-muted-foreground">
        <span>
          {"Gang XP "}
          {xp.toLocaleString()}
        </span>
        <span>{xpNeeded > 0 ? `${xpInto.toLocaleString()} / ${xpNeeded.toLocaleString()} to L${level + 1}` : "MAX"}</span>
      </div>
      <div className="mt-1 h-1.5 overflow-hidden rounded-full bg-muted">
        <div className="h-full rounded-full bg-primary transition-all" style={{ width: `${i}%` }} />
      </div>
    </div>
  );
}

// Reference e2: the two bonus chips.
export function GangBonusChips({ yieldBonus, xpBonus }: { yieldBonus: number; xpBonus: number }) {
  return (
    <>
      <span className="rounded bg-primary/10 px-1.5 py-0.5 font-mono text-[10px] font-semibold text-primary-emphasis">+{Math.round(100 * yieldBonus)}% yield for all members</span>
      <span className="rounded bg-primary/10 px-1.5 py-0.5 font-mono text-[10px] font-semibold text-primary-emphasis">+{Math.round(100 * xpBonus)}% XP for all members</span>
    </>
  );
}
