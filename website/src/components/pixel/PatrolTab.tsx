"use client";

import { Radar, Search, Shield, Siren, TrendingDown, TrendingUp, TriangleAlert, User } from "lucide-react";
import { cn } from "@/lib/utils";
import { fmtAgo, fmtCompact, fmtSecs } from "./format";
import { Empty, Panel } from "./primitives";
import { PursuitRounds } from "./PursuitRounds";
import type { City, DispatchEntry, Me, Suspect } from "./types";

// Reference eL: the APD Patrol tab (dispatch cases + active suspects).
export function PatrolTab({
  me,
  city,
  suspects,
  npcCrime,
  dispatch,
  cityName,
  clock,
  disabled,
  busy,
  onCaseStart,
  onCaseAnswer,
  onBust,
}: {
  me: Me;
  city: City | undefined;
  suspects: Suspect[];
  npcCrime: number;
  dispatch: DispatchEntry[];
  cityName: (cityId: string) => string;
  clock: number;
  disabled: boolean;
  busy: boolean;
  onCaseStart: (practice: boolean) => void;
  onCaseAnswer: (round: number, choice: number) => void;
  onBust: (targetId: string) => void;
}) {
  const u = me.apdCase,
    h = u && "active" === u.status,
    p = clock >= me.apdCaseReadyAt;
  return (
    <div className="grid gap-3 lg:grid-cols-2">
      <Panel title={`Dispatch — ${city?.name ?? ""}`} icon={<Siren className="h-3.5 w-3.5 text-blue-600 dark:text-blue-400" />} className="border-blue-500/30">
        <div className="mb-3 flex items-center gap-3 rounded-lg bg-surface p-3">
          <Radar className="h-4 w-4 shrink-0 text-blue-600 dark:text-blue-400" />
          <div className="min-w-0 flex-1">
            <div className="text-[10px] uppercase tracking-wide text-muted-foreground">Reported criminal activity</div>
            <div className="mt-1 h-1.5 w-full overflow-hidden rounded-full bg-muted">
              <div className="h-full rounded-full bg-blue-500 transition-[width] duration-500" style={{ width: `${Math.min(100, npcCrime)}%` }} />
            </div>
          </div>
          <span className="shrink-0 font-mono text-sm font-semibold tabular-nums text-foreground">{Math.round(npcCrime)}%</span>
        </div>
        {me.manpowerMult < 0.99 && (
          <div className="mb-3 flex items-center gap-2 rounded-lg border border-amber-500/30 bg-amber-500/5 px-3 py-2 text-[11px] text-amber-700 dark:text-amber-400">
            <TrendingDown className="h-3.5 w-3.5 shrink-0" />
            APD is heavily staffed here — patrol and arrest payouts are reduced (×{me.manpowerMult.toFixed(2)}) until the ratio evens out.
          </div>
        )}
        {me.manpowerMult > 1.01 && (
          <div className="mb-3 flex items-center gap-2 rounded-lg border border-primary/30 bg-primary/5 px-3 py-2 text-[11px] text-primary-emphasis">
            <TrendingUp className="h-3.5 w-3.5 shrink-0" />
            Officers are stretched thin here — payouts are boosted (×{me.manpowerMult.toFixed(2)}) to keep patrolling worthwhile.
          </div>
        )}
        {h ? (
          <>
            <p className="mb-2 text-center text-[11px] font-semibold uppercase tracking-wide text-foreground">
              {u.practice ? "Unpaid practice" : "NPC dispatch case"}
              {" — score "}
              {u.targetScore}
              {" to "}
              {u.practice ? "pass" : `earn $${u.reward}`}
            </p>
            <PursuitRounds rounds={u.rounds} myAnswers={u.answers} startsAt={u.startsAt} until={u.until} clock={clock} disabled={busy} onAnswer={onCaseAnswer} />
          </>
        ) : u && "active" !== u.status ? (
          <div
            className={cn(
              "mb-3 flex items-center justify-between gap-2 rounded-lg border px-3 py-2 text-xs font-semibold",
              "won" === u.status ? "border-green-500/30 bg-green-500/5 text-green-700 dark:text-green-400" : "border-border bg-surface text-muted-foreground",
            )}
          >
            <span>
              {"won" === u.status
                ? u.practice
                  ? "Practice passed."
                  : `Case closed — $${u.reward} earned.`
                : "lost" === u.status
                  ? "Case failed — no reward."
                  : "Case expired — no reward."}
            </span>
          </div>
        ) : null}
        {!h && (
          <div className="grid grid-cols-2 gap-2">
            <button
              type="button"
              disabled={disabled || !p || npcCrime < 2}
              onClick={() => onCaseStart(false)}
              className={cn(
                "flex flex-col items-center gap-1 rounded-lg px-4 py-4 text-sm font-bold uppercase tracking-wider transition",
                "active:scale-[0.99] disabled:cursor-not-allowed disabled:opacity-50",
                "bg-blue-600 text-white hover:brightness-110 disabled:bg-muted disabled:text-muted-foreground",
              )}
            >
              <Search className="h-4 w-4" />
              {p ? (npcCrime < 2 ? "No paid calls here" : "Take a paid call") : `Cooling down (${fmtSecs(me.apdCaseReadyAt - clock)})`}
            </button>
            <button
              type="button"
              disabled={disabled}
              onClick={() => onCaseStart(true)}
              className="flex flex-col items-center gap-1 rounded-lg border border-border bg-surface px-4 py-4 text-sm font-bold uppercase tracking-wider text-foreground transition hover:bg-muted disabled:cursor-not-allowed disabled:opacity-50"
            >
              <Shield className="h-4 w-4" />
              Unpaid practice
            </button>
          </div>
        )}
        <p className="mt-2 text-center text-[10px] text-muted-foreground">{"Same route-choice checkpoints as a live pursuit — pass to earn a call's payout."}</p>
        <dl className="mt-3 grid grid-cols-3 gap-2 border-t border-border pt-3 text-center">
          <div>
            <dt className="text-[10px] uppercase text-muted-foreground">Arrests</dt>
            <dd className="font-mono text-sm font-semibold text-foreground">{me.stats.busts}</dd>
          </div>
          <div>
            <dt className="text-[10px] uppercase text-muted-foreground">Earned</dt>
            <dd className="font-mono text-sm font-semibold text-green-600 dark:text-green-400">{fmtCompact(me.stats.earned)}</dd>
          </div>
          <div>
            <dt className="text-[10px] uppercase text-muted-foreground">Calls</dt>
            <dd className="font-mono text-sm font-semibold text-foreground">{me.stats.clicks}</dd>
          </div>
        </dl>
        <div className="mt-3 border-t border-border pt-3">
          <h3 className="mb-1.5 text-[10px] font-semibold uppercase tracking-wide text-muted-foreground">City tips</h3>
          <ul className="divide-y divide-border">
            {dispatch.map((a) => (
              <li key={a.cityId} className="flex items-center justify-between gap-2 py-1.5 text-[11px]">
                <span className="font-semibold text-foreground">{cityName(a.cityId)}</span>
                <span className="flex items-center gap-2 font-mono text-muted-foreground">
                  <span className={a.wantedCount > 0 ? "text-red-600 dark:text-red-400" : ""}>
                    {a.wantedCount}
                    {" wanted"}
                  </span>
                  <span>
                    {a.officerCount}
                    {" officer"}
                    {1 === a.officerCount ? "" : "s"}
                  </span>
                  {a.cityId !== me.cityId && <span>{a.travelSeconds}s away</span>}
                  {null !== a.latestSeen && (
                    <span>
                      {"seen "}
                      {fmtAgo(clock - a.latestSeen)}
                      {" ago"}
                    </span>
                  )}
                </span>
              </li>
            ))}
          </ul>
        </div>
      </Panel>
      <Panel
        title="Active Suspects"
        icon={<TriangleAlert className="h-3.5 w-3.5 text-red-600 dark:text-red-400" />}
        right={
          <span className="text-[10px] text-muted-foreground">
            {city?.name}
            {" only"}
          </span>
        }
        bodyClassName="p-0"
      >
        {0 === suspects.length ? (
          <Empty>
            {"No one in "}
            {city?.name ?? "this city"}
            {" is carrying enough heat."}
            <br />
            Wait for someone to heat up, or move city.
          </Empty>
        ) : (
          <ul className="divide-y divide-border">
            {suspects.map((a) => (
              <li key={a.steamId} className="flex items-center gap-2.5 px-3 py-2.5">
                {a.avatarUrl ? (
                  // eslint-disable-next-line @next/next/no-img-element -- reference renders a plain <img>
                  <img src={a.avatarUrl} alt="" className="h-8 w-8 shrink-0 rounded-md border border-border" />
                ) : (
                  <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-md border border-border bg-surface">
                    <User className="h-3.5 w-3.5 text-muted-foreground" />
                  </div>
                )}
                <div className="min-w-0 flex-1">
                  <div className="truncate text-xs font-semibold text-foreground">{a.name}</div>
                  <div className="font-mono text-[10px] text-muted-foreground">
                    {"heat "}
                    <span className="text-red-600 dark:text-red-400">{a.heat}</span>
                    {" · "}
                    {"est. "}
                    {fmtCompact(a.estValue)}
                    {" on them"}
                  </div>
                </div>
                {a.pursued ? (
                  <span className="shrink-0 rounded-md bg-muted px-3 py-1.5 text-[10px] font-bold uppercase text-muted-foreground">Being chased</span>
                ) : (
                  <button
                    type="button"
                    disabled={disabled || me.stamina < 14}
                    onClick={() => onBust(a.steamId)}
                    className="shrink-0 rounded-md bg-blue-600 px-3 py-1.5 text-[10px] font-bold uppercase text-white transition hover:brightness-110 disabled:cursor-not-allowed disabled:opacity-40"
                  >
                    Arrest
                  </button>
                )}
              </li>
            ))}
          </ul>
        )}
      </Panel>
    </div>
  );
}
