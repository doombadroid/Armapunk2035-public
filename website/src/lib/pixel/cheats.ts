// Owner cheats. Armapunk Pixel is a closed test on the owner's own save (access.ts), and the owner
// asked for three standing advantages: stamina that never runs out, the top prestige star, and no
// rate limit on actions. They are
// resolved from the Steam id in the store (the only layer allowed to read the environment) and ride
// on the save as `state.cheats`, so the engine stays pure and every rule can be tested with the
// flags on or off. Nothing about them reaches the wire: `view.ts` keeps the reference's `me` shape,
// so the client just sees a full stamina bar and prestige 25.
import { PRESTIGE, STAR_PERK } from "./content";
import type { CareerState, PixelCheats, PlayerState } from "./types";

export const NO_CHEATS: PixelCheats = { unlimitedStamina: false, maxPrestige: false, noRateLimit: false };
const OWNER_CHEATS: PixelCheats = { unlimitedStamina: true, maxPrestige: true, noRateLimit: true };

/**
 * The cheats a Steam id gets. Only the owner account named by `OWNER_STEAMID` has any; everyone else
 * plays the reference rules, so opening the game up later needs no change here.
 */
export function cheatsFor(steamId: string, ownerId: string | undefined): PixelCheats {
  return ownerId && steamId === ownerId ? { ...OWNER_CHEATS } : { ...NO_CHEATS };
}

/** The cheats on a save, or none. Every engine rule asks through here. */
export function cheats(s: PlayerState): PixelCheats {
  return s.cheats ?? NO_CHEATS;
}

/** Star perk ranks already attuned in a career (each rank cost one pick). */
export function perkRanksSpent(c: CareerState): number {
  let n = 0;
  for (const id of Object.keys(STAR_PERK)) n += c.perks[id] ?? 0;
  return n;
}

/**
 * Hold both careers at the top star. A prestige run normally wipes the career and hands back one
 * pick per star, so the cheat's picks are `PRESTIGE.max` minus what is already attuned: spending a
 * pick keeps it spent, and no amount of ticking hands out a twenty-sixth star. Idempotent by
 * construction, which is what lets `settle()` call it on every tick.
 */
export function enforceMaxPrestige(s: PlayerState): void {
  if (!cheats(s).maxPrestige) return;
  for (const c of [s.careers.civ, s.careers.cop]) {
    if (c.prestige < PRESTIGE.max) c.prestige = PRESTIGE.max;
    const picks = PRESTIGE.max - perkRanksSpent(c);
    c.starPicks = Math.max(0, picks);
  }
}
