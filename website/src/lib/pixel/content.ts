// Armapunk Pixel v3 content: the reference game's SSR `statics` prop, verbatim (reference/statics.json
// is the single source; a test asserts CONTENT_TABLES deep-equals it). Everything below the tables is
// a derived map, a bundle-visible detail the statics do not carry, or INFERRED (server-side in the
// reference, fitted here).
import statics from "./reference/statics.json";
import type {
  BackpackDef, ChestDef, ChestRarity, CityDef, CityId, CopGearDef, CrewDef, GangDef, GearDef, ItemDef, LicenseDef, PrestigeDef,
  SiteDef, SkillDef, StarPerkDef, Statics, TalentDef, ToolDef,
} from "./types";

export const CONTENT_TABLES: Statics = statics as unknown as Statics;

export const CITIES: CityDef[] = CONTENT_TABLES.cities;
export const CITY: Record<CityId, CityDef> = Object.fromEntries(CITIES.map((c) => [c.id, c])) as Record<CityId, CityDef>;
export const SITES: SiteDef[] = CONTENT_TABLES.sites;
export const SITE: Record<string, SiteDef> = Object.fromEntries(SITES.map((s) => [s.id, s]));
export const ITEMS: ItemDef[] = CONTENT_TABLES.items;
export const ITEM: Record<string, ItemDef> = Object.fromEntries(ITEMS.map((i) => [i.id, i]));
export const SKILLS: SkillDef[] = CONTENT_TABLES.skills;
export const SKILL: Record<string, SkillDef> = Object.fromEntries(SKILLS.map((s) => [s.id, s]));
export const LICENSES: LicenseDef[] = CONTENT_TABLES.licenses;
export const LICENSE: Record<string, LicenseDef> = Object.fromEntries(LICENSES.map((l) => [l.id, l]));
export const GEAR: GearDef[] = CONTENT_TABLES.gear;
export const BACKPACKS: BackpackDef[] = CONTENT_TABLES.backpacks;
export const COP_GEAR: CopGearDef[] = CONTENT_TABLES.copGear;
export const TOOLS: ToolDef[] = CONTENT_TABLES.tools;
export const TALENTS: TalentDef[] = CONTENT_TABLES.talents;
export const TALENT: Record<string, TalentDef> = Object.fromEntries(TALENTS.map((t) => [t.id, t]));
export const CREWS: CrewDef[] = CONTENT_TABLES.crews;
export const CREW: Record<string, CrewDef> = Object.fromEntries(CREWS.map((c) => [c.siteId, c]));
export const PROCESS_RATES: Record<string, number> = CONTENT_TABLES.processRates;
export const XP_CURVE: number[] = CONTENT_TABLES.xpCurve;
export const CHESTS: ChestDef[] = CONTENT_TABLES.chests;
export const CHEST: Record<ChestRarity, ChestDef> = Object.fromEntries(CHESTS.map((c) => [c.rarity, c])) as Record<ChestRarity, ChestDef>;
export const PRESTIGE: PrestigeDef = CONTENT_TABLES.prestige;
export const GANG: GangDef = CONTENT_TABLES.gang;
export const STAR_PERKS: StarPerkDef[] = CONTENT_TABLES.starPerks;
export const STAR_PERK: Record<string, StarPerkDef> = Object.fromEntries(STAR_PERKS.map((p) => [p.id, p]));
export const TRAVEL: Record<CityId, Record<CityId, number>> = CONTENT_TABLES.travel;
export const CONTRACTS = {
  worker: CONTENT_TABLES.workerContracts,
  process: CONTENT_TABLES.processContracts,
  processContractPaperCost: CONTENT_TABLES.processContractPaperCost,
  workerRateMult: CONTENT_TABLES.workerRateMult,
  workerMaxActive: CONTENT_TABLES.workerMaxActive,
  paperDropChance: CONTENT_TABLES.paperDropChance,
} as const;
export const CONST = {
  talentPointsPerLevel: CONTENT_TABLES.talentPointsPerLevel,
  maxLevel: CONTENT_TABLES.maxLevel,
  autoSellUnlockLevel: CONTENT_TABLES.autoSellUnlockLevel,
  careerSwitchCooldownMin: CONTENT_TABLES.careerSwitchCooldownMin,
  wantedAt: CONTENT_TABLES.wantedAt,
  maxArrestBounty: CONTENT_TABLES.maxArrestBounty,
  maxCrewsPerSite: CONTENT_TABLES.maxCrewsPerSite,
  chatMaxLen: CONTENT_TABLES.chatMaxLen,
  /** bundle: each further crew at a site costs x1.65 */
  crewCostGrowth: 1.65,
} as const;

/** The chest table as the client bundle carries it (statics only ship rarity/name/weight/cash): xp and the paper range. */
export const CHEST_DETAILS: Record<ChestRarity, { xp: number; papers: [number, number] }> = {
  common: { xp: 30, papers: [0, 1] },
  rare: { xp: 120, papers: [1, 2] },
  epic: { xp: 400, papers: [3, 5] },
  legendary: { xp: 1500, papers: [8, 12] },
};

/** The checkpoint icon pool the client maps to lucide icons (`tu` in the reference). */
export const CHECKPOINT_ICONS = ["anchor", "apple", "bell", "car", "crown", "fish", "key", "pickaxe", "shield", "star", "truck", "zap"] as const;

/** Route-choice labels of every pursuit / dispatch checkpoint in the capture. */
export const ROUTE_LABELS = ["Left street", "Center street", "Right street"] as const;
export const ROUTE_PROMPT = (n: number) => `Checkpoint ${n}: choose the lowest total route cost.`;
export const ROUTE_OBSTACLE_COST = 5;

/**
 * Server-side numbers the reference never shows. Each entry names what it was fitted to (a snapshot
 * figure, a guide sentence) or is marked plausible. Tune here; every consumer reads this table.
 */
export const INFERRED = {
  // stamina: "300 = 100 + 15*12 + 10*2" verified; regen 6.78 at endurance 12 / Second Wind 5 fits 1.6
  staminaBase: 100,
  regenBase: 1.6,
  // xp: "about twenty clicks gets you to level 2" (apple: 3 stamina -> 6 xp, 20 clicks = 120 = xpCurve[1]);
  // sale / purchase / crew rates plausible; "crews earn XP at a third of the rate your own hands do"
  clickXpPerStamina: 2,
  saleXpPerDollar: 1 / 200,
  purchaseXpPerDollar: 1 / 1000,
  crewXpFraction: 1 / 3,
  caseXp: 30,
  // heat: plausible; "cools on its own over time, and Stealth cools it faster"
  heatGather: 2,
  heatProcess: 3,
  heatSalePerUnits: 10,
  heatCoolPerMin: 2,
  heatCoolStealthPct: 0.05,
  heatMax: 100,
  crewHeatPerMin: 0.5,
  // fine: snapshot fine 17,385 at level 100 (2,385 + 150 * 100); fineCeiling equalled fine in the snapshot
  fineBase: 2_385,
  finePerLevel: 150,
  // bust estimate bounty: snapshot 4 / 217 with 78 illegal units carried (0.05 and 2.78 per unit)
  bountyPerUnitMin: 0.05,
  bountyPerUnitMax: 2.78,
  // bribe: snapshot 115,328 at heat 0 with 327,600 seizable (35.204 %); the heat term is plausible
  bribeHeatCost: 1_000,
  bribeSeizedPct: 0.35204,
  // market: resting 1.18 and post-dump 0.98 observed; drop/recovery plausible (2,180 units -> x0.846)
  marketRest: 1.18,
  marketFloor: 0.4,
  marketRecoverPerMin: 0.004,
  marketDropMin: 0.8,
  marketDropLog: 0.02,
  // chests: chance per click plausible; "pays with your level" as (1 + level / 20)
  chestChancePerClick: 0.02,
  chestLevelScale: 1 / 20,
  // respec: snapshot 121,000 with 52 points spent (17,000 + 2,000 * 52); "gets pricier each time" +50 % per respec
  respecBase: 17_000,
  respecPerPoint: 2_000,
  respecRepeatPct: 0.5,
  travelMinMs: 1_000,
  // APD: salary "every minute, online or not"; patrol cost and case numbers plausible
  copSalaryBase: 100,
  copSalaryPerLevel: 5,
  patrolStamina: 8,
  caseRewardBase: 400,
  caseRewardPerLevel: 20,
  caseDispatchPct: 0.04,
  caseTargetScore: 180,
  caseReadyDelayMs: 3_000,
  caseWindowMs: 45_000,
  caseCooldownMs: 60_000,
  npcCrimeRegenPerMin: 1,
  npcCrimeCostPerCase: 20,
  npcCrimeMax: 100,
  manpowerMin: 0.5,
  manpowerMax: 1.5,
  // checkpoint (anti-automation): frequency and miss limit not in the bundle; lockout shown as mm:ss
  checkpointEveryClicks: 150,
  checkpointMaxMisses: 3,
  checkpointLockMs: 60_000,
  honeypotLockMs: 600_000,
  // jail: sentence length not in the bundle; bail "starts above the fine and gets cheaper the longer served"
  jailBaseSeconds: 120,
  jailPerHeatSeconds: 3,
  bailStartMult: 1.5,
  prisonJobCreditSeconds: 45,
  prisonWorkCap: 0.5,
  // pursuit windows plausible; pursuitFleeCost 9 is the snapshot value (meaning not in the bundle)
  duelReadyMs: 30_000,
  duelStartDelayMs: 3_000,
  duelWindowMs: 45_000,
  pursuitFleeCost: 9,
  arrestChanceBase: 0.5,
  // feed: only big sales and rare chests appear in the capture's feed
  feedSaleMin: 100_000,
  feedLimit: 40,
  chatWindow: 40,
  chatRetain: 200,
  // slots paytable beyond "7s pay 25x": BAR 10x, BELL 6x, CHERRY 4x, two cherries 1x (RTP about 88 %)
  slotsBar: 10,
  slotsBell: 6,
  slotsCherry: 4,
  slotsTwoCherries: 1,
  slotsReel: ["CHERRY", "CHERRY", "CHERRY", "CHERRY", "CHERRY", "BAR", "BAR", "BAR", "BAR", "BELL", "BELL", "BELL", "7"] as readonly string[],
  gangInviteCodeLen: 6,
} as const;
