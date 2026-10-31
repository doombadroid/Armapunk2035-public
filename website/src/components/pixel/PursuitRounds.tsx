"use client";

import { Route } from "lucide-react";
import { cn } from "@/lib/utils";
import { fmtSecs } from "./format";
import type { Round, RoundAnswer } from "./types";

// Reference eP: score colour.
export function scoreTone(e: number): string {
  return e >= 100 ? "text-green-600 dark:text-green-400" : e > 0 ? "text-amber-600 dark:text-amber-400" : "text-red-600 dark:text-red-400";
}

// Reference eS: the route-choice checkpoint rounds shared by pursuits and APD dispatch cases.
export function PursuitRounds({
  rounds,
  myAnswers,
  opponentAnswers,
  opponentLabel,
  startsAt,
  until,
  clock,
  disabled,
  onAnswer,
}: {
  rounds: Round[];
  myAnswers: RoundAnswer[];
  opponentAnswers?: RoundAnswer[];
  opponentLabel?: string;
  startsAt: number;
  until: number;
  clock: number;
  disabled: boolean;
  onAnswer: (round: number, choice: number) => void;
}) {
  const c = myAnswers.length,
    m = rounds[c],
    x = Math.max(0, Math.min(100, ((until - clock) / Math.max(1, until - startsAt)) * 100));
  return (
    <div className="flex flex-col gap-3">
      <div className="h-1.5 w-full overflow-hidden rounded-full bg-muted">
        <div className={cn("h-full rounded-full transition-[width] duration-300", x > 30 ? "bg-primary" : "bg-red-500")} style={{ width: `${x}%` }} />
      </div>
      {clock < startsAt ? (
        <p className="text-center text-sm font-semibold text-foreground">
          {"Get ready — starting in "}
          {fmtSecs(startsAt - clock)}
        </p>
      ) : m ? (
        <>
          <p className="text-center text-[11px] text-muted-foreground">
            {m.prompt}
            {" Each obstacle adds "}
            {m.obstacleCost}
            {" to the route cost. Checkpoint "}
            {c + 1}
            {" of "}
            {rounds.length}.
          </p>
          <div className="grid grid-cols-1 gap-2 sm:grid-cols-3">
            {m.options.map((e, a) => (
              <button
                key={e.label}
                type="button"
                disabled={disabled}
                onClick={() => onAnswer(c, a)}
                className={cn(
                  "flex flex-col items-center gap-1 rounded-lg border border-border bg-surface px-3 py-3",
                  "transition hover:border-primary/40 hover:bg-primary/5 active:scale-[0.98]",
                  "disabled:cursor-not-allowed disabled:opacity-50",
                )}
              >
                <Route className="h-4 w-4 text-primary-emphasis" />
                <span className="text-xs font-bold text-foreground">{e.label}</span>
                <span className="font-mono text-[10px] text-muted-foreground">
                  {e.distance}
                  {" distance · "}
                  {e.obstacles}
                  {" obstacle"}
                  {1 === e.obstacles ? "" : "s"}
                </span>
              </button>
            ))}
          </div>
        </>
      ) : (
        <p className="text-center text-sm text-muted-foreground">All checkpoints submitted — waiting for the window to close.</p>
      )}
      {rounds.some((e, t) => myAnswers[t]) && (
        <ul className="grid grid-cols-1 gap-1 border-t border-border pt-2 text-[11px]">
          {rounds.map((e, n) => {
            const i = myAnswers[n];
            if (!i) return null;
            const l = opponentAnswers?.[n];
            return (
              <li key={e.id} className="flex items-center justify-between gap-2 font-mono">
                <span className="text-muted-foreground">
                  {"Checkpoint "}
                  {n + 1}
                </span>
                <span className="flex items-center gap-3">
                  <span className={scoreTone(i.score)}>
                    {"You "}
                    {i.score}
                  </span>
                  {opponentLabel && (
                    <span className={l ? scoreTone(l.score) : "text-muted-foreground"}>
                      {opponentLabel}
                      {" "}
                      {l ? l.score : "…"}
                    </span>
                  )}
                </span>
              </li>
            );
          })}
        </ul>
      )}
    </div>
  );
}
