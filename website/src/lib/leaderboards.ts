// Categorized leaderboard catalog. Every metric maps to a real Armapunk data
// source: a direct players/players_global column, a players_global.lifetime_stats
// array index (the ~148-elem cumulative stat array — index map pinned from the
// game's fn_statArrUpdate.sqf), computed net-worth, or the live `wanted` table.
//
// NOTE the metric `key` is the ?metric= URL value and is used to pick a SQL
// column/index from THIS whitelist only — never interpolate user input into SQL.
import { money, commas, nd } from "./format";

export type LbFormat = "money" | "nd" | "int" | "xp" | "meters" | "minutes";

export type LbSource =
  | { kind: "col"; col: string } //  SQL expr, whitelisted here (e.g. "p.bankacc")
  | { kind: "ltstat"; index: number } // players_global.lifetime_stats[index]
  | { kind: "wealth" } //  p.cash + p.bankacc
  | { kind: "wanted" }; //  live `wanted` table, bounty col

export interface LbMetric {
  key: string;
  label: string;
  format: LbFormat;
  source: LbSource;
  excludeStaff?: boolean; // drop adminlevel>=1 (money boards — staff can spawn cash)
}

export interface LbCategory {
  key: string;
  label: string;
  icon: string; // lucide icon name, resolved in the page
  metrics: LbMetric[];
}

const col = (col: string): LbSource => ({ kind: "col", col });
const lt = (index: number): LbSource => ({ kind: "ltstat", index });

export const LB_CATEGORIES: LbCategory[] = [
  {
    key: "economy", label: "Economy", icon: "DollarSign",
    metrics: [
      { key: "bankacc", label: "Bank Account", format: "money", source: col("p.bankacc"), excludeStaff: true },
      { key: "wealth", label: "Net Worth", format: "money", source: { kind: "wealth" }, excludeStaff: true },
      { key: "new_drachma", label: "New Drachma", format: "nd", source: col("p.new_drachma"), excludeStaff: true },
      { key: "casinogain", label: "Casino Winnings", format: "money", source: lt(49) },
      { key: "moneypickedup", label: "Money Picked Up", format: "money", source: lt(52) },
    ],
  },
  {
    key: "progression", label: "Progression", icon: "TrendingUp",
    metrics: [
      { key: "civ", label: "Civilian XP", format: "xp", source: col("p.civ_exp") },
      { key: "cop", label: "Police XP", format: "xp", source: col("p.cop_exp") },
      { key: "med", label: "Trauma Team XP", format: "xp", source: col("p.med_exp") },
      { key: "infamy", label: "Infamy", format: "int", source: col("p.infamy_exp") },
      { key: "honor", label: "Honor", format: "int", source: col("g.honor_exp") },
      { key: "prestige", label: "Prestige", format: "int", source: col("CAST(NULLIF(p.prestige,'') AS SIGNED)") },
    ],
  },
  {
    key: "criminal", label: "Criminal", icon: "Skull",
    metrics: [
      { key: "wanted", label: "Most Wanted", format: "money", source: { kind: "wanted" } },
      { key: "blacklace", label: "Black Lace Processed", format: "int", source: lt(26) },
      { key: "smashbrick_proc", label: "Smash Bricks Made", format: "int", source: lt(72) },
      { key: "moonshine_proc", label: "Moonshine Made", format: "int", source: lt(99) },
      { key: "picksuccess", label: "Successful Lockpicks", format: "int", source: lt(2) },
      { key: "goldsold", label: "Gold Bars Sold", format: "int", source: lt(8) },
      { key: "treasure", label: "Treasures Recovered", format: "int", source: lt(28) },
    ],
  },
  {
    key: "combat", label: "Combat", icon: "Swords",
    metrics: [
      { key: "copkills", label: "Cops Killed", format: "int", source: lt(0) },
      { key: "civ_cops_downed", label: "Cops Downed", format: "int", source: lt(75) },
      { key: "warkill_headshots", label: "War Headshots", format: "int", source: lt(80) },
      { key: "rpg_vehhits", label: "RPG Vehicle Hits", format: "int", source: lt(74) },
      { key: "turfscaptured", label: "Turfs Captured", format: "int", source: lt(83) },
      { key: "cartelscaptured", label: "Cartels Captured", format: "int", source: lt(84) },
      { key: "ziptied", label: "Players Zip-Tied", format: "int", source: lt(43) },
    ],
  },
  {
    key: "police", label: "Police", icon: "Shield",
    metrics: [
      { key: "fugitivearrested", label: "Fugitives Arrested", format: "int", source: lt(57) },
      { key: "ticketsgiven", label: "Tickets Issued", format: "int", source: lt(60) },
      { key: "ticketsgivenamount", label: "Ticket Revenue", format: "money", source: lt(61) },
      { key: "moneyearnedcop", label: "Police Earnings", format: "money", source: lt(97) },
      { key: "evidencesdone", label: "Evidence Processed", format: "int", source: lt(46) },
    ],
  },
  {
    key: "traumateam", label: "Trauma Team", icon: "Stethoscope",
    metrics: [
      { key: "defibs", label: "Defibrillations", format: "int", source: lt(1) },
      { key: "adrenaline", label: "Adrenaline Given", format: "int", source: lt(9) },
      { key: "bloodbag", label: "Blood Bags Used", format: "int", source: lt(13) },
      { key: "moneyearnedmedic", label: "Trauma Team Earnings", format: "money", source: lt(98) },
      { key: "housefirecompleted", label: "House Fires Fought", format: "int", source: lt(131) },
    ],
  },
  {
    key: "heists", label: "Heists & Events", icon: "Gem",
    metrics: [
      { key: "banksdone", label: "Banks Robbed", format: "int", source: lt(121) },
      { key: "fedsafeopened", label: "Fed Reserve Safes", format: "int", source: lt(93) },
      { key: "prisonsdone", label: "Prison Breaks", format: "int", source: lt(118) },
      { key: "convoysdone", label: "Convoys Done", format: "int", source: lt(119) },
      { key: "loonybinbreached", label: "Loony Bin Breached", format: "int", source: lt(123) },
      { key: "jewelryscompleted", label: "Jewelry Store Heists", format: "int", source: lt(138) },
      { key: "gangfortresscapped", label: "Gang Fortress Caps", format: "int", source: lt(136) },
      { key: "graveyardwon", label: "Graveyard Wins", format: "int", source: lt(105) },
      { key: "battleroyalewon", label: "Battle Royale Wins", format: "int", source: lt(106) },
      { key: "gungamewon", label: "Gun Game Wins", format: "int", source: lt(107) },
      { key: "normquests_completed", label: "Quests Completed", format: "int", source: lt(66) },
    ],
  },
  {
    key: "fun", label: "Fun & Misc", icon: "Dice5",
    metrics: [
      { key: "fishcaught", label: "Fish Caught", format: "int", source: lt(39) },
      { key: "distancedrove", label: "Distance Driven", format: "meters", source: lt(104) },
      { key: "distancewalked", label: "Distance Walked", format: "meters", source: lt(103) },
      { key: "vehiclesbought", label: "Vehicles Bought", format: "int", source: lt(41) },
      { key: "prisontime", label: "Time in Prison", format: "minutes", source: lt(4) },
      { key: "blackjackwon", label: "Blackjack Wins", format: "int", source: lt(114) },
      { key: "slotswon", label: "Slot Machine Wins", format: "int", source: lt(116) },
      { key: "shank", label: "Times Shanked", format: "int", source: lt(34) },
    ],
  },
];

export const LB_METRICS: Map<string, LbMetric> = new Map(
  LB_CATEGORIES.flatMap((c) => c.metrics.map((m) => [m.key, m] as const))
);

export const DEFAULT_METRIC = "bankacc";

export function lbMetric(key: string | undefined): LbMetric {
  return (key && LB_METRICS.get(key)) || LB_METRICS.get(DEFAULT_METRIC)!;
}

/** Format a raw value for display per the metric's unit. */
export function fmtLbValue(m: LbMetric, v: number): string {
  switch (m.format) {
    case "money": return money(v);
    case "nd": return nd(v);
    case "xp": return `${commas(v)} XP`;
    case "meters": return `${commas(v)} m`;
    case "minutes": return `${commas(v)} min`;
    default: return commas(v);
  }
}
