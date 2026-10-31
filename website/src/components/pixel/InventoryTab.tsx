"use client";

import { Archive, Clock, FlaskConical, Gift, Package, ScrollText, Users } from "lucide-react";
import { cn } from "@/lib/utils";
import { fmtCompact, fmtMoney, fmtSecs } from "./format";
import { Empty, Panel, Stat } from "./primitives";
import type { ChestRarity, Item, Me, Site, Statics } from "./types";

// Reference tS: chest card tones by rarity.
const CHEST_TONES: Record<ChestRarity, string> = {
  common: "border-border bg-surface text-foreground-secondary",
  rare: "border-blue-500/40 bg-blue-500/10 text-blue-700 dark:text-blue-300",
  epic: "border-purple-500/40 bg-purple-500/10 text-purple-700 dark:text-purple-300",
  legendary: "border-amber-500/40 bg-amber-500/10 text-amber-700 dark:text-amber-300",
};

// Reference: the inline contract-countdown formatter inside tL.
function fmtContractLeft(e: number): string {
  const t = Math.max(0, Math.ceil(e / 1e3));
  if (t < 90) return fmtSecs(e);
  const a = Math.floor(t / 60);
  return a < 90 ? `${a}m ${t % 60}s` : `${Math.floor(a / 60)}h ${a % 60}m`;
}

// Reference tL: the Inventory view of the Market tab (chests, contract papers, contracts, bag, lifetime).
export function InventoryTab({
  me,
  statics,
  itemMap,
  siteMap,
  prices,
  clock,
  disabled,
  onOpen,
  onCraftContract,
}: {
  me: Me;
  statics: Statics;
  itemMap: Record<string, Item>;
  siteMap: Record<string, Site>;
  prices: Record<string, number>;
  clock: number;
  disabled: boolean;
  onOpen: (rarity: ChestRarity) => void;
  onCraftContract: (qty: number) => void;
}) {
  const c = Object.entries(me.inventory)
      .filter(([, e]) => e > 0)
      .map(([e, t]) => ({
        id: e,
        qty: t,
        item: itemMap[e],
      }))
      .filter((e) => e.item)
      .sort((e, t) => (prices[t.id] ?? 0) * t.qty - (prices[e.id] ?? 0) * e.qty),
    m = Object.values(me.chests).reduce((e, t) => e + (t || 0), 0);
  return (
    <div className="space-y-3">
      <div className="grid gap-3 lg:grid-cols-[minmax(0,1fr)_260px]">
        <Panel
          title="Chests"
          icon={<Gift className="h-3.5 w-3.5 text-muted-foreground" />}
          right={
            <span className="text-[10px] text-muted-foreground">
              {"found while working & patrolling · "}
              {me.stats.chestsFound}
              {" lifetime"}
            </span>
          }
        >
          {0 === m ? (
            <Empty>Nothing yet — every work click and paid patrol has a small chance of turning one up. Rarer chests carry contract papers.</Empty>
          ) : (
            <div className="grid gap-2 sm:grid-cols-2">
              {statics.chests.map((a) => {
                const s = me.chests[a.rarity] ?? 0;
                return 0 === s ? null : (
                  <div key={a.rarity} className={cn("flex items-center gap-2.5 rounded-lg border p-2.5", CHEST_TONES[a.rarity])}>
                    <Archive className="h-5 w-5 shrink-0" />
                    <div className="min-w-0 flex-1">
                      <div className="truncate text-xs font-semibold">{a.name}</div>
                      <div className="text-[10px] opacity-80">
                        x{s}
                        {" · pays with your level — worth more the higher you are"}
                      </div>
                    </div>
                    <button
                      type="button"
                      disabled={disabled}
                      onClick={() => onOpen(a.rarity)}
                      className={cn(
                        "shrink-0 rounded-md bg-primary px-2.5 py-1.5 text-[10px] font-bold uppercase",
                        "text-primary-foreground transition hover:brightness-110",
                        "disabled:cursor-not-allowed disabled:opacity-40",
                      )}
                    >
                      Open
                    </button>
                  </div>
                );
              })}
            </div>
          )}
        </Panel>
        <Panel
          title="Contract Papers"
          icon={<ScrollText className="h-3.5 w-3.5 text-muted-foreground" />}
          right={
            <span className="text-[10px] text-muted-foreground">
              {statics.processContractPaperCost}
              {" → 1 processing"}
            </span>
          }
        >
          <div className="flex items-center gap-3">
            <div
              className={cn(
                "flex h-12 w-12 shrink-0 items-center justify-center rounded-lg text-lg font-bold",
                me.papers > 0 ? "bg-primary/15 text-primary-emphasis" : "bg-muted text-muted-foreground",
              )}
            >
              {me.papers}
            </div>
            <p className="text-[10px] leading-relaxed text-muted-foreground">
              The only way to hire a contractor — they cannot be bought. Contracts cost{" "}
              {statics.workerContracts.map((e) => `${e.papers} for ${e.minutes}m`).join(", ")}. They turn up as you work and ride inside the rarer chests. Spend them from the{" "}
              <span className="font-semibold text-foreground">Work</span>
              {" tab."}
            </p>
          </div>
          <div className="mt-3 border-t border-border pt-3">
            <div className="flex items-center gap-3">
              <div
                className={cn(
                  "flex h-12 w-12 shrink-0 items-center justify-center rounded-lg text-lg font-bold",
                  me.processPapers > 0 ? "bg-teal-500/10 text-teal-700 dark:bg-teal-900/30 dark:text-teal-300" : "bg-muted text-muted-foreground",
                )}
              >
                {me.processPapers}
              </div>
              <div className="min-w-0 flex-1">
                <p className="mb-0.5 flex items-center gap-1 text-xs font-semibold text-foreground">
                  <FlaskConical className="h-3 w-3 text-teal-700 dark:text-teal-400" />
                  Processing Contracts
                </p>
                <p className="text-[10px] leading-relaxed text-muted-foreground">
                  The only contract that works a processor, converting stock you already hold. Costs{" "}
                  {statics.processContracts.map((e) => `${e.contracts} for ${e.minutes}m`).join(", ")}.
                </p>
              </div>
            </div>
            <div className="mt-2 flex items-center gap-1">
              <button
                type="button"
                disabled={disabled || me.papers < statics.processContractPaperCost}
                onClick={() => onCraftContract(1)}
                title={
                  me.papers < statics.processContractPaperCost
                    ? `Needs ${statics.processContractPaperCost} papers — you have ${me.papers}`
                    : `Spend ${statics.processContractPaperCost} papers`
                }
                className={cn(
                  "shrink-0 rounded-md bg-primary px-2.5 py-1.5 text-[10px] font-bold uppercase",
                  "text-primary-foreground transition hover:brightness-110",
                  "disabled:cursor-not-allowed disabled:opacity-40",
                )}
              >
                Draw up
              </button>
              {me.papers >= 5 * statics.processContractPaperCost && (
                <button
                  type="button"
                  disabled={disabled}
                  onClick={() => onCraftContract(5)}
                  title={`Spend ${5 * statics.processContractPaperCost} papers for 5`}
                  className={cn(
                    "shrink-0 rounded-md border border-border px-2 py-1.5 text-[10px] font-bold uppercase",
                    "text-muted-foreground transition hover:bg-muted hover:text-foreground",
                    "disabled:cursor-not-allowed disabled:opacity-40",
                  )}
                >
                  ×5
                </button>
              )}
            </div>
          </div>
        </Panel>
      </div>
      <Panel
        title="Active Contracts"
        icon={<Users className="h-3.5 w-3.5 text-muted-foreground" />}
        right={
          <span className="text-[10px] text-muted-foreground">
            {me.workers.length}/{statics.workerMaxActive}
            {" running"}
          </span>
        }
        bodyClassName="p-0"
      >
        {0 === me.workers.length ? (
          <Empty>
            No contractors on the clock. Hire one with contract papers on a gathering site, or a processing contract on a processor — they work wall-clock time, online or not,
            and sell what they produce on the spot unless you switch contractor auto-sell off.
          </Empty>
        ) : (
          <ul className="divide-y divide-border">
            {me.workers.map((e) => {
              const a = siteMap[e.siteId];
              return (
                <li key={e.siteId} className="flex items-center gap-2 px-3 py-2">
                  <Clock className="h-3.5 w-3.5 shrink-0 text-muted-foreground" />
                  <span className="min-w-0 flex-1 truncate text-xs text-foreground">{a?.name ?? e.siteId}</span>
                  <span className="shrink-0 rounded bg-green-500/15 px-1.5 py-0.5 font-mono text-[10px] font-semibold text-green-700 dark:text-green-400">~{e.perMinute}/min</span>
                  <span className="shrink-0 font-mono text-[10px] tabular-nums text-muted-foreground" title="Auto-sold by this contract so far">
                    {fmtMoney(e.earned)}
                  </span>
                  <span className="shrink-0 font-mono text-[10px] tabular-nums text-muted-foreground">
                    {fmtContractLeft(e.until - clock)}
                    {" left"}
                  </span>
                </li>
              );
            })}
          </ul>
        )}
      </Panel>
      <Panel
        title="Bag"
        icon={<Package className="h-3.5 w-3.5 text-muted-foreground" />}
        right={
          <span className="font-mono text-[10px] text-muted-foreground">
            {me.carried}/{me.capacity}kg
          </span>
        }
        bodyClassName="p-0"
      >
        {0 === c.length ? (
          <Empty>Empty. Work a site and it fills up.</Empty>
        ) : (
          <ul className="divide-y divide-border">
            {c.map(({ id, qty, item }) => (
              <li key={id} className="flex items-center gap-2 px-3 py-1.5">
                <span className={cn("h-1.5 w-1.5 shrink-0 rounded-full", item.legal ? "bg-green-500" : "bg-red-500")} aria-hidden={true} />
                <span className="min-w-0 flex-1 truncate text-xs text-foreground">{item.name}</span>
                <span className="shrink-0 font-mono text-[10px] text-muted-foreground">
                  x{qty}
                  {" · "}
                  {Math.round(item.weight * qty)}kg
                </span>
                <span className="w-16 shrink-0 text-right font-mono text-[10px] tabular-nums text-foreground-secondary">
                  {(prices[id] ?? 0) > 0 ? fmtCompact((prices[id] ?? 0) * qty) : "—"}
                </span>
              </li>
            ))}
          </ul>
        )}
        <div className="border-t border-border px-3 py-1.5 text-[10px] text-muted-foreground">Sell from the Sell view above — prices differ by city and move with every sale.</div>
      </Panel>
      <Panel title="Lifetime" icon={<Archive className="h-3.5 w-3.5 text-muted-foreground" />}>
        <div className="grid grid-cols-3 gap-x-4 gap-y-3 sm:grid-cols-6">
          <Stat label="Earned" value={fmtCompact(me.stats.earned)} />
          <Stat label="Gathered" value={me.stats.gathered.toLocaleString()} />
          <Stat label="Processed" value={me.stats.processed.toLocaleString()} />
          <Stat label="Sold" value={me.stats.sold.toLocaleString()} />
          <Stat label="Chests" value={me.stats.chestsFound.toLocaleString()} />
          <Stat label={"cop" === me.faction ? "Arrests" : "Jackpots"} value={("cop" === me.faction ? me.stats.busts : me.stats.jackpots).toLocaleString()} />
        </div>
      </Panel>
    </div>
  );
}
