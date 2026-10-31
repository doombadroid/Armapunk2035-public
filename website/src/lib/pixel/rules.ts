// Armapunk Pixel v3: the per-rank effects the reference's blurbs state in words. content.ts carries
// costs, names and blurbs verbatim; the multipliers those blurbs describe live here so that every
// formula reads its number from one table. Star perk values come from statics.starPerks.

/** skill effects per rank (the skill blurbs) */
export const SKILL_PCT = {
  staminaPerEndurance: 15,
  regenPerEndurance: 0.22,
  strengthCapacity: 0.08,
  harvestingYield: 0.12,
  refiningYield: 0.12,
  stealthHeat: 0.07,
  hagglingPrice: 0.03,
  pursuitArrest: 0.06,
  authorityBounty: 0.1,
  forensicsSeized: 0.07,
  interrogationFine: 0.1,
} as const;

/** talent effects per rank (the talent blurbs) */
export const TALENT_PCT = {
  quickLearnerXp: 0.08,
  secondWindRegen: 0.12,
  muleCapacity: 0.1,
  bumperCropChance: 0.08,
  lowProfileHeat: 3,
  efficiencyChance: 0.07,
  prospectorJackpot: 0.3,
  logisticsCrew: 0.15,
  fencePrice: 0.06,
  ghostHeat: 0.09,
  rapidResponsePayout: 0.12,
  warrantBounty: 0.1,
  forensicKitSeized: 0.08,
  hardlinerArrest: 0.05,
} as const;

/** "K9 Unit: +8% chance an arrest sticks" */
export const K9_ARREST = 0.08;
/** Guide: "Officers may work legal sites at half rate" */
export const COP_WORK_RATE = 0.5;
/** Guide: "Arrest button needs >= 14 stamina" (Patrol tab) */
export const ARREST_STAMINA_MIN = 14;
/** Patrol tab: a paid call needs the city's reported criminal activity at 2 or more */
export const PAID_CALL_NPC_CRIME_MIN = 2;
/** the action rate limit */
export const ACTION_GAP_MS = 200;
/** roster "online" = seen within two minutes */
export const ONLINE_MS = 2 * 60_000;

/** Casino tab copy: "Dealer stands on 17", "7s pay 25x", "Straight / green pay 36x", red/black/even/odd 2x. */
export const CASINO = {
  blackjackStandsOn: 17,
  blackjackWin: 2,
  blackjackNatural: 2.5,
  slotsSevens: 25,
  rouletteEven: 2,
  rouletteStraight: 36,
  pokerMinPlayers: 2,
  pokerMaxPlayers: 4,
} as const;

/** Prison workshop copy: "the first 60 seconds of any sentence must be served", "Takes at least 20 seconds either way". */
export const PRISON = { mustServeFirstSeconds: 60, jobSeconds: 20 } as const;
