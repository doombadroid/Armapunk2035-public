"use client";

import { useMemo } from "react";
import { Clock, Flame, PackageOpen, Scale, ShoppingBasket, Trash2, TrendingDown, TrendingUp, Zap } from "lucide-react";
import { cn } from "@/lib/utils";
import { fmtCompact, fmtMoney } from "./format";
import { Empty, Panel } from "./primitives";
import type { City, Item, Me, Statics } from "./types";

export type MarketView = "inventory" | "sell" | "prices";

// Reference ed: the HOT / FLOODED / percentage market tag.
export function MarketTag({ mult }: { mult: number }) {
  return mult >= 1.08 ? (
    <span className="inline-flex items-center gap-0.5 rounded bg-green-500/15 px-1 py-0.5 font-mono text-[9px] font-semibold text-green-700 dark:text-green-400">
      <TrendingUp className="h-2.5 w-2.5" />
      HOT
    </span>
  ) : mult <= 0.72 ? (
    <span className="inline-flex items-center gap-0.5 rounded bg-red-500/15 px-1 py-0.5 font-mono text-[9px] font-semibold text-red-700 dark:text-red-400">
      <TrendingDown className="h-2.5 w-2.5" />
      FLOODED
    </span>
  ) : (
    <span className="font-mono text-[9px] text-muted-foreground">{Math.round(100 * mult)}%</span>
  );
}

// Reference ec: the Market tab (Inventory / Sell / Prices).
export function MarketTab({
  me,
  city,
  items,
  itemMap,
  prices,
  mults,
  disabled,
  processedAt,
  sourcedAt,
  bestCity,
  statics,
  view,
  onViewChange,
  inventory,
  onSell,
  onDrop,
  onDitch,
  onPayHeat,
  onAutoSell,
  onWorkerAutoSell,
}: {
  me: Me;
  city: City | undefined;
  items: Item[];
  itemMap: Record<string, Item>;
  prices: Record<string, number>;
  mults: Record<string, number>;
  disabled: boolean;
  processedAt: Record<string, string>;
  sourcedAt: Record<string, string>;
  bestCity: { name: string; demand: number } | null;
  statics: Statics;
  view: MarketView;
  onViewChange: (view: MarketView) => void;
  inventory: React.ReactNode;
  onSell: (itemId: string, amount: number | "all") => void;
  onDrop: (itemId: string, amount: number | "all") => void;
  onDitch: () => void;
  onPayHeat: () => void;
  onAutoSell: () => void;
  onWorkerAutoSell: () => void;
}) {
  const C = useMemo(
      () =>
        Object.entries(me.inventory)
          .filter(([, e]) => e > 0)
          .map(([e, t]) => ({
            id: e,
            qty: t,
            it: itemMap[e],
          }))
          .filter((e) => e.it)
          .sort((e, t) => (prices[t.id] ?? 0) * t.qty - (prices[e.id] ?? 0) * e.qty),
      [me.inventory, itemMap, prices],
    ),
    P = useMemo(() => items.filter((e) => e.sell > 0).sort((e, t) => t.sell - e.sell), [items]),
    S = C.reduce((e, t) => e + (prices[t.id] ?? 0) * t.qty, 0),
    L = C.some((e) => !e.it.legal),
    M = "cop" === me.faction,
    A = me.level < statics.autoSellUnlockLevel;
  return (
    <div className="space-y-3">
      <div className="rounded-lg border border-border bg-card p-1.5">
        <div className="grid grid-cols-3 gap-1" role="tablist" aria-label="Market sections">
          {(
            [
              {
                id: "inventory",
                label: "Inventory",
                Icon: PackageOpen,
              },
              {
                id: "sell",
                label: "Sell",
                Icon: ShoppingBasket,
              },
              {
                id: "prices",
                label: "Prices",
                Icon: TrendingUp,
              },
            ] as const
          ).map(({ id, label, Icon }) => (
            <button
              key={id}
              type="button"
              role="tab"
              aria-selected={view === id}
              onClick={() => onViewChange(id)}
              className={cn(
                "inline-flex min-h-11 items-center justify-center gap-1.5 rounded-md px-3 py-2 text-xs font-bold transition",
                view === id ? "bg-primary text-primary-foreground shadow-sm" : "text-muted-foreground hover:bg-surface hover:text-foreground",
              )}
            >
              <Icon className="h-3.5 w-3.5" />
              {label}
            </button>
          ))}
        </div>
      </div>
      {"inventory" === view && inventory}
      {"sell" === view && (
        <>
          <div className="grid gap-2 sm:grid-cols-2">
            <div className="flex items-center gap-2.5 rounded-lg border border-border bg-card px-3 py-2.5">
              <Zap className={cn("h-4 w-4 shrink-0", me.autoSell ? "text-primary-emphasis" : "text-muted-foreground")} />
              <div className="min-w-0 flex-1">
                <p className="text-xs font-semibold text-foreground">Auto-sell</p>
                <p className="text-[10px] leading-relaxed text-muted-foreground">
                  {A
                    ? `Unlocks at level ${statics.autoSellUnlockLevel} — sell your haul here until then.`
                    : me.autoSell
                      ? "Work output sells immediately at the local live price."
                      : "Off — work output stays in your bag until you sell it here."}
                </p>
              </div>
              <button
                type="button"
                disabled={disabled || (A && !me.autoSell)}
                onClick={onAutoSell}
                className={cn(
                  "shrink-0 rounded-md px-3 py-2 text-[10px] font-bold uppercase transition",
                  "disabled:cursor-not-allowed disabled:opacity-40",
                  me.autoSell ? "bg-primary text-primary-foreground hover:brightness-110" : "border border-border text-muted-foreground hover:bg-muted hover:text-foreground",
                )}
              >
                {A && !me.autoSell ? `Level ${statics.autoSellUnlockLevel}` : me.autoSell ? "On" : "Off"}
              </button>
            </div>
            <div className="flex items-center gap-2.5 rounded-lg border border-border bg-card px-3 py-2.5">
              <Clock className={cn("h-4 w-4 shrink-0", me.workerAutoSell ? "text-primary-emphasis" : "text-muted-foreground")} />
              <div className="min-w-0 flex-1">
                <p className="text-xs font-semibold text-foreground">Contractor auto-sell</p>
                <p className="text-[10px] leading-relaxed text-muted-foreground">
                  {me.workerAutoSell
                    ? "Contractors sell on the spot at its local price — nothing to haul."
                    : "Off — contractors stock your bag instead, and stop making what will not fit."}
                </p>
              </div>
              <button
                type="button"
                disabled={disabled}
                onClick={onWorkerAutoSell}
                className={cn(
                  "shrink-0 rounded-md px-3 py-2 text-[10px] font-bold uppercase transition",
                  "disabled:cursor-not-allowed disabled:opacity-40",
                  me.workerAutoSell ? "bg-primary text-primary-foreground hover:brightness-110" : "border border-border text-muted-foreground hover:bg-muted hover:text-foreground",
                )}
              >
                {me.workerAutoSell ? "On" : "Off"}
              </button>
            </div>
          </div>
          <Panel
            title={`Sell — ${city?.name ?? ""}`}
            icon={<PackageOpen className="h-3.5 w-3.5 text-muted-foreground" />}
            right={
              <span className="font-mono text-[10px] text-muted-foreground">
                {me.carried}/{me.capacity}
                {"kg · worth "}
                {fmtCompact(S)}
                {" · demand ×"}
                {city?.demand.toFixed(2) ?? "1.00"}
              </span>
            }
            bodyClassName="p-0"
          >
            {0 === C.length ? (
              <Empty>Empty. Go work a site.</Empty>
            ) : (
              <ul className="divide-y divide-border">
                {C.map(({ id, qty, it }) => {
                  const r = prices[id] ?? 0,
                    n = r * qty,
                    l = !disabled && r > 0 && !(M && !it.legal);
                  return (
                    <li key={id} className="flex items-center gap-2 px-3 py-2">
                      <div className="min-w-0 flex-1">
                        <div className="flex items-center gap-1.5">
                          <span className="truncate text-xs font-medium text-foreground">{it.name}</span>
                          {!it.legal && (
                            <span className="shrink-0 rounded bg-red-500/15 px-1 py-0.5 text-[9px] font-semibold uppercase text-red-700 dark:text-red-400">Illegal</span>
                          )}
                        </div>
                        <div className="font-mono text-[10px] text-muted-foreground">
                          {qty}
                          {" × "}
                          {r > 0 ? fmtMoney(r) : "no buyer"}
                          {" · "}
                          {(it.weight * qty).toLocaleString()}kg
                        </div>
                        {r <= 0 && (
                          <div className="text-[10px] text-amber-600 dark:text-amber-400">
                            {processedAt[id] ? `Process at ${processedAt[id]}` : "Nothing processes this — safe to drop"}
                          </div>
                        )}
                      </div>
                      <span className="shrink-0 font-mono text-xs font-semibold tabular-nums text-foreground">{n > 0 ? fmtCompact(n) : "—"}</span>
                      <div className="flex shrink-0 gap-1">
                        {r > 0 ? (
                          <>
                            <button
                              type="button"
                              disabled={!l}
                              onClick={() => onSell(id, 1)}
                              className="min-h-9 rounded border border-border px-2 py-1 text-[10px] font-medium hover:border-primary/40 disabled:opacity-40"
                            >
                              Sell 1
                            </button>
                            <button
                              type="button"
                              disabled={!l}
                              onClick={() => onSell(id, "all")}
                              className="min-h-9 rounded bg-primary px-2 py-1 text-[10px] font-bold uppercase text-primary-foreground hover:brightness-110 disabled:opacity-40"
                            >
                              Sell all
                            </button>
                          </>
                        ) : null}
                        <button
                          type="button"
                          disabled={disabled}
                          onClick={() => onDrop(id, "all")}
                          title={`Throw away all ${qty} ${it.name}`}
                          className={cn(
                            "inline-flex items-center gap-1 rounded border px-1.5 py-1 text-[10px] font-medium transition",
                            "disabled:opacity-40",
                            r > 0
                              ? "border-border text-muted-foreground hover:border-red-500/50 hover:text-red-600 dark:hover:text-red-400"
                              : "border-red-500/40 text-red-700 hover:bg-red-500/10 dark:text-red-400",
                          )}
                        >
                          <Trash2 className="h-3 w-3" />
                          Drop
                        </button>
                      </div>
                    </li>
                  );
                })}
              </ul>
            )}
            {!M && (L || me.heat > 0) && (
              <div className="space-y-1.5 border-t border-border p-2">
                {L && (
                  <button
                    type="button"
                    disabled={disabled}
                    onClick={onDitch}
                    className="inline-flex w-full items-center justify-center gap-1.5 rounded-md border border-red-500/40 px-2 py-1.5 text-[10px] font-semibold text-red-700 transition hover:bg-red-500/10 disabled:cursor-not-allowed disabled:opacity-40 dark:text-red-400"
                  >
                    <Trash2 className="h-3 w-3" />
                    Ditch all contraband — halves your heat
                  </button>
                )}
                {me.heat > 0 && (
                  <>
                    <button
                      type="button"
                      disabled={disabled || me.cash < me.bribeCost}
                      onClick={onPayHeat}
                      title={L ? "Priced on your heat plus what you are carrying — a bust would seize all of it." : "Priced on your heat alone."}
                      className="inline-flex w-full items-center justify-center gap-1.5 rounded-md border border-amber-500/40 px-2 py-1.5 text-[10px] font-semibold text-amber-700 transition hover:bg-amber-500/10 disabled:cursor-not-allowed disabled:opacity-40 dark:text-amber-400"
                    >
                      <Scale className="h-3 w-3" />
                      {"Pay off your record — "}
                      {fmtMoney(me.bribeCost)}
                    </button>
                    <p className="text-center text-[10px] leading-relaxed text-muted-foreground">
                      {me.cash < me.bribeCost
                        ? `You are $${(me.bribeCost - me.cash).toLocaleString()} short.`
                        : "Clears your wanted level to zero and keeps everything in your bag."}
                    </p>
                  </>
                )}
              </div>
            )}
          </Panel>
        </>
      )}
      {"prices" === view && (
        <Panel
          title={`Market prices — ${city?.name ?? ""}`}
          icon={<ShoppingBasket className="h-3.5 w-3.5 text-muted-foreground" />}
          right={
            <span className="font-mono text-[10px] text-muted-foreground">
              demand ×{city?.demand.toFixed(2) ?? "1.00"}
              {bestCity && bestCity.name !== city?.name && (
                <span className="ml-2 text-green-700 dark:text-green-400">
                  {"best: "}
                  {bestCity.name}
                  {" ×"}
                  {bestCity.demand.toFixed(2)}
                </span>
              )}
            </span>
          }
          bodyClassName="p-0"
        >
          <div className="max-h-[520px] overflow-y-auto">
            <table className="w-full text-xs">
              <thead className="sticky top-0 bg-surface">
                <tr className="border-b border-border text-left">
                  <th className="px-3 py-1.5 font-medium text-muted-foreground">Item</th>
                  <th className="px-2 py-1.5 text-right font-medium text-muted-foreground">Base</th>
                  <th className="px-2 py-1.5 text-right font-medium text-muted-foreground">Now</th>
                  <th className="px-3 py-1.5 text-right font-medium text-muted-foreground">Market</th>
                </tr>
              </thead>
              <tbody>
                {P.map((a) => {
                  const s = prices[a.id] ?? a.sell,
                    r = mults[a.id] ?? 1,
                    n = me.inventory[a.id] ?? 0;
                  return (
                    <tr key={a.id} className={cn("border-b border-border/50", n > 0 && "bg-primary/5")}>
                      <td className="px-3 py-1.5">
                        <div className="flex items-center gap-1.5">
                          {!a.legal && <Flame className="h-3 w-3 shrink-0 text-red-500" />}
                          <span className="truncate text-foreground">{a.name}</span>
                          {sourcedAt[a.id] && (
                            <span className="hidden shrink-0 truncate font-mono text-[9px] text-muted-foreground sm:inline" title={`Produced in ${sourcedAt[a.id]}`}>
                              {sourcedAt[a.id]}
                            </span>
                          )}
                          {n > 0 && <span className="shrink-0 rounded bg-primary/15 px-1 font-mono text-[9px] text-primary-emphasis">{n}</span>}
                        </div>
                      </td>
                      <td className="px-2 py-1.5 text-right font-mono text-muted-foreground tabular-nums">{a.sell.toLocaleString()}</td>
                      <td
                        className={cn(
                          "px-2 py-1.5 text-right font-mono font-semibold tabular-nums",
                          s > a.sell ? "text-green-600 dark:text-green-400" : s < 0.85 * a.sell ? "text-red-600 dark:text-red-400" : "text-foreground",
                        )}
                      >
                        {s.toLocaleString()}
                      </td>
                      <td className="px-3 py-1.5 text-right">
                        <MarketTag mult={r} />
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </Panel>
      )}
    </div>
  );
}
