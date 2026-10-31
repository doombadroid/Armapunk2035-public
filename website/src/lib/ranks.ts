// Rank / stat semantics — pinned from the live game SQF (fn_getRankString.sqf,
// fn_requestReceived.sqf, fn_titleCfg.sqf). Keep in sync if the game changes them.

// players_global.coplevel 1..7
export const COP_RANKS: Record<number, string> = {
  1: "MaxSec Cadet",
  2: "MaxSec Patrol Officer",
  3: "MaxSec Corporal",
  4: "MaxSec Sergeant",
  5: "MaxSec Lieutenant",
  6: "MaxSec Captain",
  7: "MaxSec Chief of Police",
};

// players_global.mediclevel — Trauma Team (rebranded from AFD/Medic). 1..7,
// plus 99 = the EMT Volunteer tier (a sentinel, not a ladder step).
export const MEDIC_RANKS: Record<number, string> = {
  99: "TT EMT Volunteer",
  1: "TT Private",
  2: "TT Corporal",
  3: "TT Sergeant",
  4: "TT Warrant Officer",
  5: "TT Lieutenant",
  6: "TT Commander",
  7: "TT Marshal",
};

// gang rank is INVERTED: 1 = leader .. 5 = recruit
export const GANG_RANKS: Record<number, string> = {
  1: "Leader",
  2: "Officer",
  3: "Member",
  4: "Associate",
  5: "Recruit",
};

// players_global.adminlevel — server staff ranks (pinned from fn_welcomeUI.sqf;
// level 1 is untagged in-game, labelled "Trial Mod" here).
export const ADMIN_LEVELS: Record<number, string> = {
  1: "Trial Mod",
  2: "Moderator",
  3: "Admin",
  4: "Senior Admin",
  5: "Owner",
};

export function copRank(level: number): string | null {
  return level > 0 ? COP_RANKS[level] ?? `MaxSec L${level}` : null;
}
export function medicRank(level: number): string | null {
  return level > 0 ? MEDIC_RANKS[level] ?? `TT L${level}` : null;
}
export function gangRank(rank: number): string {
  return GANG_RANKS[rank] ?? `R${rank}`;
}

// --- players_global.stats  (A_stats, 17 ints) index map (fn_requestReceived.sqf) ---
export const STAT = {
  CIV_TIME: 11, // civ playtime, minutes
  COP_TIME: 14, // cop playtime, minutes
  MED_TIME: 15, // medic playtime, minutes
} as const;
