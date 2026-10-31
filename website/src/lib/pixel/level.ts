// Armapunk Pixel v3 levels, XP multiplier and talent points. Pure arithmetic over content tables and
// a CareerState; nothing here mutates anything. Levels are per career ("Each side has its own level").
import { CONST, GANG, STAR_PERK, TALENTS, XP_CURVE } from "./content";
import { TALENT_PCT } from "./rules";
import type { CareerState } from "./types";

/**
 * Level is the highest i+1 with xp >= XP_CURVE[i] (binary search); xpInto is the distance past that
 * threshold; xpNeeded is the width of the current level, 0 at CONST.maxLevel (the snapshot shows
 * xpNeeded 1 at level 100, i.e. the reference clamps to 1; we mirror that).
 */
export function levelFromXp(xp: number): { level: number; xpInto: number; xpNeeded: number } {
  const top = Math.min(CONST.maxLevel, XP_CURVE.length);
  let lo = 0;
  let hi = top - 1;
  while (lo < hi) {
    const mid = (lo + hi + 1) >> 1;
    if (xp >= XP_CURVE[mid]) lo = mid;
    else hi = mid - 1;
  }
  const level = lo + 1;
  const xpInto = xp - XP_CURVE[lo];
  const xpNeeded = level >= top ? 1 : XP_CURVE[lo + 1] - XP_CURVE[lo];
  return { level, xpInto, xpNeeded };
}

export function levelOf(c: CareerState): number {
  return levelFromXp(c.xp).level;
}

/** Gang level from cumulative gang XP: the highest i+1 with xp >= GANG.xpCurve[i], capped at maxLevel. */
export function gangLevelFromXp(xp: number): { level: number; xpInto: number; xpNeeded: number } {
  const curve = GANG.xpCurve;
  let lo = 0;
  for (let i = 0; i < curve.length; i++) if (xp >= curve[i]) lo = i;
  const level = Math.min(GANG.maxLevel, lo + 1);
  const xpInto = level >= GANG.maxLevel ? 0 : xp - curve[lo];
  const xpNeeded = level >= GANG.maxLevel || lo + 1 >= curve.length ? 0 : curve[lo + 1] - curve[lo];
  return { level, xpInto, xpNeeded };
}

/** Every XP gain is scaled by (1 + 0.08 quickLearner) * (1 + 0.08 starXp) * (1 + gang xpBonus). */
export function xpMultiplier(c: CareerState, gangLevel = 0): number {
  const talent = 1 + TALENT_PCT.quickLearnerXp * (c.talents.quickLearner ?? 0);
  const star = 1 + STAR_PERK.starXp.value * (c.perks.starXp ?? 0);
  const gang = 1 + GANG.xpPerLevel * gangLevel;
  return talent * star * gang;
}

/** Points sunk into talents: costs[0..rank-1] of every talent held. */
export function talentSpent(c: CareerState): number {
  let spent = 0;
  for (const t of TALENTS) {
    const rank = c.talents[t.id] ?? 0;
    for (let r = 0; r < rank && r < t.costs.length; r++) spent += t.costs[r];
  }
  return spent;
}

/** (level - 1) * talentPointsPerLevel minus what is spent, never below 0. */
export function talentPoints(c: CareerState): number {
  const earned = (levelOf(c) - 1) * CONST.talentPointsPerLevel;
  return Math.max(0, earned - talentSpent(c));
}
