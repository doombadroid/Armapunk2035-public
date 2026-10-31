"use client";

import { AlertTriangle, Backpack, Banknote, FlaskConical, Gavel, ScrollText, Shield, Truck, User, Zap } from "lucide-react";
import { cn } from "@/lib/utils";
import { fmtCompact, fmtMoney, fmtSecs } from "./format";
import { Bar, Stat } from "./primitives";
import type { City, Item, Me } from "./types";

// Reference Y: the player HUD card (identity, cash, stamina, load, heat/duty, location, bag strip,
// custody / travel banner).
export function PlayerCard({
  me,
  city,
  clock,
  wantedAt,
  itemMap,
  onRelease,
}: {
  me: Me;
  city: City | undefined;
  clock: number;
  wantedAt: number;
  itemMap: Record<string, Item>;
  onRelease: () => void;
}) {
  const l = me.jailedUntil > clock,
    o = me.travelUntil > clock,
    d = "cop" === me.faction,
    c = Math.min(100, (me.heat / 100) * 100),
    m = me.capacity > 0 && me.carried >= me.capacity,
    x = Object.entries(me.inventory)
      .filter(([, e]) => e > 0)
      .map(([e, t]) => ({
        id: e,
        qty: t,
        item: itemMap[e],
      }))
      .filter((e) => e.item)
      .sort((e, t) => t.qty * t.item.weight - e.qty * e.item.weight),
    u = !d && (me.papers > 0 || me.processPapers > 0);
  return (
    <div className="rounded-xl border border-border bg-card shadow-sm">
      <div className="flex flex-wrap items-center gap-x-5 gap-y-3 p-3">
        <div className="flex min-w-0 items-center gap-2.5">
          {me.avatarUrl ? (
            // eslint-disable-next-line @next/next/no-img-element -- reference renders a plain <img>
            <img src={me.avatarUrl} alt="" className="h-9 w-9 shrink-0 rounded-md border border-border" />
          ) : (
            <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-md border border-border bg-surface">
              <User className="h-4 w-4 text-muted-foreground" />
            </div>
          )}
          <div className="min-w-0">
            <div className="flex items-center gap-1.5">
              <span className="truncate text-sm font-semibold text-foreground">{me.name}</span>
              <span
                className={cn(
                  "shrink-0 rounded px-1.5 py-0.5 text-[10px] font-semibold uppercase tracking-wide",
                  d ? "bg-blue-500/15 text-blue-700 dark:text-blue-300" : "bg-muted text-foreground-secondary",
                )}
              >
                {d ? "APD" : "Civilian"}
              </span>
            </div>
            <div className="mt-1 flex items-center gap-2">
              <span className="font-mono text-[10px] text-muted-foreground">
                {"LVL "}
                {me.level}
              </span>
              {me.prestige > 0 && (
                <span className="font-mono text-[10px] font-bold text-amber-600 dark:text-amber-400" title={`${d ? "APD" : "Civilian"} Prestige ${me.prestige} — career star perks`}>
                  ★{me.prestige}
                </span>
              )}
              <Bar value={me.xpInto} max={me.xpNeeded} tone="xp" className="w-20" />
            </div>
          </div>
        </div>
        <div className="h-9 w-px bg-border" aria-hidden={true} />
        <Stat label="Cash" value={<span className="text-green-600 dark:text-green-400">{fmtCompact(me.cash)}</span>} sub={fmtMoney(me.cash)} />
        <Stat label="Net worth" value={fmtCompact(me.netWorth)} />
        <div className="min-w-[104px]">
          <div className="flex items-center gap-1 text-[10px] uppercase tracking-wide text-muted-foreground">
            <Zap className="h-3 w-3" />
            {" Stamina"}
          </div>
          <div className="font-mono text-sm font-semibold tabular-nums">
            {me.stamina}
            <span className="text-muted-foreground">/{me.staminaMax}</span>
          </div>
          <Bar value={me.stamina} max={me.staminaMax} tone="stamina" className="mt-1" />
          <div className="mt-0.5 font-mono text-[10px] text-muted-foreground" title="Stamina regenerated per second, Endurance and Second Wind included.">
            +{me.staminaRegen.toFixed(2)}/s
          </div>
        </div>
        <div className="min-w-[104px]">
          <div className="flex items-center gap-1 text-[10px] uppercase tracking-wide text-muted-foreground">
            <Truck className="h-3 w-3" />
            {" Load"}
          </div>
          <div className={cn("font-mono text-sm font-semibold tabular-nums", m ? "text-red-600 dark:text-red-400" : "text-foreground")}>
            {me.carried}
            <span className={m ? "" : "text-muted-foreground"}>/{me.capacity}kg</span>
          </div>
          <Bar value={me.carried} max={me.capacity} tone="weight" className="mt-1" />
          {m && <div className="mt-0.5 text-[10px] font-semibold uppercase text-red-600 dark:text-red-400">Pack full</div>}
        </div>
        {d ? (
          <div className="min-w-[104px]">
            <div className="flex items-center gap-1 text-[10px] uppercase tracking-wide text-muted-foreground">
              <Shield className="h-3 w-3" />
              {" Duty"}
            </div>
            <div className="font-mono text-sm font-semibold text-blue-700 tabular-nums dark:text-blue-300">On patrol</div>
            <div className="mt-1 text-[10px] text-muted-foreground">Salary accruing</div>
          </div>
        ) : (
          <div className="min-w-[104px]">
            <div className="flex items-center gap-1 text-[10px] uppercase tracking-wide text-muted-foreground">
              <AlertTriangle className="h-3 w-3" />
              {" Heat"}
            </div>
            <div className={cn("font-mono text-sm font-semibold tabular-nums", me.wanted ? "text-red-600 dark:text-red-400" : "text-foreground")}>
              {me.heat.toFixed(1)}
              {me.wanted && <span className="ml-1 text-[10px] uppercase">Wanted</span>}
            </div>
            <Bar value={c} max={100} tone="heat" className="mt-1" />
            <div className="mt-0.5 text-[10px] text-muted-foreground">
              {"APD sees you at "}
              {wantedAt}
            </div>
            {me.bustEstimate.bounty > 0 && (
              <div
                className="mt-0.5 text-[10px] text-muted-foreground"
                title="The low end includes the maximum repeat-arrest reduction; the high end is the hard worst case for a fully-built officer."
              >
                Bust risk: ~{fmtCompact(me.bustEstimate.fine)}–{fmtCompact(me.bustEstimate.fineCeiling)}
                {" fine ·"}
                {" "}~{fmtCompact(me.bustEstimate.bounty)}–{fmtCompact(me.bustEstimate.bountyCeiling)}
                {" to APD"}
              </div>
            )}
          </div>
        )}
        <div className="ml-auto flex items-center gap-2 text-xs">
          <span className="text-muted-foreground">Location</span>
          <span className="rounded-md border border-border bg-surface px-2 py-1 font-semibold text-foreground">{city?.name ?? "—"}</span>
        </div>
      </div>
      {(x.length > 0 || u) && (
        <div className="flex items-center gap-1.5 overflow-x-auto border-t border-border px-3 py-1.5">
          <Backpack className="h-3 w-3 shrink-0 text-muted-foreground" />
          <div className="flex flex-wrap items-center gap-1">
            {u && (
              <>
                {me.papers > 0 && (
                  <span
                    title={`${me.papers} contract paper${1 === me.papers ? "" : "s"} — hires a contractor on a gathering site`}
                    className="inline-flex items-center gap-1 rounded bg-primary/15 px-1.5 py-0.5 text-[10px] whitespace-nowrap text-primary-emphasis"
                  >
                    <ScrollText className="h-3 w-3" />
                    <span className="font-mono font-semibold tabular-nums">{me.papers}</span>
                  </span>
                )}
                {me.processPapers > 0 && (
                  <span
                    title={`${me.processPapers} processing contract${1 === me.processPapers ? "" : "s"} — works a processor`}
                    className="inline-flex items-center gap-1 rounded bg-teal-500/10 text-teal-700 dark:bg-teal-900/30 dark:text-teal-300 px-1.5 py-0.5 text-[10px] whitespace-nowrap"
                  >
                    <FlaskConical className="h-3 w-3" />
                    <span className="font-mono font-semibold tabular-nums">{me.processPapers}</span>
                  </span>
                )}
                {x.length > 0 && <span className="mx-0.5 h-3.5 w-px shrink-0 bg-border" />}
              </>
            )}
            {x.map(({ id, qty, item }) => (
              <span
                key={id}
                title={`${item.name} — ${qty} x ${item.weight}kg = ${Math.round(qty * item.weight)}kg`}
                className={cn(
                  "inline-flex items-center gap-1 rounded px-1.5 py-0.5 text-[10px] whitespace-nowrap",
                  item.legal ? "bg-muted text-foreground-secondary" : "bg-red-500/15 text-red-700 dark:text-red-400",
                )}
              >
                <span className="font-medium">{item.name}</span>
                <span className="font-mono font-semibold tabular-nums">{qty}</span>
              </span>
            ))}
          </div>
        </div>
      )}
      {(l || o) && (
        <div
          className={cn(
            "flex flex-wrap items-center gap-2 border-t px-3 py-2 text-xs",
            l ? "border-red-500/40 bg-red-500/10 text-red-700 dark:text-red-300" : "border-border bg-surface text-muted-foreground",
          )}
        >
          {l ? (
            <>
              <Gavel className="h-3.5 w-3.5 shrink-0" />
              <span>
                In APD custody — released in{" "}
                <span className="font-mono font-semibold">{fmtSecs(me.jailedUntil - clock)}</span>
              </span>
              <div className="ml-auto flex items-center gap-1.5">
                <button
                  type="button"
                  onClick={onRelease}
                  className="inline-flex items-center gap-1 rounded-md border border-border px-2 py-1 font-semibold text-foreground hover:bg-surface"
                >
                  <Banknote className="h-3 w-3" />
                  {"Pay "}
                  {fmtMoney(me.custody?.releaseCost ?? me.bailCost)}
                  {" to leave now"}
                </button>
              </div>
            </>
          ) : (
            <>
              <Truck className="h-3.5 w-3.5 shrink-0 animate-pulse" />
              <span>
                On the road — arriving in{" "}
                <span className="font-mono font-semibold">{fmtSecs(me.travelUntil - clock)}</span>
              </span>
            </>
          )}
        </div>
      )}
    </div>
  );
}
