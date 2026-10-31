"use client";

import { useState } from "react";
import { Backpack, BadgeCheck, Check, GraduationCap, Hammer, Lock, Pause, Pickaxe, Play, Repeat, RotateCcw, Shield, Siren, Star, Truck, Users } from "lucide-react";
import { cn } from "@/lib/utils";
import { fmtCompact, fmtMoney, fmtSecs } from "./format";
import { Empty, Panel } from "./primitives";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "./ui/alert-dialog";
import type { Faction, Me, Site, SiteMode, StarPerk, Statics } from "./types";

// Reference ev: the Upgrades view of the Progression tab (skills, tools, licences, APD equipment,
// backpack, vehicle, career / prestige / star perks / wipe, work crews).
export function UpgradesTab({
  me,
  statics,
  siteMap,
  disabled,
  clock,
  contrabandUnits,
  onSkill,
  onLicense,
  onGear,
  onCopGear,
  onSwitch,
  onReset,
  onTool,
  onPack,
  onPrestige,
  onStarPerk,
  onCrewPause,
}: {
  me: Me;
  statics: Statics;
  siteMap: Record<string, Site>;
  disabled: boolean;
  clock: number;
  contrabandUnits: number;
  onSkill: (skillId: string) => void;
  onLicense: (licenseId: string) => void;
  onGear: () => void;
  onCopGear: () => void;
  onSwitch: (faction: Faction) => void;
  onReset: () => void;
  onTool: (kind: SiteMode) => void;
  onPack: () => void;
  onPrestige: () => void;
  onStarPerk: (perkId: string) => void;
  onCrewPause: (siteId: string | null, paused: boolean) => void;
}) {
  const [k, w] = useState(false),
    [N, C] = useState(false),
    [P, L] = useState<StarPerk | null>(null),
    M = statics.backpacks[me.packTier] ?? statics.backpacks[0],
    A = statics.backpacks[me.packTier + 1],
    I = !!A && me.level < A.minLevel,
    D = "cop" === me.faction,
    R = statics.skills.filter((t) => "both" === t.faction || t.faction === me.faction),
    B = statics.gear[me.gearTier + 1],
    U = statics.gear[me.gearTier],
    _ = statics.copGear[me.copGearTier] ?? statics.copGear[0],
    H = statics.copGear[me.copGearTier + 1],
    Y = !!H?.requires && !me.licenses.includes(H.requires),
    z: Faction = D ? "civ" : "cop",
    q = Math.max(0, me.careerSwitchReadyAt - clock),
    V = "cop" === z && me.heat > 1,
    K = Object.entries(me.crews)
      .filter(([, e]) => e > 0)
      .map(([t, s]) => ({
        siteId: t,
        n: s,
        site: siteMap[t],
        crew: statics.crews.find((e) => e.siteId === t),
        paused: me.pausedCrews.includes(t),
      }))
      .filter((e) => e.site && e.crew),
    X = K.length > 0 && K.every((e) => e.paused);
  return (
    <div className="grid gap-3 lg:grid-cols-2">
      <div className="space-y-3">
        <Panel
          title={D ? "APD Skills" : "Civilian Skills"}
          icon={<GraduationCap className="h-3.5 w-3.5 text-muted-foreground" />}
          right={<span className="text-[10px] text-muted-foreground">{D ? "Your civilian tree is kept, dormant" : "Your APD tree is kept, dormant"}</span>}
          bodyClassName="p-0"
        >
          <ul className="divide-y divide-border">
            {R.map((a) => {
              const r = me.skills[a.id] ?? 0,
                i = r >= a.max,
                l = i ? 0 : a.costs[r],
                d = !i && me.cash >= l,
                c =
                  "endurance" === a.id
                    ? `${me.staminaMax} max \xb7 +${me.staminaRegen.toFixed(2)}/s refill`
                    : "strength" === a.id
                      ? `${me.capacity}kg carried`
                      : null;
              return (
                <li key={a.id} className="flex items-center gap-3 px-3 py-2">
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center gap-2">
                      <span className="text-xs font-semibold text-foreground">{a.name}</span>
                      <span className={cn("rounded px-1 font-mono text-[10px]", i ? "bg-green-500/15 font-bold text-green-700 dark:text-green-400" : "text-primary-emphasis")}>
                        {r}/{a.max}
                        {i && " MAX"}
                      </span>
                    </div>
                    <p className="truncate text-[10px] text-muted-foreground">{a.blurb}</p>
                    {c && (
                      <p className="font-mono text-[10px] text-primary-emphasis">
                        {"Now: "}
                        {c}
                      </p>
                    )}
                    <div className="mt-1 flex gap-0.5">
                      {Array.from(
                        {
                          length: a.max,
                        },
                        (e, a) => <span key={a} className={cn("h-1 flex-1 rounded-sm", a < r ? "bg-primary" : "bg-muted")} />,
                      )}
                    </div>
                  </div>
                  <button
                    type="button"
                    disabled={disabled || i || !d}
                    onClick={() => onSkill(a.id)}
                    className={cn(
                      "shrink-0 rounded-md px-2.5 py-1.5 text-[10px] font-bold uppercase transition",
                      "disabled:cursor-not-allowed disabled:opacity-40",
                      i ? "bg-muted text-muted-foreground" : "bg-primary text-primary-foreground hover:brightness-110",
                    )}
                  >
                    {i ? "Max" : fmtCompact(l)}
                  </button>
                </li>
              );
            })}
          </ul>
        </Panel>
        {!D && (
          <Panel title="Tools" icon={<Pickaxe className="h-3.5 w-3.5 text-muted-foreground" />} bodyClassName="p-0">
            <ul className="divide-y divide-border">
              {(["gather", "process"] as const).map((s) => {
                const r = statics.tools.filter((e) => e.kind === s).sort((e, t) => e.tier - t.tier),
                  i = me.tools[s] ?? 0,
                  l = r[Math.min(i, r.length - 1)],
                  o = r[i + 1],
                  d = !!o && me.level < o.minLevel,
                  c = !!o && me.cash >= o.cost,
                  Icon = "gather" === s ? Pickaxe : Hammer;
                return (
                  <li key={s} className="flex items-center gap-3 px-3 py-2">
                    <div className="min-w-0 flex-1">
                      <div className="flex items-center gap-1.5">
                        <Icon className="h-3 w-3 text-muted-foreground" />
                        <span className="text-xs font-semibold text-foreground">{l.name}</span>
                        <span className="font-mono text-[10px] text-primary-emphasis">x{l.mult.toFixed(2)}</span>
                        <span className="text-[10px] text-muted-foreground">{"gather" === s ? "gathering" : "processing"}</span>
                      </div>
                      <p className="mt-0.5 text-[10px] leading-relaxed text-muted-foreground">
                        {o ? (d ? `${o.name} unlocks at level ${o.minLevel}.` : `${o.name} — ${o.blurb}`) : "Top of the ladder — nothing better is made."}
                      </p>
                      <div className="mt-1 flex gap-0.5">
                        {r.map((e, a) => (
                          <span key={e.tier} className={cn("h-1 flex-1 rounded-sm", a <= i ? "bg-primary" : "bg-muted")} />
                        ))}
                      </div>
                    </div>
                    <button
                      type="button"
                      disabled={disabled || !o || d || !c}
                      onClick={() => onTool(s)}
                      className={cn(
                        "inline-flex shrink-0 items-center gap-1 rounded-md px-2.5 py-1.5",
                        "text-[10px] font-bold uppercase transition",
                        "disabled:cursor-not-allowed disabled:opacity-40",
                        o ? "bg-primary text-primary-foreground hover:brightness-110" : "bg-muted text-muted-foreground",
                      )}
                    >
                      {o ? (
                        d ? (
                          <>
                            <Lock className="h-3 w-3" />
                            {"Lv "}
                            {o.minLevel}
                          </>
                        ) : (
                          fmtCompact(o.cost)
                        )
                      ) : (
                        <>
                          <Check className="h-3 w-3" />
                          Max
                        </>
                      )}
                    </button>
                  </li>
                );
              })}
            </ul>
          </Panel>
        )}
      </div>
      <div className="space-y-3">
        <Panel title="Licenses" icon={<BadgeCheck className="h-3.5 w-3.5 text-muted-foreground" />} bodyClassName="p-0">
          <ul className="divide-y divide-border">
            {statics.licenses
              .filter((e) => !(D && !e.legal))
              .filter((t) => !t.faction || t.faction === me.faction)
              .map((a) => {
                const s = me.licenses.includes(a.id),
                  r = me.cash >= a.cost;
                return (
                  <li key={a.id} className="flex items-center gap-3 px-3 py-2">
                    <div className="min-w-0 flex-1">
                      <div className="flex items-center gap-1.5">
                        <span className="truncate text-xs font-medium text-foreground">{a.name}</span>
                        {!a.legal && <span className="shrink-0 rounded bg-red-500/15 px-1 py-0.5 text-[9px] font-semibold uppercase text-red-700 dark:text-red-400">Illegal</span>}
                      </div>
                      <span className="font-mono text-[10px] text-muted-foreground">
                        {fmtMoney(a.cost)}
                        {a.effect && <span className="ml-1.5 text-primary-emphasis">{a.effect}</span>}
                      </span>
                    </div>
                    {s ? (
                      <span className="inline-flex shrink-0 items-center gap-1 rounded-md bg-green-500/15 px-2 py-1 text-[10px] font-semibold text-green-700 dark:text-green-400">
                        <Check className="h-3 w-3" />
                        {" Held"}
                      </span>
                    ) : (
                      <button
                        type="button"
                        disabled={disabled || !r}
                        onClick={() => onLicense(a.id)}
                        className="shrink-0 rounded-md bg-primary px-2.5 py-1.5 text-[10px] font-bold uppercase text-primary-foreground transition hover:brightness-110 disabled:cursor-not-allowed disabled:opacity-40"
                      >
                        Buy
                      </button>
                    )}
                  </li>
                );
              })}
          </ul>
        </Panel>
        {D && (
          <Panel title="APD Equipment" icon={<Siren className="h-3.5 w-3.5 text-blue-600 dark:text-blue-400" />} className="border-blue-500/30">
            <div className="flex items-center gap-3">
              <div className="min-w-0 flex-1">
                <div className="text-xs font-semibold text-foreground">{_?.name}</div>
                <p className="text-[10px] text-muted-foreground">{_?.blurb}</p>
                <div className="mt-1 flex flex-wrap gap-x-2.5 font-mono text-[10px] text-blue-700 dark:text-blue-300">
                  <span>+{Math.round((_?.bustBonus ?? 0) * 100)}% arrest</span>
                  <span>
                    ×{(_?.bountyMult ?? 1).toFixed(2)}
                    {" bounty"}
                  </span>
                  <span>
                    {_?.staminaDelta ?? 0}
                    {" stamina/patrol"}
                  </span>
                </div>
                {H && (
                  <div className="mt-1.5 border-t border-border pt-1.5 font-mono text-[10px] text-muted-foreground">
                    {"Next: "}
                    <span className="text-foreground">{H.name}</span>
                    {" · "}+{Math.round(100 * H.bustBonus)}% arrest{" · "}×{H.bountyMult.toFixed(2)}
                    {" bounty"}
                    {Y && (
                      <span className="ml-1 inline-flex items-center gap-0.5 text-amber-600 dark:text-amber-400">
                        <Lock className="h-2.5 w-2.5" />
                        {"needs "}
                        {statics.licenses.find((e) => e.id === H.requires)?.name}
                      </span>
                    )}
                  </div>
                )}
              </div>
              <button
                type="button"
                disabled={disabled || !H || Y || me.cash < (H?.cost ?? 0)}
                onClick={onCopGear}
                className="shrink-0 rounded-md bg-blue-600 px-3 py-2 text-[10px] font-bold uppercase text-white transition hover:brightness-110 disabled:cursor-not-allowed disabled:opacity-40"
              >
                {H ? fmtCompact(H.cost) : "Maxed"}
              </button>
            </div>
          </Panel>
        )}
        {!D && (
          <>
            <Panel title="Backpack" icon={<Backpack className="h-3.5 w-3.5 text-muted-foreground" />}>
              <div className="flex items-center gap-3">
                <div className="min-w-0 flex-1">
                  <div className="text-xs font-semibold text-foreground">{M.name}</div>
                  <div className="font-mono text-[10px] text-muted-foreground">{M.capacity}kg on your back</div>
                  {A && (
                    <div className="mt-1 font-mono text-[10px] text-primary-emphasis">
                      {"Next: "}
                      {A.name}
                      {" — "}
                      {A.capacity}kg{I ? ` (level ${A.minLevel})` : ""}
                    </div>
                  )}
                </div>
                <button
                  type="button"
                  disabled={disabled || !A || I || me.cash < (A?.cost ?? 0)}
                  onClick={onPack}
                  className="shrink-0 rounded-md bg-primary px-3 py-2 text-[10px] font-bold uppercase text-primary-foreground transition hover:brightness-110 disabled:cursor-not-allowed disabled:opacity-40"
                >
                  {A ? (I ? `Lv ${A.minLevel}` : fmtCompact(A.cost)) : "Maxed"}
                </button>
              </div>
            </Panel>
            <Panel title="Vehicle" icon={<Truck className="h-3.5 w-3.5 text-muted-foreground" />}>
              <div className="flex items-center gap-3">
                <div className="min-w-0 flex-1">
                  <div className="text-xs font-semibold text-foreground">{U?.name}</div>
                  <div className="font-mono text-[10px] text-muted-foreground">
                    +{U?.capacity}kg cargo · travel x{U?.speed.toFixed(2)}
                    {" · "}
                    {me.capacity}kg total
                  </div>
                  {B && (
                    <div className="mt-1 font-mono text-[10px] text-primary-emphasis">
                      {"Next: "}
                      {B.name}
                      {" — +"}
                      {B.capacity}kg, travel x{B.speed.toFixed(2)}
                    </div>
                  )}
                </div>
                <button
                  type="button"
                  disabled={disabled || !B || me.cash < (B?.cost ?? 0)}
                  onClick={onGear}
                  className="shrink-0 rounded-md bg-primary px-3 py-2 text-[10px] font-bold uppercase text-primary-foreground transition hover:brightness-110 disabled:cursor-not-allowed disabled:opacity-40"
                >
                  {B ? fmtCompact(B.cost) : "Maxed"}
                </button>
              </div>
            </Panel>
          </>
        )}
        <Panel title="Career" icon={<Repeat className="h-3.5 w-3.5 text-muted-foreground" />}>
          <div className="flex items-center gap-3">
            <div className="min-w-0 flex-1">
              <div className="flex items-center gap-1.5">
                {D && <Shield className="h-3 w-3 text-blue-600 dark:text-blue-400" />}
                <span className="text-xs font-semibold text-foreground">
                  {"Currently "}
                  {D ? "APD Officer" : "Civilian"}
                </span>
              </div>
              <p className="mt-0.5 text-[10px] leading-relaxed text-muted-foreground">
                {V
                  ? "The APD will not take you while you are under investigation. Let your heat cool."
                  : q > 0
                    ? `Paperwork pending — ${fmtSecs(q)}.`
                    : `Switch to your saved ${"cop" === z ? "APD" : "civilian"} cash, level, licences, prestige and upgrades. This career stays saved.`}
              </p>
              {"cop" === z && contrabandUnits > 0 && !V && (
                <p className="mt-1 text-[10px] leading-relaxed text-amber-700 dark:text-amber-400">
                  {"You are carrying "}
                  {contrabandUnits}
                  {
                    " units of contraband. You can still enlist — your civilian bag is stored intact and restored when you hand the badge back. APD duty starts from its own bag."
                  }
                </p>
              )}
            </div>
            <button
              type="button"
              disabled={disabled || q > 0 || V}
              onClick={() => onSwitch(z)}
              className={cn(
                "shrink-0 rounded-md px-3 py-2 text-[10px] font-bold uppercase transition",
                "disabled:cursor-not-allowed disabled:opacity-40",
                "cop" === z ? "bg-blue-600 text-white hover:brightness-110" : "bg-primary text-primary-foreground hover:brightness-110",
              )}
            >
              {"cop" === z ? "Join APD" : "Go civilian"}
            </button>
          </div>
          {(me.prestigeReady || me.prestige > 0 || me.level >= 20) && (
            <div className="mt-3 flex items-center gap-3 border-t border-border pt-3">
              <Star className={cn("h-4 w-4 shrink-0", me.prestigeReady ? "text-amber-500" : "text-muted-foreground")} />
              <div className="min-w-0 flex-1">
                <div className="flex items-center gap-1.5">
                  <span className="text-xs font-semibold text-foreground">
                    {D ? "APD" : "Civilian"}
                    {" Prestige "}
                    {me.prestige > 0 ? me.prestige : ""}
                  </span>
                  {me.prestige > 0 && (
                    <span className="rounded bg-amber-500/15 px-1.5 py-0.5 font-mono text-[10px] font-semibold text-amber-700 dark:text-amber-400">
                      ★{me.prestige}
                      {" / "}
                      {statics.prestige.max}
                    </span>
                  )}
                </div>
                <p className="mt-0.5 text-[10px] leading-relaxed text-muted-foreground">
                  {me.prestigeReady
                    ? "Everything is bought, the fee is in hand. Reset this career onto its next tier and earn one of its permanent stars."
                    : "Finish this career: max level, all of its upgrades, and the ascension fee. The other faction is never reset."}
                </p>
                {!me.prestigeReady && me.prestigeBlockers.length > 0 && (
                  <ul className="mt-1 space-y-0.5">
                    {me.prestigeBlockers.map((e) => (
                      <li key={e} className="flex items-center gap-1 text-[10px] text-muted-foreground">
                        <Lock className="h-2.5 w-2.5 shrink-0 text-amber-600 dark:text-amber-500" />
                        {e}
                      </li>
                    ))}
                  </ul>
                )}
              </div>
              <button
                type="button"
                disabled={disabled || !me.prestigeReady}
                onClick={() => C(true)}
                className={cn(
                  "inline-flex shrink-0 items-center gap-1.5 rounded-md px-3 py-2 text-[10px] font-bold uppercase transition",
                  "disabled:cursor-not-allowed disabled:opacity-40",
                  me.prestigeReady ? "bg-amber-500 text-amber-950 hover:brightness-110" : "border border-border text-muted-foreground",
                )}
              >
                <Star className="h-3 w-3" />
                {me.prestigeReady ? "Prestige" : "Not yet"}
              </button>
            </div>
          )}
          {(me.prestige > 0 || me.starPicks > 0) && (
            <div className="mt-3 border-t border-border pt-3">
              <div className="mb-1.5 flex items-center justify-between">
                <span className="text-xs font-semibold text-foreground">
                  {D ? "APD" : "Civilian"}
                  {" star perks"}
                </span>
                {me.starPicks > 0 ? (
                  <span className="rounded bg-amber-500/15 px-1.5 py-0.5 font-mono text-[10px] font-bold text-amber-700 dark:text-amber-400">
                    {me.starPicks}
                    {" star"}
                    {me.starPicks > 1 ? "s" : ""}
                    {" to spend"}
                  </span>
                ) : (
                  <span className="text-[10px] text-muted-foreground">next pick at your next prestige</span>
                )}
              </div>
              <div className="space-y-1">
                {statics.starPerks
                  .filter((t) => "both" === t.faction || t.faction === me.faction)
                  .map((a) => {
                    const s = me.perks[a.id] ?? 0,
                      r = s >= a.max,
                      i = me.starPicks > 0 && !r;
                    return (
                      <div key={a.id} className={cn("flex items-center gap-2 rounded-md border px-2 py-1.5", s > 0 ? "border-amber-500/30 bg-amber-500/5" : "border-border bg-surface")}>
                        <div className="min-w-0 flex-1">
                          <div className="flex items-center gap-1.5">
                            <span className="text-[11px] font-semibold text-foreground">{a.name}</span>
                            <span className="font-mono text-[10px] text-muted-foreground">
                              {s}/{a.max}
                            </span>
                          </div>
                          <p className="text-[10px] leading-snug text-muted-foreground">{a.blurb}</p>
                        </div>
                        <button
                          type="button"
                          disabled={disabled || !i}
                          onClick={() => L(a)}
                          className={cn(
                            "shrink-0 rounded-md px-2.5 py-1.5 text-[10px] font-bold uppercase transition",
                            "disabled:cursor-not-allowed disabled:opacity-40",
                            i ? "bg-amber-500 text-amber-950 hover:brightness-110" : "border border-border text-muted-foreground",
                          )}
                        >
                          {r ? "Max" : "Pick"}
                        </button>
                      </div>
                    );
                  })}
              </div>
            </div>
          )}
          <AlertDialog
            open={null !== P}
            onOpenChange={(e) => {
              if (!e) L(null);
            }}
          >
            <AlertDialogContent>
              <AlertDialogHeader>
                <AlertDialogTitle>
                  {"Spend a star on "}
                  {P?.name}?
                </AlertDialogTitle>
                <AlertDialogDescription>
                  {P?.blurb}
                  {"This is permanent — star perks are never refunded or respecced, applies only to this career, and the star is gone until this career's next prestige."}
                </AlertDialogDescription>
              </AlertDialogHeader>
              <AlertDialogFooter>
                <AlertDialogCancel>Cancel</AlertDialogCancel>
                <AlertDialogAction
                  onClick={() => {
                    if (P) onStarPerk(P.id);
                    L(null);
                  }}
                >
                  Attune the star
                </AlertDialogAction>
              </AlertDialogFooter>
            </AlertDialogContent>
          </AlertDialog>
          <AlertDialog open={N} onOpenChange={C}>
            <AlertDialogContent>
              <AlertDialogHeader>
                <AlertDialogTitle>
                  {"Prestige this "}
                  {D ? "APD" : "civilian"}
                  {" run?"}
                </AlertDialogTitle>
                <AlertDialogDescription>
                  {"Your "}
                  {fmtMoney(me.cash)}
                  {", level "}
                  {me.level}
                  {", every licence, skill, talent, bag and upgrade owned by this career resets to square one on the next tier. "}
                  {D ? "Your civilian vehicles, tools, crews and bag are untouched." : "Your APD progression and bag are untouched; your civilian crews restart too."}
                  {" "}
                  {"You keep shared chests, contract papers, lifetime stats and this career's star perks, and earn a new star for this career."}
                </AlertDialogDescription>
              </AlertDialogHeader>
              <AlertDialogFooter>
                <AlertDialogCancel>Cancel</AlertDialogCancel>
                <AlertDialogAction
                  onClick={() => {
                    C(false);
                    onPrestige();
                  }}
                >
                  Ascend
                </AlertDialogAction>
              </AlertDialogFooter>
            </AlertDialogContent>
          </AlertDialog>
          <div className="mt-3 flex items-center gap-3 border-t border-border pt-3">
            <p className="min-w-0 flex-1 text-[10px] leading-relaxed text-muted-foreground">
              Wipe this save and start again from the career picker. Cash, level, licences, upgrades and crews are all destroyed. This cannot be undone.
            </p>
            <button
              type="button"
              disabled={disabled}
              onClick={() => w(true)}
              className={cn(
                "inline-flex shrink-0 items-center gap-1.5 rounded-md border border-destructive/40 px-3 py-2",
                "text-[10px] font-bold uppercase text-destructive transition",
                "hover:bg-destructive/10 disabled:cursor-not-allowed disabled:opacity-40",
              )}
            >
              <RotateCcw className="h-3 w-3" />
              Start over
            </button>
          </div>
          <AlertDialog open={k} onOpenChange={w}>
            <AlertDialogContent>
              <AlertDialogHeader>
                <AlertDialogTitle>Wipe your save?</AlertDialogTitle>
                <AlertDialogDescription>
                  {"Your "}
                  {fmtMoney(me.cash)}
                  {", level "}
                  {me.level}, every licence and upgrade you have bought and all of your crews will be deleted permanently. You will be returned to the career picker. This
                  cannot be undone.
                </AlertDialogDescription>
              </AlertDialogHeader>
              <AlertDialogFooter>
                <AlertDialogCancel>Cancel</AlertDialogCancel>
                <AlertDialogAction
                  onClick={() => {
                    w(false);
                    onReset();
                  }}
                >
                  Wipe save
                </AlertDialogAction>
              </AlertDialogFooter>
            </AlertDialogContent>
          </AlertDialog>
        </Panel>
        {!D && (
          <Panel
            title="Work Crews"
            icon={<Users className="h-3.5 w-3.5 text-muted-foreground" />}
            right={
              K.length > 0 ? (
                <button
                  type="button"
                  disabled={disabled}
                  onClick={() => onCrewPause(null, !X)}
                  className="inline-flex items-center gap-1 rounded border border-border px-1.5 py-0.5 text-[10px] font-semibold text-muted-foreground transition hover:bg-muted hover:text-foreground disabled:cursor-not-allowed disabled:opacity-40"
                >
                  {X ? <Play className="h-2.5 w-2.5" /> : <Pause className="h-2.5 w-2.5" />}
                  {X ? "Resume all" : "Pause all"}
                </button>
              ) : (
                <span className="text-[10px] text-muted-foreground">{"Produce while you're away"}</span>
              )
            }
            bodyClassName="p-0"
          >
            {0 === K.length ? (
              <Empty>No crews yet — hire one from any gathering site.</Empty>
            ) : (
              <ul className="divide-y divide-border">
                {K.map(({ siteId, n, site, crew, paused }) => (
                  <li key={siteId} className="flex items-center gap-2 px-3 py-2">
                    <span className={cn("min-w-0 flex-1 truncate text-xs", paused ? "text-muted-foreground" : "text-foreground")}>
                      {site.name}
                      {!site.legal && <span className="ml-1 text-[9px] font-semibold uppercase text-red-700 dark:text-red-400">illegal</span>}
                    </span>
                    <span className="shrink-0 font-mono text-[10px] text-muted-foreground">
                      {n}
                      {" crew"}
                    </span>
                    {paused ? (
                      <span className="shrink-0 rounded bg-muted px-1.5 py-0.5 font-mono text-[10px] font-semibold text-muted-foreground">Paused</span>
                    ) : (
                      <span className="shrink-0 rounded bg-green-500/15 px-1.5 py-0.5 font-mono text-[10px] font-semibold text-green-700 dark:text-green-400">
                        +{(crew?.perMinute ?? 0) * n}/min
                      </span>
                    )}
                    <button
                      type="button"
                      disabled={disabled}
                      title={paused ? "Put this crew back to work" : "Park this crew — no output, no XP, no heat. Free to resume."}
                      onClick={() => onCrewPause(siteId, !paused)}
                      className="inline-flex shrink-0 items-center justify-center rounded border border-border p-1 text-muted-foreground transition hover:bg-muted hover:text-foreground disabled:cursor-not-allowed disabled:opacity-40"
                    >
                      {paused ? <Play className="h-3 w-3" /> : <Pause className="h-3 w-3" />}
                    </button>
                  </li>
                ))}
              </ul>
            )}
            <p className="px-3 pb-2 pt-1.5 text-[10px] leading-relaxed text-muted-foreground">
              Pausing keeps the crew — resuming is free. A parked crew produces nothing, earns no XP and, at an illegal site, generates no heat.
            </p>
          </Panel>
        )}
      </div>
    </div>
  );
}
