"use client";

import { Check, Lock, RotateCcw, Sparkles, Star } from "lucide-react";
import { cn } from "@/lib/utils";
import { fmtMoney } from "./format";
import { Empty, Panel } from "./primitives";
import type { Me, Statics } from "./types";

// Reference eO: the Talents view of the Progression tab.
export function TalentsTab({
  me,
  statics,
  disabled,
  onLearn,
  onRespec,
}: {
  me: Me;
  statics: Statics;
  disabled: boolean;
  onLearn: (talentId: string) => void;
  onRespec: () => void;
}) {
  const i = "cop" === me.faction,
    l = statics.talents.filter((t) => "both" === t.faction || t.faction === me.faction),
    o = [...l].sort((e, t) => e.minLevel - t.minLevel || e.name.localeCompare(t.name)),
    d = l.filter((t) => t.minLevel > me.level).sort((e, t) => e.minLevel - t.minLevel)[0] ?? null;
  return (
    <div className="space-y-3">
      <Panel
        title="Talent Points"
        icon={<Sparkles className="h-3.5 w-3.5 text-muted-foreground" />}
        right={
          <span className="font-mono text-[10px] text-muted-foreground">
            {me.talentSpent}
            {" spent"}
          </span>
        }
      >
        <div className="flex items-center gap-3">
          <div
            className={cn(
              "flex h-12 w-12 shrink-0 items-center justify-center rounded-lg text-lg font-bold",
              me.talentPoints > 0 ? "bg-primary/15 text-primary-emphasis" : "bg-muted text-muted-foreground",
            )}
          >
            {me.talentPoints}
          </div>
          <div className="min-w-0 flex-1">
            <p className="text-xs font-semibold text-foreground">{me.talentPoints > 0 ? `${me.talentPoints} point${1 === me.talentPoints ? "" : "s"} to spend` : "No points available"}</p>
            <p className="mt-0.5 text-[10px] leading-relaxed text-muted-foreground">
              {"You earn "}
              {statics.talentPointsPerLevel}
              {" per level. Talents cannot be bought with cash — levelling is the only way to get them."}
              {d ? ` Next talent unlocks at level ${d.minLevel} (${d.name}).` : " Every talent is unlocked."}
            </p>
          </div>
          <button
            type="button"
            disabled={disabled || 0 === me.talentSpent || me.cash < me.respecCost}
            onClick={onRespec}
            className={cn(
              "inline-flex shrink-0 items-center gap-1.5 rounded-md border border-border px-2.5 py-2",
              "text-[10px] font-bold uppercase text-muted-foreground transition",
              "hover:bg-muted hover:text-foreground",
              "disabled:cursor-not-allowed disabled:opacity-40",
            )}
            title={`Refund every point for ${fmtMoney(me.respecCost)}`}
          >
            <RotateCcw className="h-3 w-3" />
            {"Respec "}
            {fmtMoney(me.respecCost)}
          </button>
        </div>
      </Panel>
      <Panel
        title={i ? "APD Talents" : "Civilian Talents"}
        icon={<Star className="h-3.5 w-3.5 text-muted-foreground" />}
        right={<span className="text-[10px] text-muted-foreground">{i ? "Your civilian tree is kept, dormant" : "Your APD tree is kept, dormant"}</span>}
        bodyClassName="p-0"
      >
        {0 === o.length ? (
          <Empty>No talents available to your career.</Empty>
        ) : (
          <ul className="divide-y divide-border">
            {o.map((a) => {
              const n = me.talents[a.id] ?? 0,
                i = n >= a.max,
                l = me.level < a.minLevel,
                o = i ? 0 : a.costs[n],
                d = !i && !l && me.talentPoints >= o;
              return (
                <li key={a.id} className="flex items-center gap-3 px-3 py-2">
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center gap-2">
                      <span className={cn("text-xs font-semibold", l ? "text-muted-foreground" : "text-foreground")}>{a.name}</span>
                      <span className="font-mono text-[10px] text-primary-emphasis">
                        {n}/{a.max}
                      </span>
                      {l && (
                        <span className="inline-flex items-center gap-1 rounded bg-muted px-1.5 py-0.5 text-[9px] font-bold uppercase text-muted-foreground">
                          <Lock className="h-2.5 w-2.5" />
                          {"Level "}
                          {a.minLevel}
                        </span>
                      )}
                    </div>
                    <p className="truncate text-[10px] text-muted-foreground">{a.blurb}</p>
                    <div className="mt-1 flex gap-0.5">
                      {Array.from(
                        {
                          length: a.max,
                        },
                        (e, a) => <span key={a} className={cn("h-1 flex-1 rounded-sm", a < n ? "bg-primary" : "bg-muted")} />,
                      )}
                    </div>
                  </div>
                  <button
                    type="button"
                    disabled={disabled || i || l || !d}
                    onClick={() => onLearn(a.id)}
                    className={cn(
                      "inline-flex shrink-0 items-center gap-1 rounded-md px-2.5 py-1.5",
                      "text-[10px] font-bold uppercase transition",
                      "disabled:cursor-not-allowed disabled:opacity-40",
                      i ? "bg-muted text-muted-foreground" : "bg-primary text-primary-foreground hover:brightness-110",
                    )}
                  >
                    {i ? (
                      <>
                        <Check className="h-3 w-3" />
                        Max
                      </>
                    ) : (
                      <>
                        <Sparkles className="h-3 w-3" />
                        {o}
                        {" pt"}
                        {1 === o ? "" : "s"}
                      </>
                    )}
                  </button>
                </li>
              );
            })}
          </ul>
        )}
      </Panel>
    </div>
  );
}
