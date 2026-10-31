"use client";

import { useState } from "react";
import { Anchor, Apple, Bell, Car, Crown, Fish, HelpCircle, Key, Pickaxe, Shield, ShieldAlert, Star, Truck, Zap } from "lucide-react";
import { cn } from "@/lib/utils";
import type { Checkpoint } from "./types";

// Reference tu: checkpoint option icons.
const OPTION_ICONS = {
  anchor: Anchor,
  apple: Apple,
  bell: Bell,
  car: Car,
  crown: Crown,
  fish: Fish,
  key: Key,
  pickaxe: Pickaxe,
  shield: Shield,
  star: Star,
  truck: Truck,
  zap: Zap,
} as const;

function optionIcon(name: string): React.ComponentType<{ className?: string }> {
  return name in OPTION_ICONS ? OPTION_ICONS[name as keyof typeof OPTION_ICONS] : HelpCircle;
}

// Reference th: the "Routine checkpoint" human-check overlay.
export function CheckpointDialog({
  checkpoint,
  clock,
  disabled,
  onAnswer,
  error,
}: {
  checkpoint: Checkpoint;
  clock: number;
  disabled: boolean;
  onAnswer: (id: string, answer: string) => void;
  error: string | null;
}) {
  const [l, o] = useState<string | null>(null),
    d = Math.max(0, Math.ceil((checkpoint.lockedUntil - clock) / 1e3));
  return (
    <div className="fixed inset-0 z-[95] flex items-center justify-center bg-background/80 p-4 backdrop-blur-sm">
      <div className="w-full max-w-sm rounded-xl border border-border bg-card p-5 shadow-2xl">
        <div className="mb-1 flex items-center gap-2">
          <ShieldAlert className="h-4 w-4 text-amber-500" />
          <h2 className="text-sm font-bold text-foreground">Routine checkpoint</h2>
        </div>
        <p className="mb-4 text-xs leading-relaxed text-muted-foreground">
          {"Just confirming there's a person at the wheel — automation isn't allowed on the island. Everything pauses until you answer."}
        </p>
        {d > 0 ? (
          <div className="rounded-md border border-destructive/40 bg-destructive/10 px-3 py-4 text-center">
            <p className="text-xs font-semibold text-destructive">Too many misses.</p>
            <p className="mt-1 font-mono text-lg font-bold text-foreground">
              {Math.floor(d / 60)}:{String(d % 60).padStart(2, "0")}
            </p>
            <p className="mt-1 text-[10px] text-muted-foreground">A fresh checkpoint opens when the timer runs out.</p>
          </div>
        ) : (
          <>
            <p className="mb-2 text-center text-xs font-semibold text-foreground">
              {"Tap the "}
              <span className="text-amber-600 dark:text-amber-400">{checkpoint.target}</span>
            </p>
            <div className="grid grid-cols-3 gap-2">
              {checkpoint.options.map((a) => {
                const Icon = optionIcon(a);
                return (
                  <button
                    key={a}
                    type="button"
                    disabled={disabled}
                    onClick={() => {
                      o(a);
                      onAnswer(checkpoint.id, a);
                    }}
                    aria-label={`Option ${a}`}
                    className={cn(
                      "flex h-16 items-center justify-center rounded-lg border transition",
                      "active:scale-95 disabled:cursor-not-allowed disabled:opacity-50",
                      l === a ? "border-primary/60 bg-primary/10" : "border-border bg-surface hover:border-primary/40 hover:bg-primary/5",
                    )}
                  >
                    <Icon className="h-7 w-7 text-foreground" />
                  </button>
                );
              })}
            </div>
            {error && <p className="mt-3 text-center text-[11px] font-semibold text-destructive">{error}</p>}
          </>
        )}
      </div>
    </div>
  );
}
