// Armapunk Pixel v3 economy helpers: prices and market drift, carry capacity, stamina, heat, every
// cost formula, per-click and per-minute rates. Pure functions over content constants and a
// PlayerState / CareerState; only `give` and `take` write, and only to the engine's private copy.
import { BACKPACKS, CITY, CONST, CONTRACTS, COP_GEAR, CREW, GANG, GEAR, INFERRED, ITEM, LICENSES, PRESTIGE, PROCESS_RATES, SITE, STAR_PERK, TOOLS, TRAVEL } from "./content";
import { levelOf, talentSpent } from "./level";
import { COP_WORK_RATE, SKILL_PCT, TALENT_PCT } from "./rules";
import type { CareerState, CityId, Faction, ItemId, Market, MarketRow, PlayerState, SiteDef, ToolDef, ToolKind } from "./types";

/** Floor that forgives binary float noise: floor(2.9999999999) is 3, not 2. */
export function floorSafe(v: number): number {
  return Math.floor(v + 1e-9);
}

/** A probability from rank * pct, rounded to 1e-6 so a scripted-roll threshold is exact (5 * 0.07 is not 0.35 in binary). */
export function chance(x: number): number {
  return Math.round(x * 1e6) / 1e6;
}

export function round2(n: number): number {
  return Math.round(n * 100) / 100;
}

/** The career the player is currently playing (civ before the picker: the picker only has civ defaults to show). */
export function career(s: PlayerState): CareerState {
  return s.careers[s.faction ?? "civ"];
}

export function factionOf(s: PlayerState): Faction {
  return s.faction ?? "civ";
}

// ---- market

export function marketKey(city: CityId, item: ItemId): string {
  return `${city}:${item}`;
}

/** Multiplier a (city, item) row has drifted to by `now`: untouched rows rest at marketRest; sold rows recover toward it per minute. */
export function marketMultAt(row: MarketRow | undefined, now: number): number {
  if (!row) return INFERRED.marketRest;
  const minutes = Math.max(0, now - row.at) / 60_000;
  return Math.min(INFERRED.marketRest, row.mult + INFERRED.marketRecoverPerMin * minutes);
}

/** The multiplier a row drops to after `units` sell: max(floor, mult * max(dropMin, 1 - dropLog * ln(1 + units))). */
export function marketAfterSale(mult: number, units: number): number {
  const drop = Math.max(INFERRED.marketDropMin, 1 - INFERRED.marketDropLog * Math.log(1 + units));
  return Math.max(INFERRED.marketFloor, mult * drop);
}

/**
 * Verified on the snapshot: round(sell * mult * (1 + 0.03 haggling) * (illegal ? 1 + 0.06 fence : 1)
 * * city.demand * (1 + 0.04 starHaggle)); 0 when nobody buys the item raw.
 */
export function unitPrice(item: ItemId, city: CityId, market: Market, c: CareerState, now: number): number {
  const def = ITEM[item];
  if (!def || def.sell <= 0) return 0;
  const mult = marketMultAt(market[marketKey(city, item)], now);
  const haggle = 1 + SKILL_PCT.hagglingPrice * (c.skills.haggling ?? 0);
  const fence = def.legal ? 1 : 1 + TALENT_PCT.fencePrice * (c.talents.fence ?? 0);
  const star = 1 + STAR_PERK.starHaggle.value * (c.perks.starHaggle ?? 0);
  return Math.round(def.sell * mult * haggle * fence * CITY[city].demand * star);
}

/** Verified: cash plus the bag at base prices. */
export function netWorth(c: CareerState): number {
  let worth = c.cash;
  for (const [item, n] of Object.entries(c.inventory)) worth += n * (ITEM[item]?.sell ?? 0);
  return worth;
}

/** Verified: what a bust would seize, illegal units at base price. */
export function seizable(c: CareerState): number {
  let sum = 0;
  for (const [item, n] of Object.entries(c.inventory)) {
    const def = ITEM[item];
    if (def && !def.legal) sum += n * def.sell;
  }
  return sum;
}

/** Illegal units a bust would actually value: those with a base price (the snapshot counts 78 uraniump, not the 1,255 unsellable ore). */
export function seizableUnits(c: CareerState): number {
  let sum = 0;
  for (const [item, n] of Object.entries(c.inventory)) if (ITEM[item] && !ITEM[item].legal && ITEM[item].sell > 0) sum += n;
  return sum;
}

export function illegalUnits(c: CareerState): number {
  let sum = 0;
  for (const [item, n] of Object.entries(c.inventory)) if (ITEM[item] && !ITEM[item].legal) sum += n;
  return sum;
}

// ---- bag

/** Verified: round((vehicle + backpack) * (1 + 0.08 strength) * (1 + 0.10 mule)); officers carry the starter gear only. */
export function capacityKg(s: PlayerState): number {
  const c = career(s);
  const cop = factionOf(s) === "cop";
  const base = (cop ? GEAR[0] : GEAR[c.gearTier]).capacity + (cop ? BACKPACKS[0] : BACKPACKS[c.packTier]).capacity;
  const strength = 1 + SKILL_PCT.strengthCapacity * (c.skills.strength ?? 0);
  const mule = 1 + TALENT_PCT.muleCapacity * (c.talents.mule ?? 0);
  return Math.round(base * strength * mule);
}

export function carriedKg(c: CareerState): number {
  let kg = 0;
  for (const [item, n] of Object.entries(c.inventory)) kg += n * (ITEM[item]?.weight ?? 0);
  return kg;
}

/** Whole units of `item` that still fit: a unit fits when carried + weight <= capacity. */
export function roomFor(s: PlayerState, item: ItemId): number {
  const w = ITEM[item]?.weight ?? 0;
  if (w <= 0) return Number.MAX_SAFE_INTEGER;
  return Math.max(0, floorSafe((capacityKg(s) - carriedKg(career(s))) / w));
}

export function give(c: CareerState, item: ItemId, n: number): void {
  if (n <= 0) return;
  c.inventory[item] = (c.inventory[item] ?? 0) + n;
}

/** Remove `n` of an item, dropping the key at zero so the bag never lists empty rows. */
export function take(c: CareerState, item: ItemId, n: number): void {
  const left = (c.inventory[item] ?? 0) - n;
  if (left > 0) c.inventory[item] = left;
  else delete c.inventory[item];
}

// ---- stamina

export function staminaMax(c: CareerState): number {
  return INFERRED.staminaBase + SKILL_PCT.staminaPerEndurance * (c.skills.endurance ?? 0) + STAR_PERK.starStamina.value * (c.perks.starStamina ?? 0);
}

/** Stamina regenerated per second. */
export function staminaRegen(c: CareerState): number {
  const base = INFERRED.regenBase + SKILL_PCT.regenPerEndurance * (c.skills.endurance ?? 0);
  return base * (1 + TALENT_PCT.secondWindRegen * (c.talents.secondWind ?? 0));
}

// ---- heat

/** Every heat gain is scaled by (1 - 0.07 stealth)(1 - 0.09 ghost)(1 - 0.08 starGhost). */
export function heatMult(c: CareerState): number {
  const stealth = 1 - SKILL_PCT.stealthHeat * (c.skills.stealth ?? 0);
  const ghost = 1 - TALENT_PCT.ghostHeat * (c.talents.ghost ?? 0);
  const star = 1 - STAR_PERK.starGhost.value * (c.perks.starGhost ?? 0);
  return Math.max(0, stealth * ghost * star);
}

/** Heat lost per minute of cooling. */
export function heatCoolPerMin(c: CareerState): number {
  return INFERRED.heatCoolPerMin * (1 + INFERRED.heatCoolStealthPct * (c.skills.stealth ?? 0));
}

/** wantedAt + 3 per Low Profile rank. */
export function visibleAt(c: CareerState): number {
  return CONST.wantedAt + TALENT_PCT.lowProfileHeat * (c.talents.lowProfile ?? 0);
}

/** bribeHeatCost * heat + bribeSeizedPct * seizable, rounded (snapshot: 115,328 at heat 0 with 327,600 seizable). */
export function bribeCost(s: PlayerState): number {
  return Math.round(INFERRED.bribeHeatCost * s.heat + INFERRED.bribeSeizedPct * seizable(s.careers.civ));
}

/** The fine an arrest charges at the civilian level (snapshot: 17,385 at level 100). */
export function fineEstimate(c: CareerState): number {
  return Math.round(INFERRED.fineBase + INFERRED.finePerLevel * levelOf(c));
}

// ---- purchases

/** Cost of the next rank of a skill (costs[rank]); null once maxed. */
export function skillCost(costs: number[], max: number, rank: number): number | null {
  if (rank >= max || rank >= costs.length) return null;
  return costs[rank];
}

/** (respecBase + respecPerPoint * talentSpent) * (1 + respecRepeatPct * respecs), rounded (snapshot: 121,000 at 52 points). */
export function respecCost(c: CareerState): number {
  return Math.round((INFERRED.respecBase + INFERRED.respecPerPoint * talentSpent(c)) * (1 + INFERRED.respecRepeatPct * c.respecs));
}

/** The tool of `kind` at `tier` (TOOLS lists both kinds in one table). */
export function toolOf(kind: ToolKind, tier: number): ToolDef | undefined {
  return TOOLS.find((t) => t.kind === kind && t.tier === tier);
}

// ---- prestige

export function prestigeFee(c: CareerState): number {
  return PRESTIGE.cashBase + PRESTIGE.cashStep * c.prestige;
}

/**
 * Every reason the career cannot prestige yet: level, its licences, its equipment (civ: both tools,
 * vehicle, backpack; cop: the equipment ladder), the fee, and the star cap. Empty when ready.
 */
export function prestigeBlockers(c: CareerState, faction: Faction): string[] {
  const out: string[] = [];
  if (c.prestige >= PRESTIGE.max) out.push("Already at the top star");
  if (levelOf(c) < CONST.maxLevel) out.push(`Needs level ${CONST.maxLevel}`);
  for (const l of LICENSES) if ((l.faction ?? "civ") === faction && !c.licenses.includes(l.id)) out.push(`Needs the ${l.name}`);
  if (faction === "civ") {
    for (const kind of ["gather", "process"] as const) {
      const top = TOOLS.filter((t) => t.kind === kind).reduce((a, b) => (b.tier > a.tier ? b : a));
      if (c.tools[kind] < top.tier) out.push(`Needs the ${top.name}`);
    }
    const topGear = GEAR[GEAR.length - 1];
    if (c.gearTier < topGear.tier) out.push(`Needs the ${topGear.name}`);
    const topPack = BACKPACKS[BACKPACKS.length - 1];
    if (c.packTier < topPack.tier) out.push(`Needs the ${topPack.name}`);
  } else {
    const top = COP_GEAR[COP_GEAR.length - 1];
    if (c.copGearTier < top.tier) out.push(`Needs the ${top.name}`);
  }
  const fee = prestigeFee(c);
  if (c.cash < fee) out.push(`Needs ${money(fee)} in cash`);
  return out;
}

// ---- work rates

/** Gang yield bonus for a gang level. */
export function gangYieldBonus(gangLevel: number): number {
  return GANG.yieldPerLevel * gangLevel;
}

/**
 * Units per click before Bumper Crop: civilians max(1, floor(yield * tool.mult * (1 + 0.12 skill)
 * * (1 + gang yield) * (1 + 0.06 starYield))); officers work legal sites at half rate with the
 * starter tool and no harvesting / refining skill.
 */
export function perClick(s: PlayerState, site: SiteDef, gangLevel = 0): number {
  const c = career(s);
  const gang = 1 + gangYieldBonus(gangLevel);
  const star = 1 + STAR_PERK.starYield.value * (c.perks.starYield ?? 0);
  if (factionOf(s) === "cop") return Math.max(1, floorSafe(site.yield * COP_WORK_RATE * gang * star));
  const tool = toolOf(site.mode, c.tools[site.mode])?.mult ?? 1;
  const skillRank = site.mode === "gather" ? c.skills.harvesting ?? 0 : c.skills.refining ?? 0;
  const skillPct = site.mode === "gather" ? SKILL_PCT.harvestingYield : SKILL_PCT.refiningYield;
  return Math.max(1, floorSafe(site.yield * tool * (1 + skillPct * skillRank) * gang * star));
}

/** Bundle: CREW cost * 1.65^ownedAtSite, rounded. */
export function crewCost(siteId: string, ownedAtSite: number): number {
  const def = CREW[siteId];
  if (!def) return 0;
  return Math.round(def.cost * CONST.crewCostGrowth ** ownedAtSite);
}

/** One crew's units per minute: perMinute * (1 + 0.15 logistics). */
export function crewRate(c: CareerState, siteId: string): number {
  const def = CREW[siteId];
  if (!def) return 0;
  return def.perMinute * (1 + TALENT_PCT.logisticsCrew * (c.talents.logistics ?? 0));
}

/**
 * Contractor units per minute: CREW perMinute * workerRateMult at gather sites, processRates *
 * workerRateMult at processors; null when the output has no price or the site has no entry.
 */
export function contractRate(siteId: string): number | null {
  const site = SITE[siteId];
  if (!site) return null;
  if ((ITEM[site.output]?.sell ?? 0) <= 0) return null;
  const base = site.mode === "gather" ? CREW[siteId]?.perMinute : PROCESS_RATES[siteId];
  if (base === undefined) return null;
  return base * CONTRACTS.workerRateMult;
}

// ---- travel

/** travel[from][to] * vehicle speed * 1000 ms (officers ride the starter tier), never under travelMinMs; 0 for the current city. */
export function travelMs(s: PlayerState, to: CityId): number {
  if (to === s.cityId) return 0;
  const secs = TRAVEL[s.cityId]?.[to];
  if (secs === undefined) return 0;
  const tier = factionOf(s) === "cop" ? 0 : career(s).gearTier;
  return Math.max(INFERRED.travelMinMs, Math.round(secs * GEAR[tier].speed * 1000));
}

/** "$1,234,567" for feed text. */
export function money(n: number): string {
  return "$" + Math.round(n).toLocaleString("en-US");
}
