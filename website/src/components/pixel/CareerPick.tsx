"use client";

import { Banknote, Pickaxe, Shield, Siren, TriangleAlert, Users } from "lucide-react";
import { cn } from "@/lib/utils";
import type { Faction } from "./types";

// Reference eF: one career card.
function CareerCard({
  tone,
  icon,
  title,
  tagline,
  points,
  cta,
  onPick,
  disabled,
}: {
  tone: Faction;
  icon: React.ReactNode;
  title: string;
  tagline: string;
  points: { icon: React.ReactNode; text: string }[];
  cta: string;
  onPick: () => void;
  disabled: boolean;
}) {
  const d = "cop" === tone;
  return (
    <div className={cn("flex flex-col rounded-xl border-2 bg-card p-5 transition", d ? "border-blue-500/40 hover:border-blue-500" : "border-border hover:border-primary")}>
      <div className={cn("mb-3 flex h-11 w-11 items-center justify-center rounded-lg", d ? "bg-blue-500/15" : "bg-primary/15")}>{icon}</div>
      <h3 className="text-lg font-bold text-foreground">{title}</h3>
      <p className="mt-1 text-xs text-muted-foreground">{tagline}</p>
      <ul className="mt-4 space-y-2">
        {points.map((e, a) => (
          <li key={a} className="flex items-start gap-2 text-xs text-foreground-secondary">
            <span className="mt-0.5 shrink-0 text-muted-foreground">{e.icon}</span>
            <span>{e.text}</span>
          </li>
        ))}
      </ul>
      <button
        type="button"
        disabled={disabled}
        onClick={onPick}
        className={cn(
          "mt-5 w-full rounded-lg px-4 py-2.5 text-sm font-bold uppercase tracking-wide transition",
          "active:scale-[0.99] disabled:cursor-not-allowed disabled:opacity-50",
          d ? "bg-blue-600 text-white hover:brightness-110" : "bg-primary text-primary-foreground hover:brightness-110",
        )}
      >
        {cta}
      </button>
    </div>
  );
}

// Reference eE: "Choose your life on Altis".
export function CareerPick({ onPick, disabled }: { onPick: (faction: Faction) => void; disabled: boolean }) {
  return (
    <div className="mx-auto max-w-3xl">
      <div className="mb-6 text-center">
        <h2 className="text-2xl font-bold text-foreground">Choose your life on Altis</h2>
        <p className="mt-2 text-sm text-muted-foreground">This decision is permanent. Pick carefully.</p>
      </div>
      <div className="grid gap-4 sm:grid-cols-2">
        <CareerCard
          tone="civ"
          icon={<Pickaxe className="h-5 w-5 text-primary-emphasis" />}
          title="Civilian"
          tagline="Work the island. Legally or otherwise."
          points={[
            {
              icon: <Pickaxe className="h-3 w-3" />,
              text: "Every gathering and processing site on the map",
            },
            {
              icon: <TriangleAlert className="h-3 w-3" />,
              text: "Full access to the underground — drugs, moonshine, uranium",
            },
            {
              icon: <Users className="h-3 w-3" />,
              text: "Hire work crews that keep producing while you're offline",
            },
            {
              icon: <Shield className="h-3 w-3" />,
              text: "Illegal work builds heat, and the APD can take everything",
            },
          ]}
          cta="Start as Civilian"
          onPick={() => onPick("civ")}
          disabled={disabled}
        />
        <CareerCard
          tone="cop"
          icon={<Shield className="h-5 w-5 text-blue-600 dark:text-blue-400" />}
          title="APD Officer"
          tagline="Keep the island honest. Take a cut for it."
          points={[
            {
              icon: <Banknote className="h-3 w-3" />,
              text: "Salary accrues every minute, online or not",
            },
            {
              icon: <Siren className="h-3 w-3" />,
              text: "Patrol to flag players carrying heat, then arrest them",
            },
            {
              icon: <Banknote className="h-3 w-3" />,
              text: "Keep a share of everything you seize, plus their fine",
            },
            {
              icon: <TriangleAlert className="h-3 w-3" />,
              text: "No illegal work, no crews, half rate on civilian jobs",
            },
          ]}
          cta="Join the APD"
          onPick={() => onPick("cop")}
          disabled={disabled}
        />
      </div>
    </div>
  );
}
