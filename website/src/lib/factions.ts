import { COP_RANKS, MEDIC_RANKS, ADMIN_LEVELS } from "./ranks";

// adminlevel >= this => may view player logs AND whitelist any rank/faction.
export const ADMIN_WL_LEVEL = 4;
// adminlevel >= this => excluded from public leaderboards (can spawn money/ranks).
export const STAFF_LEVEL = 1;
// adminlevel >= this => may edit economy/progression (money, cars, gang funds).
export const ECON_EDIT_LEVEL = 3;
// adminlevel >= this (Senior Admin) => may lock + reboot the game server.
// Updating the PBO (repack + deploy) is owner-only (isOwner), gated separately.
export const SERVER_CTRL_LEVEL = 4;

// Sub-whitelist = an on/off role flag inside a faction (MaxTac, SCD, ...).
// Stored on the per-character `players` table.
export interface SubFlag { key: string; label: string; column: string }

export interface Faction {
  key: string;            // 'police' | 'medic' | 'staff'
  label: string;
  column: "coplevel" | "mediclevel" | "adminlevel"; // players_global column = source of truth
  max: number;            // highest rank
  ranks: Record<number, string>;
  minWhitelister: number; // lowest rank with ANY whitelist power
  subs: SubFlag[];        // on/off role whitelists within the faction
  ownerOnly?: boolean;    // only the server owner may grant (no admin override)
}

// Extensible registry — add a faction by adding an entry (+ its DB column).
export const FACTIONS: Record<string, Faction> = {
  police: {
    key: "police", label: "MaxSec (Police)", column: "coplevel",
    max: 7, ranks: COP_RANKS, minWhitelister: 5, // LT+
    subs: [
      { key: "maxtac", label: "MaxTac", column: "ismaxtac" },
      { key: "scd", label: "Street Crime Division", column: "isscd" },
    ],
  },
  medic: {
    key: "medic", label: "Trauma Team", column: "mediclevel",
    max: 7, ranks: MEDIC_RANKS, minWhitelister: 4, // TT Warrant Officer+
    subs: [],
  },
  staff: {
    key: "staff", label: "Server Staff", column: "adminlevel",
    max: 5, ranks: ADMIN_LEVELS, minWhitelister: 99, // owner-only (rank threshold N/A)
    subs: [], ownerOnly: true,
  },
};

export function getFaction(key: string): Faction | null {
  return FACTIONS[key] ?? null;
}

export interface ActorPowers {
  uid: string;
  adminlevel: number;
  isOwner: boolean;
  ranks: Record<string, number>; // faction key -> actor's rank in that faction
}

export function isAdminPlus(p: ActorPowers): boolean {
  return p.isOwner || p.adminlevel >= ADMIN_WL_LEVEL;
}

/** Highest rank the actor may GRANT in a faction. -1 = no power at all. */
export function maxGrant(f: Faction, p: ActorPowers): number {
  if (f.ownerOnly) return p.isOwner ? f.max : -1; // owner-exclusive, no admin override
  if (isAdminPlus(p)) return f.max; // any rank
  const r = p.ranks[f.key] ?? 0;
  if (r >= f.minWhitelister) return r - 1; // up to one below their own
  return -1;
}

/** Out-of-ladder values (e.g. TT's 99 Volunteer sentinel) sort as the lowest tier. */
function effRank(f: Faction, rank: number): number {
  return rank >= 1 && rank <= f.max ? rank : 0;
}

/** Can the actor set `targetCurrentRank` -> `newRank` in this faction? */
export function canManage(
  f: Faction, p: ActorPowers, targetCurrentRank: number, newRank: number
): boolean {
  const mg = maxGrant(f, p);
  if (mg < 0) return false;
  if (newRank < 0 || newRank > mg) return false;        // can't grant above cap
  if (effRank(f, targetCurrentRank) > mg) return false; // can't touch higher-ranked
  return true;
}

/** Sub-flags (MaxTac/SCD) use the same gate as rank whitelisting: must have
 *  whitelist power in the faction, and the target can't out-rank your cap. */
export function canManageSub(f: Faction, p: ActorPowers, targetCurrentRank: number): boolean {
  const mg = maxGrant(f, p);
  return mg >= 0 && effRank(f, targetCurrentRank) <= mg;
}

export function canSeeLogs(p: ActorPowers): boolean {
  return isAdminPlus(p);
}

/** Factions this actor can manage at all (for tab/menu visibility). */
export function manageableFactions(p: ActorPowers): Faction[] {
  return Object.values(FACTIONS).filter((f) => maxGrant(f, p) >= 0);
}

export function hasAnyStaffAccess(p: ActorPowers): boolean {
  return isAdminPlus(p) || manageableFactions(p).length > 0;
}

export function actionFor(oldRank: number, newRank: number): string {
  if (newRank === 0) return "remove";
  if (oldRank === 0) return "whitelist";
  return newRank > oldRank ? "promote" : "demote";
}
