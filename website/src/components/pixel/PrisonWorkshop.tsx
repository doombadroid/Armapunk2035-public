"use client";

import { Lock, RotateCw, Wrench } from "lucide-react";
import { cn } from "@/lib/utils";
import { fmtSecs } from "./format";
import { Panel } from "./primitives";
import type { Me } from "./types";

// Reference tb: the four pipe directions of a tile bitmask.
const PIPE_DIRS = [
  {
    bit: 1,
    x2: 20,
    y2: 2,
  },
  {
    bit: 2,
    x2: 38,
    y2: 20,
  },
  {
    bit: 4,
    x2: 20,
    y2: 38,
  },
  {
    bit: 8,
    x2: 2,
    y2: 20,
  },
];

// Reference ty: one rotatable pipe tile.
function PipeTile({ mask, isSource, isSink, disabled, onClick }: { mask: number; isSource: boolean; isSink: boolean; disabled: boolean; onClick: () => void }) {
  return (
    <button
      type="button"
      disabled={disabled}
      onClick={onClick}
      aria-label={isSource ? "Inlet tile — rotate" : isSink ? "Outlet tile — rotate" : "Rotate tile"}
      className={cn(
        "relative flex h-11 w-11 items-center justify-center rounded-md border bg-surface transition",
        "hover:border-primary/40 active:scale-95 disabled:cursor-not-allowed disabled:opacity-60",
        isSource || isSink ? "border-primary/50" : "border-border",
      )}
    >
      <svg viewBox="0 0 40 40" className="h-full w-full text-primary-emphasis">
        {PIPE_DIRS.filter((t) => mask & t.bit).map((e) => (
          <line key={e.bit} x1={20} y1={20} x2={e.x2} y2={e.y2} stroke="currentColor" strokeWidth={4} strokeLinecap="round" />
        ))}
        <circle cx={20} cy={20} r={4} fill="currentColor" />
      </svg>
      {isSource && <span className="absolute -left-1 top-1/2 -translate-x-full -translate-y-1/2 text-[9px] font-bold uppercase text-muted-foreground">In</span>}
      {isSink && <span className="absolute -right-1 top-1/2 -translate-x-[-100%] -translate-y-1/2 text-[9px] font-bold uppercase text-muted-foreground">Out</span>}
    </button>
  );
}

// Reference tj: "Prison workshop" (the pipe puzzle that shaves time off a sentence).
export function PrisonWorkshop({
  me,
  clock,
  disabled,
  onStart,
  onRotate,
  onComplete,
}: {
  me: Me;
  clock: number;
  disabled: boolean;
  onStart: () => void;
  onRotate: (tile: number) => void;
  onComplete: () => void;
}) {
  const l = me.custody;
  if (!l) return null;
  const o = l.job,
    d = !!o && clock >= o.readyAt;
  return (
    <Panel
      title="Prison workshop"
      icon={<Wrench className="h-3.5 w-3.5 text-muted-foreground" />}
      right={
        <span className="font-mono text-[10px] text-muted-foreground">
          {"Released in "}
          {fmtSecs(me.jailedUntil - clock)}
        </span>
      }
    >
      {o ? (
        <div className="flex flex-col items-center gap-3">
          <p className="text-center text-[11px] text-muted-foreground">
            Rotate tiles to connect the inlet (left) to the outlet (right). Worth{" "}
            <span className="font-mono font-semibold text-foreground">{l.availableCreditSeconds}s</span>
            {" off your sentence."}
          </p>
          <div className="grid grid-cols-3 gap-1.5">
            {o.tiles.map((e, a) => (
              <PipeTile key={a} mask={e} isSource={0 === a} isSink={a === o.tiles.length - 1} disabled={disabled} onClick={() => onRotate(a)} />
            ))}
          </div>
          <button
            type="button"
            disabled={disabled || !d}
            onClick={onComplete}
            className={cn(
              "flex items-center gap-1.5 rounded-lg px-4 py-2 text-xs font-bold uppercase transition",
              d ? "bg-primary text-primary-foreground hover:brightness-110" : "bg-muted text-muted-foreground",
              "disabled:cursor-not-allowed",
            )}
          >
            <RotateCw className="h-3.5 w-3.5" />
            {d ? "Submit repair" : `Working... ${fmtSecs(o.readyAt - clock)}`}
          </button>
        </div>
      ) : l.availableCreditSeconds > 0 ? (
        <div className="flex flex-col items-center gap-2 py-4 text-center">
          <Lock className="h-6 w-6 text-muted-foreground" />
          <p className="max-w-xs text-xs text-muted-foreground">
            Connect the inlet to the outlet to shave up to{" "}
            <span className="font-mono font-semibold text-foreground">{l.availableCreditSeconds}s</span>
            {" "}
            off your sentence. Takes at least 20 seconds either way; a failed attempt costs nothing and can be retried.
          </p>
          <button
            type="button"
            disabled={disabled}
            onClick={onStart}
            className="rounded-lg bg-primary px-4 py-2 text-xs font-bold uppercase text-primary-foreground transition hover:brightness-110 disabled:cursor-not-allowed disabled:opacity-50"
          >
            Start work detail
          </button>
        </div>
      ) : (
        <p className="py-4 text-center text-xs text-muted-foreground">
          {l.workRemainingSeconds <= 0
            ? "You've worked off as much of this sentence as the rules allow — ride out the rest, or pay to leave."
            : "No eligible work time yet — the first 60 seconds of any sentence must be served."}
        </p>
      )}
    </Panel>
  );
}
