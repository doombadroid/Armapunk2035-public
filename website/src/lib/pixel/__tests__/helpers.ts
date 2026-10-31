// Shared fixtures for the Armapunk Pixel v3 engine tests: a fixed clock, a scripted rng that throws
// when the engine asks for more than the test planned, and state builders on the reference ids.
import { XP_CURVE } from "../content";
import { emptyShared, newState } from "../engine";
import type { ActionOk, ActionResult, ApplyOutcome, CareerState, Faction, PlayerState, Shared, World } from "../types";

export const NOW = 1_800_000_000_000;
export const MIN = 60_000;
export const STEAM = "76561198000000000";

/** A fresh civilian save whose first action is never rate limited, with optional overrides. */
export function fresh(over: Partial<PlayerState> = {}, faction: Faction | null = "civ"): PlayerState {
  const s = newState(STEAM, "Tester", NOW);
  s.faction = faction;
  return { ...s, ...over };
}
/** Override fields of the active career. */
export function withCareer(s: PlayerState, over: Partial<CareerState>): PlayerState {
  const f = s.faction ?? "civ";
  return { ...s, careers: { ...s.careers, [f]: { ...s.careers[f], ...over } } };
}
export function withSkills(s: PlayerState, skills: Record<string, number>): PlayerState {
  return withCareer(s, { skills: { ...s.careers[s.faction ?? "civ"].skills, ...skills } });
}
export function withTalents(s: PlayerState, talents: Record<string, number>): PlayerState {
  return withCareer(s, { talents: { ...s.careers[s.faction ?? "civ"].talents, ...talents } });
}
export function withPerks(s: PlayerState, perks: Record<string, number>): PlayerState {
  return withCareer(s, { perks: { ...s.careers[s.faction ?? "civ"].perks, ...perks } });
}
export function withBag(s: PlayerState, inventory: Record<string, number>): PlayerState {
  return withCareer(s, { inventory });
}
export function withCash(s: PlayerState, cash: number): PlayerState {
  return withCareer(s, { cash });
}
/** Total XP at which `level` begins. */
export function xpAt(level: number): number {
  return XP_CURVE[level - 1];
}
export function atLevel(s: PlayerState, level: number): PlayerState {
  return withCareer(s, { xp: xpAt(level) });
}
export function c(s: PlayerState): CareerState {
  return s.careers[s.faction ?? "civ"];
}
/** Scripted randomness: hands out the given values in order and throws if asked for more. */
export function rngOf(...values: number[]): () => number {
  const q = [...values];
  return () => {
    if (q.length === 0) throw new Error("rng exhausted");
    return q.shift() as number;
  };
}
export const noRng = () => {
  throw new Error("rng must not be called");
};
/** A deterministic pseudo-random sequence for tests that need many draws (LCG, seeded). */
export function seeded(seed = 1): () => number {
  let x = seed >>> 0;
  return () => {
    x = (Math.imul(x, 1664525) + 1013904223) >>> 0;
    return x / 4294967296;
  };
}
/** A work click that hits nothing: no bumper, no jackpot, no chest, no paper. */
export const QUIET = [1, 1, 1, 1];
export function ok(r: ApplyOutcome): ApplyOutcome & { result: ActionOk } {
  if (!r.result.ok) throw new Error(`expected ok, got "${r.result.error}"`);
  return r as ApplyOutcome & { result: ActionOk };
}
export function err(r: ApplyOutcome): string {
  if (r.result.ok) throw new Error("expected an error");
  return r.result.error;
}
export function resultOf(r: ApplyOutcome): ActionResult {
  return r.result;
}
export function shared(over: Partial<Shared> = {}): Shared {
  return { ...emptyShared(), ...over };
}
export const EMPTY_WORLD: World = {
  roster: [], gangs: [], online: 0, headsByCity: {}, feed: [], dispatch: [], suspects: [], leaderboard: [], gangMembers: {}, manpowerMult: 1,
  avatarUrl: "", chat: [], chatOldestId: 0, chatRevision: 1, chatGeneration: "gen",
};
