"use client";

import { Activity, Gavel, Shield, Trophy, User, Users } from "lucide-react";
import { cn } from "@/lib/utils";
import { fmtAgo, fmtCompact } from "./format";
import { Empty, Panel } from "./primitives";
import type { Snapshot } from "./types";

// Reference eI: feed line colours by kind.
const FEED_TONES: Record<string, string> = {
  bust: "text-blue-700 dark:text-blue-300",
  raid: "text-muted-foreground",
  sale: "text-green-700 dark:text-green-400",
  jackpot: "text-amber-600 dark:text-amber-400",
  join: "text-muted-foreground",
  level: "text-primary-emphasis",
};

// Reference e$: the right-rail panels (On the island / Activity / Richest on Altis).
export function IslandRail({ snap, cityName, meSteamId, clock }: { snap: Snapshot; cityName: (cityId: string) => string; meSteamId: string; clock: number }) {
  const { roster: n, feed: i, leaderboard: l } = snap;
  return (
    <div className="space-y-3">
      <Panel
        title="On the island"
        icon={<Users className="h-3.5 w-3.5 text-muted-foreground" />}
        right={<span className="font-mono text-[10px] text-muted-foreground">{snap.online}</span>}
        bodyClassName="p-0"
      >
        {0 === n.length ? (
          <Empty>Nobody online.</Empty>
        ) : (
          <ul className="max-h-56 divide-y divide-border overflow-y-auto">
            {n.map((e) => (
              <li key={e.steamId} className="flex items-center gap-2 px-3 py-1.5">
                {e.avatarUrl ? (
                  // eslint-disable-next-line @next/next/no-img-element -- reference renders a plain <img>
                  <img src={e.avatarUrl} alt="" className="h-6 w-6 shrink-0 rounded border border-border" />
                ) : (
                  <div className="flex h-6 w-6 shrink-0 items-center justify-center rounded border border-border bg-surface">
                    <User className="h-3 w-3 text-muted-foreground" />
                  </div>
                )}
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-1">
                    <span className={cn("truncate text-xs", e.steamId === meSteamId ? "font-bold text-primary-emphasis" : "text-foreground")}>{e.name}</span>
                    {e.gangTag && <span className="shrink-0 font-mono text-[10px] font-semibold text-primary-emphasis">[{e.gangTag}]</span>}
                    {e.prestige > 0 && <span className="shrink-0 font-mono text-[10px] font-bold text-amber-600 dark:text-amber-400">★{e.prestige}</span>}
                    {"cop" === e.faction && <Shield className="h-3 w-3 shrink-0 text-blue-600 dark:text-blue-400" />}
                    {e.jailed && <Gavel className="h-3 w-3 shrink-0 text-red-500" />}
                  </div>
                  <div className="truncate font-mono text-[10px] text-muted-foreground">
                    L{e.level}
                    {" · "}
                    {e.travelling ? "in transit" : cityName(e.cityId)}
                    {e.wanted && (
                      <span className="ml-1 font-semibold text-red-600 dark:text-red-400">
                        {"WANTED "}
                        {e.heat}
                      </span>
                    )}
                  </div>
                </div>
                <span className="shrink-0 font-mono text-[10px] tabular-nums text-muted-foreground">{fmtCompact(e.netWorth)}</span>
              </li>
            ))}
          </ul>
        )}
      </Panel>
      <Panel title="Activity" icon={<Activity className="h-3.5 w-3.5 text-muted-foreground" />} bodyClassName="p-0">
        {0 === i.length ? (
          <Empty>Quiet so far.</Empty>
        ) : (
          <ul className="max-h-64 divide-y divide-border overflow-y-auto">
            {i.map((e) => (
              <li key={e.id} className="px-3 py-1.5 text-[11px] leading-snug">
                <span className="font-semibold text-foreground">{e.name}</span>
                {" "}
                <span className={FEED_TONES[e.kind]}>{e.text}</span>
                <span className="ml-1 font-mono text-[9px] text-muted-foreground">{fmtAgo(clock - e.at)}</span>
              </li>
            ))}
          </ul>
        )}
      </Panel>
      <Panel title="Richest on Altis" icon={<Trophy className="h-3.5 w-3.5 text-amber-500" />} bodyClassName="p-0">
        {0 === l.length ? (
          <Empty>No one has made a dollar yet.</Empty>
        ) : (
          <ol className="divide-y divide-border">
            {l.map((e, a) => (
              <li key={`${e.name}-${a}`} className="flex items-center gap-2 px-3 py-1.5">
                <span className={cn("w-4 shrink-0 text-center font-mono text-[10px] font-bold", 0 === a ? "text-amber-500" : "text-muted-foreground")}>{a + 1}</span>
                <span className="min-w-0 flex-1 truncate text-xs text-foreground">{e.name}</span>
                {"cop" === e.faction && <Shield className="h-3 w-3 shrink-0 text-blue-600 dark:text-blue-400" />}
                <span className="shrink-0 font-mono text-[10px] font-semibold tabular-nums text-foreground">{fmtCompact(e.netWorth)}</span>
              </li>
            ))}
          </ol>
        )}
      </Panel>
    </div>
  );
}
