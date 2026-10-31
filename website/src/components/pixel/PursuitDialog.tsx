"use client";

import { useState } from "react";
import { Handshake, ShieldAlert, Siren } from "lucide-react";
import { cn } from "@/lib/utils";
import { fmtSecs } from "./format";
import { PursuitRounds } from "./PursuitRounds";
import type { Duel } from "./types";

// Reference tg: the pursuit overlay (invitation, live rounds, result).
export function PursuitDialog({
  duel,
  clock,
  disabled,
  onReady,
  onAnswer,
  onSurrender,
}: {
  duel: Duel;
  clock: number;
  disabled: boolean;
  onReady: () => void;
  onAnswer: (round: number, choice: number) => void;
  onSurrender: () => void;
}) {
  const [o, d] = useState<string | null>(null),
    c = "cop" === duel.role,
    m = c ? "Civilian" : "Officer";
  return "resolved" === duel.status && o === duel.id ? null : (
    <div role="alertdialog" className="fixed inset-0 z-[94] flex items-center justify-center bg-background/80 p-4 backdrop-blur-sm">
      <div className="w-full max-w-sm rounded-xl border border-destructive/40 bg-card p-5 shadow-2xl">
        <div className="mb-3 flex items-center gap-2">
          {c ? <Siren className="h-4 w-4 text-primary-emphasis" /> : <ShieldAlert className="h-4 w-4 text-destructive" />}
          <h2 className="text-sm font-bold text-foreground">{"resolved" === duel.status ? "Pursuit resolved" : c ? `Chasing ${duel.opponentName}` : `${duel.opponentName} is on you`}</h2>
        </div>
        {"pending" === duel.status && (
          <>
            <p className="mb-4 text-xs leading-relaxed text-muted-foreground">
              {c ? "You called it in. Ready up — the civilian gets the same window to respond." : "You’ve been made. Ready up to contest it head-to-head, or surrender now."}
            </p>
            <div className="mb-4 flex items-center justify-center gap-2 rounded-md border border-border bg-surface py-2">
              <span className="text-[10px] uppercase tracking-wide text-muted-foreground">Invitation closes in</span>
              <span className="font-mono text-lg font-bold tabular-nums text-foreground">{fmtSecs(duel.readyUntil - clock)}</span>
            </div>
            <div className="mb-3 flex items-center justify-between text-[11px] text-muted-foreground">
              <span>
                {"You: "}
                {duel.myReady ? "Ready" : "Not ready"}
              </span>
              <span>
                {m}
                {": "}
                {duel.opponentReady ? "Ready" : "Waiting..."}
              </span>
            </div>
            <div className={cn("grid gap-2", !c && "grid-cols-2")}>
              <button
                type="button"
                disabled={disabled || duel.myReady}
                onClick={onReady}
                className={cn(
                  "flex items-center justify-center gap-2 rounded-lg bg-primary px-3 py-3 text-xs font-bold uppercase",
                  "text-primary-foreground transition hover:brightness-110 active:scale-[0.98]",
                  "disabled:cursor-not-allowed disabled:opacity-50",
                )}
              >
                <Siren className="h-4 w-4" />
                {duel.myReady ? "Ready" : "Ready up"}
              </button>
              {!c && (
                <button
                  type="button"
                  disabled={disabled}
                  onClick={onSurrender}
                  className={cn(
                    "flex items-center justify-center gap-2 rounded-lg border border-destructive/40 px-3 py-3",
                    "text-xs font-bold uppercase text-destructive transition hover:bg-destructive/10 active:scale-[0.98]",
                    "disabled:cursor-not-allowed disabled:opacity-50",
                  )}
                >
                  <Handshake className="h-4 w-4" />
                  Surrender
                </button>
              )}
            </div>
            <p className="mt-3 text-center text-[10px] text-muted-foreground">
              {c
                ? "If they don't ready up in time, they're arrested automatically. If you don't, it's called off with no penalty either way."
                : "Not readying up in time gets you arrested automatically — silence isn't an escape."}
            </p>
          </>
        )}
        {"active" === duel.status && (
          <>
            <PursuitRounds
              rounds={duel.rounds}
              myAnswers={duel.myAnswers}
              opponentAnswers={duel.opponentAnswers}
              opponentLabel={m}
              startsAt={duel.startsAt}
              until={duel.until}
              clock={clock}
              disabled={disabled}
              onAnswer={onAnswer}
            />
            <p className="mt-3 text-center text-[10px] text-muted-foreground">Higher total wins. A tie escapes.</p>
            {!c && (
              <button
                type="button"
                disabled={disabled}
                onClick={onSurrender}
                className="mt-2 w-full rounded-md border border-border py-1.5 text-[10px] font-semibold uppercase text-muted-foreground transition hover:bg-surface disabled:cursor-not-allowed disabled:opacity-50"
              >
                Give up now
              </button>
            )}
          </>
        )}
        {"resolved" === duel.status && (
          <>
            <p
              className={cn(
                "mb-3 text-center text-sm font-bold uppercase tracking-wide",
                "capture" === duel.outcome
                  ? c
                    ? "text-green-600 dark:text-green-400"
                    : "text-destructive"
                  : "escape" === duel.outcome
                    ? c
                      ? "text-destructive"
                      : "text-green-600 dark:text-green-400"
                    : "text-muted-foreground",
              )}
            >
              {"capture" === duel.outcome
                ? c
                  ? "You made the arrest"
                  : "You were caught"
                : "escape" === duel.outcome
                  ? c
                    ? "They got away"
                    : "You got away"
                  : "Pursuit cancelled"}
            </p>
            {duel.reason && <p className="mb-3 text-center text-xs text-muted-foreground">{duel.reason}</p>}
            {"cancelled" !== duel.outcome && duel.startsAt > 0 && (
              <ul className="mb-1 grid grid-cols-1 gap-1 border-t border-border pt-2 text-[11px] font-mono">
                {duel.rounds.map((a, s) => (
                  <li key={a.id} className="flex items-center justify-between gap-2">
                    <span className="text-muted-foreground">
                      {"Checkpoint "}
                      {s + 1}
                    </span>
                    <span className="flex items-center gap-3">
                      <span className="text-foreground">
                        {"You "}
                        {duel.myAnswers[s]?.score ?? "—"}
                      </span>
                      <span className="text-foreground">
                        {m}
                        {" "}
                        {duel.opponentAnswers[s]?.score ?? "—"}
                      </span>
                    </span>
                  </li>
                ))}
                <li className="flex items-center justify-between gap-2 border-t border-border pt-1 font-semibold">
                  <span className="text-foreground">Total</span>
                  <span className="flex items-center gap-3">
                    <span className="text-foreground">
                      {"You "}
                      {duel.myAnswers.reduce((e, t) => e + t.score, 0)}
                    </span>
                    <span className="text-foreground">
                      {m}
                      {" "}
                      {duel.opponentAnswers.reduce((e, t) => e + t.score, 0)}
                    </span>
                  </span>
                </li>
              </ul>
            )}
            <button
              type="button"
              onClick={() => d(duel.id)}
              className="mt-3 w-full rounded-lg bg-primary px-3 py-2 text-xs font-bold uppercase text-primary-foreground transition hover:brightness-110"
            >
              Continue
            </button>
          </>
        )}
      </div>
    </div>
  );
}
