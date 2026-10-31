"use client";

import { useMemo, useState } from "react";
import { ChevronDown, Gavel, MapPin, Shield } from "lucide-react";
import { cn } from "@/lib/utils";
import { Panel } from "./primitives";
import type { RosterEntry } from "./types";

// Reference e9: FNV-1a hash of the steam id (picks the character palette).
export function fnv1a(e: string): number {
  let t = 0x811c9dc5;
  for (let a = 0; a < e.length; a++) {
    t ^= e.charCodeAt(a);
    t = Math.imul(t, 0x1000193);
  }
  return t >>> 0;
}

// Reference e8 / te / tt / ta: skin, hair, shirt and pants palettes.
const SKINS = ["#f2c9a0", "#e0a878", "#c68642", "#8d5524", "#5c3a21", "#ffdbac"],
  HAIRS = ["#2b2118", "#4a3728", "#8b5a2b", "#c9a227", "#7c2d12", "#1f2937", "#9ca3af"],
  SHIRTS = ["#dc2626", "#16a34a", "#7c3aed", "#ea580c", "#0891b2", "#db2777", "#65a30d", "#facc15"],
  PANTS = ["#1e3a5f", "#374151", "#4b3621", "#111827"];

// Reference ts: the 16x24 pixel character.
export function PixelCharacter({ steamId, isCop, jailed, travelling }: { steamId: string; isCop: boolean; jailed: boolean; travelling: boolean }) {
  const n = fnv1a(steamId),
    i = {
      skin: SKINS[n % SKINS.length],
      hair: HAIRS[(n >> 3) % HAIRS.length],
      shirt: isCop ? "#1d4ed8" : SHIRTS[(n >> 7) % SHIRTS.length],
      pants: isCop ? "#172554" : PANTS[(n >> 11) % PANTS.length],
      hatBrim: isCop,
    },
    l = `${(fnv1a(steamId) % 1200) / 1e3}s`;
  return (
    <svg
      viewBox="0 0 16 24"
      className={cn("ap-char h-16 w-auto", jailed && "ap-jailed", travelling && "opacity-40")}
      style={{
        animationDelay: l,
      }}
      shapeRendering="crispEdges"
      aria-hidden={true}
    >
      <rect x="5" y="18" width="2" height="5" fill={i.pants} />
      <rect x="9" y="18" width="2" height="5" fill={i.pants} />
      <rect x="4" y="23" width="3" height="1" fill="#1f2937" />
      <rect x="9" y="23" width="3" height="1" fill="#1f2937" />
      <rect x="4" y="11" width="8" height="7" fill={i.shirt} />
      <rect x="2" y="11" width="2" height="6" fill={i.shirt} />
      <rect x="12" y="11" width="2" height="6" fill={i.shirt} />
      <rect x="2" y="17" width="2" height="2" fill={i.skin} />
      <rect x="12" y="17" width="2" height="2" fill={i.skin} />
      {isCop ? <rect x="10" y="12" width="1" height="1" fill="#fbbf24" /> : null}
      <rect x="4" y="17" width="8" height="1" fill="#00000030" />
      <rect x="5" y="5" width="6" height="6" fill={i.skin} />
      <rect x="6" y="7" width="1" height="1" fill="#111827" />
      <rect x="9" y="7" width="1" height="1" fill="#111827" />
      {i.hatBrim ? (
        <>
          <rect x="4" y="3" width="8" height="2" fill="#172554" />
          <rect x="3" y="5" width="10" height="1" fill="#0f172a" />
          <rect x="7" y="3" width="2" height="1" fill="#fbbf24" />
        </>
      ) : (
        <>
          <rect x="5" y="3" width="6" height="2" fill={i.hair} />
          <rect x="4" y="4" width="1" height="3" fill={i.hair} />
          <rect x="11" y="4" width="1" height="3" fill={i.hair} />
        </>
      )}
      {jailed && (
        <>
          <rect x="2" y="2" width="1" height="22" fill="#64748b" opacity="0.85" />
          <rect x="6" y="2" width="1" height="22" fill="#64748b" opacity="0.85" />
          <rect x="10" y="2" width="1" height="22" fill="#64748b" opacity="0.85" />
          <rect x="13" y="2" width="1" height="22" fill="#64748b" opacity="0.85" />
        </>
      )}
    </svg>
  );
}

// Reference tr: "On the street" (the CSS street with everyone in the city).
export function StreetScene({
  cityName,
  players,
  meSteamId,
  onSelect,
}: {
  cityName: string;
  players: RosterEntry[];
  meSteamId: string;
  onSelect?: (player: RosterEntry) => void;
}) {
  const l = useMemo(() => [...players].sort((e, t) => (e.steamId === meSteamId ? -1 : t.steamId === meSteamId ? 1 : e.name.localeCompare(t.name))), [players, meSteamId]),
    [o, d] = useState(false);
  return (
    <Panel
      title={`On the street — ${cityName}`}
      icon={<MapPin className="h-3.5 w-3.5 text-primary-emphasis" />}
      right={
        <button type="button" onClick={() => d((e) => !e)} className="flex items-center gap-1 font-mono text-[10px] text-muted-foreground lg:pointer-events-none">
          {l.length}
          {" here"}
          <ChevronDown className={cn("h-3 w-3 transition-transform lg:hidden", o && "rotate-180")} />
        </button>
      }
      bodyClassName="p-0"
    >
      <div className={cn("relative overflow-x-auto", !o && "hidden lg:block")}>
        <div className="ap-street flex min-h-[132px] items-end gap-5 px-5 pb-6 pt-4">
          {0 === l.length ? (
            <p className="w-full py-8 text-center text-xs text-muted-foreground">
              {"Nobody else in "}
              {cityName}
              {" right now."}
            </p>
          ) : (
            l.map((e) => {
              const a = e.steamId === meSteamId,
                s = !!onSelect && !a;
              return (
                <div
                  key={e.steamId}
                  role={s ? "button" : undefined}
                  tabIndex={s ? 0 : undefined}
                  onClick={s ? () => onSelect(e) : undefined}
                  onKeyDown={
                    s
                      ? (t) => {
                          if ("Enter" === t.key) onSelect(e);
                        }
                      : undefined
                  }
                  title={s && e.wanted ? `${e.name} is wanted — open Patrol` : undefined}
                  className={cn("relative flex shrink-0 flex-col items-center", s && "cursor-pointer transition hover:-translate-y-0.5")}
                >
                  {e.wanted && <span className="ap-wanted absolute -top-1 rounded bg-red-600 px-1 py-px text-[8px] font-bold uppercase tracking-wide text-white">Wanted</span>}
                  <PixelCharacter steamId={e.steamId} isCop={"cop" === e.faction} jailed={e.jailed} travelling={e.travelling} />
                  <span className="-mt-1 h-1 w-8 rounded-full bg-black/25" />
                  <span
                    className={cn(
                      "mt-1.5 flex max-w-[92px] items-center gap-0.5 truncate rounded px-1.5 py-0.5 text-[10px] font-semibold",
                      a ? "bg-primary text-primary-foreground" : "bg-black/45 text-white",
                    )}
                  >
                    {"cop" === e.faction && <Shield className="h-2.5 w-2.5 shrink-0" />}
                    {e.jailed && <Gavel className="h-2.5 w-2.5 shrink-0" />}
                    <span className="truncate">{a ? "You" : e.name}</span>
                  </span>
                </div>
              );
            })
          )}
        </div>
      </div>
    </Panel>
  );
}
