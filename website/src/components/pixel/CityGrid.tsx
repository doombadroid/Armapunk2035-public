"use client";

import { MapPin, Navigation, Users } from "lucide-react";
import { cn } from "@/lib/utils";
import type { City } from "./types";

// Reference V: the "Altis" panel with the five city cards (travel targets).
export function CityGrid({
  cities,
  currentId,
  travel,
  sitesPerCity,
  heads,
  disabled,
  onTravel,
}: {
  cities: City[];
  currentId: string;
  travel: Record<string, Record<string, number>>;
  sitesPerCity: Record<string, { legal: number; illegal: number }>;
  heads: Record<string, number>;
  disabled: boolean;
  onTravel: (cityId: string) => void;
}) {
  const current = cities.find((e) => e.id === currentId);
  return (
    <div className="rounded-xl border border-border bg-card p-3">
      <div className="mb-2 flex items-center gap-2">
        <MapPin className="h-3.5 w-3.5 text-primary-emphasis" />
        <h2 className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">Altis</h2>
        {current && <p className="ml-2 truncate text-[11px] text-muted-foreground">{current.blurb}</p>}
      </div>
      <div className="grid grid-cols-2 gap-2 sm:grid-cols-3 lg:grid-cols-5">
        {cities.map((e) => {
          const o = e.id === currentId,
            d = travel[currentId]?.[e.id] ?? 0,
            c = sitesPerCity[e.id] ?? {
              legal: 0,
              illegal: 0,
            },
            m = heads[e.id] ?? 0;
          return (
            <button
              key={e.id}
              type="button"
              disabled={disabled || o}
              onClick={() => onTravel(e.id)}
              className={cn(
                "rounded-lg border p-2 text-left transition",
                "disabled:cursor-default",
                o ? "border-primary bg-primary/10" : "border-border bg-surface hover:border-primary/50 disabled:opacity-50",
              )}
            >
              <div className="flex items-center gap-1">
                <span className={cn("truncate text-xs font-bold", o ? "text-primary-emphasis" : "text-foreground")}>{e.name}</span>
                {o && <MapPin className="h-3 w-3 shrink-0 text-primary-emphasis" />}
                <span
                  className={cn("ml-auto flex shrink-0 items-center gap-0.5 font-mono text-[10px]", m > 0 ? "text-foreground" : "text-muted-foreground")}
                  title={`${m} player${1 === m ? "" : "s"} ${o ? "here" : `in ${e.name}`}`}
                >
                  <Users className="h-3 w-3" aria-hidden={true} />
                  {m}
                  <span className="sr-only">
                    {" "}
                    player{1 === m ? "" : "s"}
                    {" "}
                    {o ? "here" : `in ${e.name}`}
                  </span>
                </span>
              </div>
              <div className="mt-0.5 flex items-center gap-1.5 font-mono text-[10px]">
                <span className="text-green-700 dark:text-green-400">
                  {c.legal}
                  {" legal"}
                </span>
                <span className="text-red-700 dark:text-red-400">
                  {c.illegal}
                  {" illegal"}
                </span>
              </div>
              <div className="mt-0.5 flex items-center gap-1 font-mono text-[10px] text-muted-foreground">
                {o ? (
                  "you are here"
                ) : (
                  <>
                    <Navigation className="h-2.5 w-2.5" />
                    {d}s · ×{e.demand.toFixed(2)}
                  </>
                )}
              </div>
            </button>
          );
        })}
      </div>
    </div>
  );
}
