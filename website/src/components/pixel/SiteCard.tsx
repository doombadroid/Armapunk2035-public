"use client";

import { Ban, ChevronRight, Clock, FlaskConical, Lock, Pickaxe, ScrollText, Sparkles, Users } from "lucide-react";
import { cn } from "@/lib/utils";
import { fmtCompact } from "./format";
import type { Item, License, Me, Site, SiteMode, Statics } from "./types";

export interface SiteCardProps {
  site: Site;
  me: Me;
  itemMap: Record<string, Item>;
  licenseMap: Record<string, License>;
  prices: Record<string, number>;
  statics: Statics;
  disabled: boolean;
  clock: number;
  onWork: (siteId: string) => void;
  onSell: (itemId: string) => void;
  onHire: (siteId: string) => void;
  onWorker: (siteId: string, minutes: number, kind: SiteMode) => void;
}

// Reference ea: one job-site card (work / process button, sell-all, contractor windows, crews).
export function SiteCard({ site, me, itemMap, licenseMap, prices, statics, disabled, clock, onWork, onSell, onHire, onWorker }: SiteCardProps) {
  const u = me.inventory[site.output] ?? 0,
    h = me.workers.find((t) => t.siteId === site.id && t.until > clock),
    p = me.workers.length >= statics.workerMaxActive,
    g = itemMap[site.output],
    f = site.input ? itemMap[site.input] : null,
    y =
      "cop" !== me.faction || site.legal
        ? site.minLevel && me.level < site.minLevel
          ? `Level ${site.minLevel}`
          : site.license && !me.licenses.includes(site.license)
            ? (licenseMap[site.license]?.name ?? site.license)
            : null
        : "APD personnel",
    v = statics.crews.find((t) => t.siteId === site.id),
    k = me.crews[site.id] ?? 0,
    w = v ? Math.round(v.cost * Math.pow(1.65, k)) : 0,
    N = (v?.perMinute ?? 0) * statics.workerRateMult,
    C: SiteMode = "process" === site.mode ? "process" : "gather",
    P = "process" === C,
    S = P ? (statics.processRates[site.id] ?? 0) * statics.workerRateMult : N,
    L = P
      ? statics.processContracts.map((e) => ({
          minutes: e.minutes,
          cost: e.contracts,
        }))
      : statics.workerContracts.map((e) => ({
          minutes: e.minutes,
          cost: e.papers,
        })),
    A = P ? me.processPapers : me.papers,
    $ = P ? "processing contract" : "contract paper",
    T = (g?.sell ?? 0) > 0,
    D = me.stamina < site.stamina,
    R = "process" === site.mode && (me.inventory[site.input ?? ""] ?? 0) < (site.inputPer ?? 1),
    F = !y && !disabled && !D && !R,
    O = prices[site.output] ?? g?.sell ?? 0;
  return (
    <div className={cn("flex flex-col rounded-lg border bg-surface p-3", site.legal ? "border-border" : "border-red-500/30", y && "opacity-60")}>
      <div className="mb-2 flex items-start gap-2">
        <div className={cn("mt-0.5 flex h-7 w-7 shrink-0 items-center justify-center rounded-md", site.legal ? "bg-muted" : "bg-red-500/15")}>
          {"process" === site.mode ? (
            <FlaskConical className={cn("h-3.5 w-3.5", site.legal ? "text-muted-foreground" : "text-red-600 dark:text-red-400")} />
          ) : (
            <Pickaxe className={cn("h-3.5 w-3.5", site.legal ? "text-muted-foreground" : "text-red-600 dark:text-red-400")} />
          )}
        </div>
        <div className="min-w-0 flex-1">
          <div className="truncate text-sm font-semibold text-foreground">{site.name}</div>
          <div className="truncate text-[10px] text-muted-foreground" title={`Map marker: ${site.from}`}>
            {site.from}
          </div>
        </div>
        {site.jackpot && <Sparkles className="mt-0.5 h-3.5 w-3.5 shrink-0 text-amber-500" aria-label={`Rare drop: ${itemMap[site.jackpot[0]]?.name}`} />}
      </div>
      <div className="mb-2 flex items-center gap-1.5 text-xs">
        {f && (
          <>
            <span className="rounded bg-muted px-1.5 py-0.5 font-mono text-[10px] text-foreground-secondary">
              {site.inputPer}
              {"x "}
              {f.name}
            </span>
            <ChevronRight className="h-3 w-3 shrink-0 text-muted-foreground" />
          </>
        )}
        <span
          className={cn(
            "truncate rounded px-1.5 py-0.5 font-mono text-[10px] font-semibold",
            site.legal ? "bg-green-500/15 text-green-700 dark:text-green-400" : "bg-red-500/15 text-red-700 dark:text-red-400",
          )}
        >
          {g?.name ?? site.output}
        </span>
        <span className="ml-auto shrink-0 font-mono text-[10px] text-muted-foreground">{O > 0 ? `${fmtCompact(O)}/u` : "raw"}</span>
      </div>
      <div className="mb-2 flex items-center gap-3 font-mono text-[10px] text-muted-foreground">
        <span>~{site.yield}/click</span>
        <span>
          {site.stamina}
          {" stam"}
        </span>
        {g && <span>{g.weight}kg</span>}
      </div>
      <div className="mt-auto flex gap-1.5">
        <button
          type="button"
          disabled={!F}
          onClick={() => onWork(site.id)}
          className={cn(
            "min-w-0 flex-1 rounded-md px-3 py-2 text-xs font-bold uppercase tracking-wide transition",
            "active:scale-[0.98] disabled:cursor-not-allowed disabled:opacity-50",
            F ? (site.legal ? "bg-primary text-primary-foreground hover:brightness-110" : "bg-red-600 text-white hover:brightness-110") : "bg-muted text-muted-foreground",
          )}
        >
          {y ? (
            <span className="inline-flex items-center gap-1">
              {"APD personnel" === y ? <Ban className="h-3 w-3" /> : <Lock className="h-3 w-3" />}
              {y}
            </span>
          ) : R ? (
            `Need ${f?.name}`
          ) : D ? (
            "Too tired"
          ) : "process" === site.mode ? (
            "Process"
          ) : (
            "Work"
          )}
        </button>
        {u > 0 && T && !(g && !g.legal && "cop" === me.faction) && (
          <button
            type="button"
            disabled={disabled}
            onClick={() => onSell(site.output)}
            title={`Sell all ${u} at the local price`}
            className={cn(
              "shrink-0 rounded-md border border-green-500/40 bg-green-500/10 px-2.5 py-2",
              "text-[10px] font-bold uppercase text-green-700 transition hover:bg-green-500/20",
              "disabled:cursor-not-allowed disabled:opacity-40 dark:text-green-400",
            )}
          >
            {"Sell "}
            {u}
            {" · "}
            {fmtCompact(u * O)}
          </button>
        )}
      </div>
      {S > 0 && !y && "civ" === me.faction && T && (
        <div className="mt-1.5 space-y-1">
          {h && (
            <div className="flex items-center gap-1.5 rounded-md border border-green-500/40 bg-green-500/10 px-2 py-1 text-[10px] text-green-700 dark:text-green-400">
              <Clock className="h-3 w-3 shrink-0" />
              <span className="min-w-0 flex-1 truncate font-medium">Auto-selling ~{fmtCompact(Math.round(h.perMinute * O))}/min</span>
              <span className="shrink-0 font-mono tabular-nums">{Math.max(0, Math.ceil((h.until - clock) / 6e4))}m left</span>
            </div>
          )}
          <div className="flex items-center gap-1">
            <span className="shrink-0 text-[9px] uppercase tracking-wide text-muted-foreground">{h ? "Extend" : P ? "Processor" : "Worker"}</span>
            {L.map(({ minutes, cost }) => {
              const r = A < cost,
                n = !h && p;
              return (
                <button
                  key={minutes}
                  type="button"
                  disabled={disabled || n || r}
                  onClick={() => onWorker(site.id, minutes, C)}
                  title={
                    n
                      ? `Already running ${statics.workerMaxActive} contracts`
                      : r
                        ? `Needs ${cost} ${$}${1 === cost ? "" : "s"} — you have ${A}`
                        : `${minutes}m \xb7 ${cost} ${$}${1 === cost ? "" : "s"} \xb7 ~${fmtCompact(Math.round(S * minutes * O))} auto-sold` +
                          (P && R ? ` — you have no ${f?.name ?? "input"} for it to convert` : "")
                  }
                  className={cn(
                    "flex-1 rounded border border-border px-1 py-0.5 text-[9px] font-medium text-muted-foreground",
                    "transition hover:border-primary/40 hover:text-foreground",
                    "disabled:cursor-not-allowed disabled:opacity-40",
                  )}
                >
                  {minutes}
                  {"m · "}
                  {cost}
                  {P ? <FlaskConical className="ml-0.5 inline h-2.5 w-2.5 text-teal-700 dark:text-teal-400" /> : <ScrollText className="ml-0.5 inline h-2.5 w-2.5" />}
                </button>
              );
            })}
          </div>
        </div>
      )}
      {v && !y && "civ" === me.faction && (
        <button
          type="button"
          disabled={disabled || k >= statics.maxCrewsPerSite || me.cash < w}
          onClick={() => onHire(site.id)}
          title={`Permanent — ${v.perMinute}/min into your bag. Priced off what ${g?.name ?? "the output"} is worth.`}
          className={cn(
            "mt-1.5 inline-flex w-full items-center justify-center gap-1 rounded-md border border-border",
            "px-2 py-1 text-[10px] font-medium text-muted-foreground transition",
            "hover:border-primary/40 hover:text-foreground disabled:cursor-not-allowed disabled:opacity-40",
          )}
        >
          <Users className="h-3 w-3" />
          {k >= statics.maxCrewsPerSite ? `Crew maxed (${k})` : `Hire crew ${k > 0 ? `#${k + 1}` : ""} — ${fmtCompact(w)}`}
          {k > 0 && (
            <span className="ml-1 rounded bg-primary/15 px-1 font-mono text-primary-emphasis">
              {k}
              {"x · "}
              {v.perMinute * k}/min
            </span>
          )}
        </button>
      )}
    </div>
  );
}
