// Armapunk Pixel v3 rules engine. Pure: (state, shared, action, now, rng) in, new objects out. No I/O
// and no clock or random source of its own; every rule is a vitest case. The vocabulary, the
// result shape and the error strings are the reference game's where its client reveals them.
import {
  BACKPACKS, CHEST, CHEST_DETAILS, CHESTS, CITY, CONST, CONTRACTS, COP_GEAR, CREW, GANG, GEAR, INFERRED, ITEM, LICENSE, SITE, SKILL,
  STAR_PERK, TALENT,
} from "./content";
import {
  bribeCost, career, chance, contractRate, crewCost, crewRate, factionOf, fineEstimate, floorSafe, give, heatCoolPerMin,
  heatMult, illegalUnits, marketAfterSale, marketKey, marketMultAt, money, perClick, prestigeBlockers, respecCost, roomFor, round2,
  skillCost, staminaMax, staminaRegen, take, toolOf, travelMs, unitPrice,
} from "./economy";
import { cheats, enforceMaxPrestige } from "./cheats";
import { gangLevelFromXp, levelOf, talentPoints, talentSpent, xpMultiplier } from "./level";
import { blackjackDeal, blackjackHit, blackjackStand, pokerShowdown, spinRoulette, spinSlots } from "./casino";
import { cuidFrom, inviteCodeFrom, newCheckpoint, newPrisonJob, pipesSolved, rotateTile, routeRounds, routeScore, routeTotal, rngInt, type Rng, uuidFrom } from "./minigames";
import { ACTION_GAP_MS, ARREST_STAMINA_MIN, CASINO, PAID_CALL_NPC_CRIME_MIN, PRISON, TALENT_PCT } from "./rules";
import type {
  Action, ActionOk, ActionResult, ApplyOutcome, CareerState, ChestRarity, CityId, Custody, Duel, Faction, FeedEvent, GangRecord, ItemId,
  NpcCrimeRow, PlayerState, PokerTable, RouletteChoice, Shared, SiteDef, ToolKind, Worker,
} from "./types";

export * from "./cheats";
export * from "./economy";
export * from "./level";
export { ACTION_GAP_MS, SKILL_PCT, TALENT_PCT } from "./rules";

// ---- fresh state

export function newCareer(now: number): CareerState {
  return {
    cash: 0,
    xp: 0,
    licenses: [],
    skills: {},
    talents: {},
    respecs: 0,
    tools: { gather: 0, process: 0 },
    gearTier: 0,
    packTier: 0,
    copGearTier: 0,
    inventory: {},
    autoSell: false,
    workerAutoSell: false,
    crews: {},
    pausedCrews: [],
    crewsAt: now,
    workers: [],
    prestige: 0,
    starPicks: 0,
    perks: {},
    salaryAt: now,
  };
}

/** A fresh save: no career yet ("Choose your life on Altis"), Kavala, full stamina, every clock at `now`. */
export function newState(steamId: string, name: string, now: number): PlayerState {
  return {
    v: 3,
    steamId,
    name,
    createdAt: now,
    lastActionAt: 0,
    faction: null,
    careers: { civ: newCareer(now), cop: newCareer(now) },
    cityId: "kavala",
    travelTo: null,
    travelUntil: 0,
    stamina: INFERRED.staminaBase,
    staminaAt: now,
    heat: 0,
    heatAt: now,
    papers: 0,
    processPapers: 0,
    chests: { common: 0, rare: 0, epic: 0, legendary: 0 },
    stats: { clicks: 0, gathered: 0, processed: 0, sold: 0, earned: 0, busts: 0, timesBusted: 0, timesFled: 0, timesResisted: 0, jackpots: 0, chestsFound: 0 },
    careerSwitchReadyAt: 0,
    activityLockUntil: 0,
    custody: null,
    arrestFine: 0,
    checkpoint: null,
    checkpointClicks: 0,
    duel: null,
    apdCase: null,
    apdCaseReadyAt: 0,
    gangId: null,
    blackjack: null,
    freePursuitRespec: true,
  };
}

export function emptyShared(): Shared {
  return { market: {}, npcCrime: {} as Shared["npcCrime"], gangs: {}, poker: newPokerTable() };
}

export function newPokerTable(): PokerTable {
  return { seats: [], pot: 0, buyIn: null, minPlayers: CASINO.pokerMinPlayers, lastResult: null };
}

/** Deep enough copy that no caller-owned object is ever written to. */
export function clone(s: PlayerState): PlayerState {
  return structuredCloneSafe(s);
}
export function cloneShared(sh: Shared): Shared {
  return structuredCloneSafe(sh);
}
function structuredCloneSafe<T>(v: T): T {
  return JSON.parse(JSON.stringify(v)) as T;
}

// ---- context

interface Ctx {
  s: PlayerState;
  sh: Shared;
  now: number;
  rng: Rng;
  events: FeedEvent[];
  res: ActionOk;
  /** set by a handler that wants its changes kept but the client told no (a checkpoint miss) */
  fail?: string;
}

function level(s: PlayerState): number {
  return levelOf(career(s));
}

function gangOf(s: PlayerState, sh: Shared): GangRecord | null {
  return s.gangId ? sh.gangs[s.gangId] ?? null : null;
}

export function gangLevel(s: PlayerState, sh: Shared): number {
  const g = gangOf(s, sh);
  return g ? gangLevelFromXp(g.xp).level : 0;
}

/** Heat gain after the stealth, ghost and star reductions, capped at heatMax, stored to 2 decimals. */
function addHeat(ctx: Ctx, raw: number): number {
  const before = ctx.s.heat;
  ctx.s.heat = round2(Math.min(INFERRED.heatMax, ctx.s.heat + raw * heatMult(ctx.s.careers.civ)));
  return round2(ctx.s.heat - before);
}

/**
 * The one door every XP gain goes through: the multiplier (Quick Learner, Old Soul, gang) applies,
 * the result is rounded, half of it feeds the gang, and every level crossed is a feed event plus a
 * talent point in the result ("LEVEL UP").
 */
function gainXp(ctx: Ctx, c: CareerState, base: number, silent = false): number {
  const n = Math.round(base * xpMultiplier(c, gangLevel(ctx.s, ctx.sh)));
  if (n <= 0) return 0;
  const before = levelOf(c);
  c.xp += n;
  const after = levelOf(c);
  const g = gangOf(ctx.s, ctx.sh);
  if (g) g.xp += Math.round(n * GANG.xpShare);
  for (let l = before + 1; l <= after; l++) ctx.events.push({ kind: "level", text: `reached level ${l}` });
  if (!silent) {
    ctx.res.xp = (ctx.res.xp ?? 0) + n;
    if (after > before) ctx.res.talentPoints = (ctx.res.talentPoints ?? 0) + (after - before) * CONST.talentPointsPerLevel;
  }
  return n;
}

function addCash(ctx: Ctx, c: CareerState, delta: number): void {
  c.cash += delta;
  if (delta !== 0) ctx.res.cash = (ctx.res.cash ?? 0) + delta;
}

function autoSells(s: PlayerState, item: ItemId): boolean {
  const c = career(s);
  return factionOf(s) === "civ" && c.autoSell && level(s) >= CONST.autoSellUnlockLevel && (ITEM[item]?.sell ?? 0) > 0;
}

/**
 * Move `units` of `item` out of the player's hands for cash at the `city` price, drop the city's
 * multiplier, count it, grant sale XP and, for contraband, the sale heat. `fromBag` is false for
 * auto-sold work output, which never entered the bag.
 */
function sellUnits(ctx: Ctx, city: CityId, item: ItemId, units: number, fromBag: boolean): number {
  const c = career(ctx.s);
  const def = ITEM[item];
  const price = unitPrice(item, city, ctx.sh.market, c, ctx.now);
  const revenue = price * units;
  const key = marketKey(city, item);
  ctx.sh.market[key] = { mult: marketAfterSale(marketMultAt(ctx.sh.market[key], ctx.now), units), at: ctx.now };
  if (fromBag) take(c, item, units);
  addCash(ctx, c, revenue);
  ctx.s.stats.sold += units;
  ctx.s.stats.earned += revenue;
  if (revenue >= INFERRED.feedSaleMin) ctx.events.push({ kind: "sale", text: `moved ${units}x ${def.name} for ${money(revenue)}` });
  gainXp(ctx, c, revenue * INFERRED.saleXpPerDollar);
  if (!def.legal) {
    const gained = addHeat(ctx, Math.max(1, units / INFERRED.heatSalePerUnits));
    if (gained > 0) ctx.res.heat = round2((ctx.res.heat ?? 0) + gained);
  }
  return revenue;
}

// ---- tick

/**
 * Crews settle per whole minute since crewsAt (civilian career, only while playing it: "Crews stop
 * while you are an officer"). Each unpaused crew makes floor(rate * n * minutes) units into the
 * bag, clamped to what fits. Crew XP is crewXpFraction of the hand rate per delivered unit; illegal
 * crews add crewHeatPerMin per crew-minute of delivered work, through the reductions.
 */
function settleCrews(ctx: Ctx): void {
  const s = ctx.s;
  const c = s.careers.civ;
  const minutes = Math.floor((ctx.now - c.crewsAt) / 60_000);
  if (minutes < 1) return;
  c.crewsAt += minutes * 60_000;
  if (s.faction !== "civ") return;
  for (const [siteId, n] of Object.entries(c.crews)) {
    const site = SITE[siteId];
    if (!site || n < 1 || c.pausedCrews.includes(siteId)) continue;
    const rate = crewRate(c, siteId);
    const made = Math.floor(rate * n * minutes + 1e-9);
    const fit = Math.min(made, roomFor(s, site.output));
    if (fit <= 0) continue;
    give(c, site.output, fit);
    s.stats.gathered += fit;
    gainXp(ctx, c, INFERRED.crewXpFraction * ((INFERRED.clickXpPerStamina * site.stamina) / site.yield) * fit, true);
    if (!site.legal) addHeat(ctx, INFERRED.crewHeatPerMin * (fit / rate));
  }
}

/**
 * Contractors settle per whole minute since lastTickAt, up to `until`, in the civilian bag whichever
 * career is active (they run on wall clock). Output per settle is floor(perMinute * minutes); a
 * processing contract consumes inputPer per unit and makes only what the inputs allow. With
 * workerAutoSell the output is sold at the site's city at the resting price and `earned` grows.
 */
function settleWorkers(ctx: Ctx): void {
  const s = ctx.s;
  const c = s.careers.civ;
  const kept: Worker[] = [];
  for (const w of c.workers) {
    const site = SITE[w.siteId];
    const end = Math.min(ctx.now, w.until);
    const minutes = Math.floor((end - w.lastTickAt) / 60_000);
    if (site && minutes >= 1) {
      w.lastTickAt += minutes * 60_000;
      let units = Math.floor(w.perMinute * minutes + 1e-9);
      if (site.mode === "process" && site.input) {
        const per = site.inputPer ?? 1;
        units = Math.min(units, Math.floor((c.inventory[site.input] ?? 0) / per));
        if (units > 0) take(c, site.input, units * per);
      }
      if (units > 0) {
        if (c.workerAutoSell && (ITEM[site.output]?.sell ?? 0) > 0) {
          const revenue = unitPrice(site.output, site.cityId, {}, c, ctx.now) * units;
          c.cash += revenue;
          w.earned += revenue;
          s.stats.sold += units;
          s.stats.earned += revenue;
        } else if (s.faction === "civ") {
          give(c, site.output, Math.min(units, roomFor(s, site.output)));
        } else {
          give(c, site.output, units);
        }
      }
    }
    if (w.until > ctx.now) kept.push(w);
  }
  c.workers = kept;
}

/** APD salary: copSalaryBase + copSalaryPerLevel * level per whole minute on duty, online or not. */
function settleSalary(ctx: Ctx): void {
  const s = ctx.s;
  const c = s.careers.cop;
  const minutes = Math.floor((ctx.now - c.salaryAt) / 60_000);
  if (minutes < 1) return;
  c.salaryAt += minutes * 60_000;
  if (s.faction !== "cop") return;
  c.cash += minutes * (INFERRED.copSalaryBase + INFERRED.copSalaryPerLevel * levelOf(c));
}

export function npcCrimeAt(row: NpcCrimeRow | undefined, now: number): number {
  if (!row) return INFERRED.npcCrimeMax;
  const minutes = Math.max(0, now - row.at) / 60_000;
  return Math.min(INFERRED.npcCrimeMax, row.value + INFERRED.npcCrimeRegenPerMin * minutes);
}

function settleDuel(ctx: Ctx): void {
  const s = ctx.s;
  const d = s.duel;
  if (!d || d.status === "resolved") return;
  if (d.status === "pending" && ctx.now >= d.readyUntil) {
    if (d.role === "civ" && !d.myReady) {
      resolveDuel(ctx, d, "capture", "Civilian did not ready up in time and was taken into custody.");
    } else if (d.role === "cop" && !d.myReady) {
      resolveDuel(ctx, d, "cancelled", "You did not ready up in time. No penalty either way.");
    } else if (!d.opponentReady) {
      resolveDuel(ctx, d, d.role === "cop" ? "capture" : "cancelled", d.role === "cop" ? "Civilian did not ready up in time and was taken into custody." : "The officer did not ready up in time. It was called off.");
    }
  } else if (d.status === "active" && ctx.now >= d.until) {
    settleActiveDuel(ctx, d);
  }
}

function settleActiveDuel(ctx: Ctx, d: Duel): void {
  const mine = routeTotal(d.myAnswers);
  const theirs = routeTotal(d.opponentAnswers);
  const copTotal = d.role === "cop" ? mine : theirs;
  const civTotal = d.role === "cop" ? theirs : mine;
  if (copTotal > civTotal) resolveDuel(ctx, d, "capture", "The officer took the better route.");
  else resolveDuel(ctx, d, "escape", "Higher total wins. A tie escapes.");
}

/** Resolve the player's side of a pursuit; a capture on the civilian side is an arrest. */
function resolveDuel(ctx: Ctx, d: Duel, outcome: Duel["outcome"], reason: string): void {
  d.status = "resolved";
  d.outcome = outcome;
  d.reason = reason;
  if (d.role === "civ") {
    if (outcome === "capture") jailPlayer(ctx.s, ctx.now, ctx.rng);
    else if (outcome === "escape") ctx.s.stats.timesFled++;
  } else if (outcome === "capture") {
    ctx.s.stats.busts++;
  }
}

/**
 * Everything the wall clock does to a save, in this order: stamina regen (per second), heat cooling
 * (fractional minutes), travel arrival, custody release, crews, contractors, salary, the open APD
 * case expiring, and pursuit deadlines.
 */
function settle(ctx: Ctx): void {
  const s = ctx.s;
  const c = career(s);
  if (ctx.now > s.staminaAt) {
    const secs = (ctx.now - s.staminaAt) / 1000;
    s.stamina = Math.min(staminaMax(c), s.stamina + staminaRegen(c) * secs);
    s.staminaAt = ctx.now;
  }
  if (cheats(s).unlimitedStamina) s.stamina = staminaMax(c);
  enforceMaxPrestige(s);
  if (ctx.now > s.heatAt) {
    const mins = (ctx.now - s.heatAt) / 60_000;
    s.heat = round2(Math.max(0, s.heat - heatCoolPerMin(s.careers.civ) * mins));
    s.heatAt = ctx.now;
  }
  if (s.travelTo && ctx.now >= s.travelUntil) {
    s.cityId = s.travelTo;
    s.travelTo = null;
    s.travelUntil = 0;
  }
  if (s.custody && ctx.now >= s.custody.jailedUntil) s.custody = null;
  settleCrews(ctx);
  settleWorkers(ctx);
  settleSalary(ctx);
  if (s.apdCase && s.apdCase.status === "active" && ctx.now > s.apdCase.until) s.apdCase.status = "expired";
  settleDuel(ctx);
}

/** Bring a save up to `now`. Pure: returns a new state, never touches the input. */
export function tick(state: PlayerState, shared: Shared, now: number): { state: PlayerState; shared: Shared; events: FeedEvent[] } {
  const ctx: Ctx = { s: clone(state), sh: cloneShared(shared), now, rng: () => 0, events: [], res: { ok: true } };
  settle(ctx);
  return { state: ctx.s, shared: ctx.sh, events: ctx.events };
}

// ---- custody

/** Seconds of the sentence a work detail can still shave off, and what one detail is worth right now. */
export function custodyCredit(s: PlayerState, now: number): { availableCreditSeconds: number; workRemainingSeconds: number } {
  const c = s.custody;
  if (!c) return { availableCreditSeconds: 0, workRemainingSeconds: 0 };
  const cap = Math.floor((c.sentenceMs / 1000) * INFERRED.prisonWorkCap);
  const workRemainingSeconds = Math.max(0, cap - c.creditedSeconds);
  const served = (now - c.startedAt) / 1000;
  const availableCreditSeconds = served < PRISON.mustServeFirstSeconds ? 0 : Math.min(workRemainingSeconds, INFERRED.prisonJobCreditSeconds);
  return { availableCreditSeconds, workRemainingSeconds };
}

/** "bail starts above the fine and gets cheaper the longer you have already served": fine * (1 + (bailStartMult - 1) * remaining / sentence). */
export function releaseCost(c: Custody, now: number): number {
  const remaining = Math.max(0, Math.min(c.sentenceMs, c.jailedUntil - now));
  return Math.round(c.fine * (1 + (INFERRED.bailStartMult - 1) * (remaining / c.sentenceMs)));
}

/**
 * An arrest: every illegal item in the civilian bag is seized, the heat is cleared, the sentence is
 * jailBaseSeconds + jailPerHeatSeconds per heat point, the fine is the level fine. Reachable only
 * through a pursuit (needs an officer); exported so the prison rules can be tested.
 */
export function jailPlayer(s: PlayerState, now: number, rng: Rng): Custody {
  const civ = s.careers.civ;
  for (const [id, n] of Object.entries(civ.inventory)) if (n > 0 && ITEM[id] && !ITEM[id].legal) take(civ, id, n);
  const sentenceMs = Math.round((INFERRED.jailBaseSeconds + INFERRED.jailPerHeatSeconds * s.heat) * 1000);
  const fine = fineEstimate(civ);
  s.heat = 0;
  s.heatAt = now;
  s.stats.timesBusted++;
  s.arrestFine = fine;
  s.custody = { id: uuidFrom(rng), startedAt: now, jailedUntil: now + sentenceMs, sentenceMs, fine, creditedSeconds: 0, job: null };
  return s.custody;
}

// ---- site gate

/**
 * The first reason `site` cannot be worked right now, or null: officers on illegal sites, city,
 * level, licence, stamina, then room (gather) or input (process). `forHire` stops after the
 * licence check (crews and contractors need the site reachable, not workable). The room check is
 * skipped when auto-sell will take the output.
 */
export function siteBlock(s: PlayerState, site: SiteDef, forHire = false): string | null {
  const c = career(s);
  if (factionOf(s) === "cop" && !site.legal) return "APD personnel cannot work illegal sites.";
  if (site.cityId !== s.cityId) return "That site is not in this city.";
  if (site.minLevel && level(s) < site.minLevel) return `Level ${site.minLevel}`;
  if (site.license && !c.licenses.includes(site.license)) return LICENSE[site.license]?.name ?? site.license;
  if (forHire) return null;
  if (!cheats(s).unlimitedStamina && s.stamina < site.stamina) return "Too tired";
  if (site.mode === "gather") {
    if (!autoSells(s, site.output) && roomFor(s, site.output) < 1) return "Pack full";
  } else if (site.input) {
    if ((c.inventory[site.input] ?? 0) < (site.inputPer ?? 1)) return `Need ${ITEM[site.input]?.name ?? site.input}`;
  }
  return null;
}

// ---- actions. Each handler validates first, then mutates the private copies and fills ctx.res;
// it returns the rejection string or null. On a rejection the caller keeps only the ticked copy.

function pickChest(roll: number): ChestRarity {
  const total = CHESTS.reduce((t, c) => t + c.weight, 0);
  let acc = 0;
  for (const c of CHESTS) {
    acc += c.weight;
    if (roll * total < acc) return c.rarity;
  }
  return CHESTS[CHESTS.length - 1].rarity;
}

/** A found chest: counted, in the result, and in the feed for epic and legendary ones. */
function findChest(ctx: Ctx, where: string): void {
  const rarity = pickChest(ctx.rng());
  ctx.s.chests[rarity] += 1;
  ctx.s.stats.chestsFound++;
  ctx.res.chest = rarity;
  if (rarity === "epic" || rarity === "legendary") ctx.events.push({ kind: "jackpot", text: `unearthed a ${CHEST[rarity].name} at ${where}` });
}

/** Every checkpointEveryClicks work clicks the player must prove there is a person at the wheel. */
function countClick(ctx: Ctx): void {
  ctx.s.checkpointClicks += 1;
  if (ctx.s.checkpointClicks >= INFERRED.checkpointEveryClicks && !ctx.s.checkpoint) {
    ctx.s.checkpoint = newCheckpoint(ctx.rng);
    ctx.s.checkpointClicks = 0;
  }
}

/**
 * A work click. Rng order, always consumed in full so a scripted rng lines up the same way at every
 * site: (1) bumper crop (gather) or efficiency (process), (2) jackpot, (3) chest, then only on a
 * hit (4) the rarity, (5) paper, then the checkpoint draw when one is due.
 */
function doWork(ctx: Ctx, site: SiteDef): string | null {
  const s = ctx.s;
  const c = career(s);
  const block = siteBlock(s, site);
  if (block) return block;
  let units = perClick(s, site, gangLevel(s, ctx.sh));
  const bonusRoll = ctx.rng();
  if (site.mode === "gather") {
    if (bonusRoll < chance((c.talents.bumperCrop ?? 0) * TALENT_PCT.bumperCropChance)) units *= 2;
  } else {
    // Process: the click affords min(yield, floor(held / inputPer)) base units; output scales with
    // that share of a full batch; an efficiency hit skips the consumption but not the output.
    const input = site.input as ItemId;
    const per = site.inputPer ?? 1;
    const baseUnits = Math.min(site.yield, Math.floor((c.inventory[input] ?? 0) / per));
    units = Math.max(1, floorSafe((units * baseUnits) / site.yield));
    if (!(bonusRoll < chance((c.talents.efficiency ?? 0) * TALENT_PCT.efficiencyChance))) take(c, input, baseUnits * per);
  }
  if (!cheats(s).unlimitedStamina) s.stamina -= site.stamina;
  s.stats.clicks++;
  const sold = autoSells(s, site.output);
  if (!sold) units = Math.min(units, roomFor(s, site.output));
  if (!sold) give(c, site.output, units);
  if (site.mode === "gather") s.stats.gathered += units;
  else s.stats.processed += units;
  ctx.res.gained = { [site.output]: units };
  if (sold && units > 0) sellUnits(ctx, s.cityId, site.output, units, false);
  gainXp(ctx, c, INFERRED.clickXpPerStamina * site.stamina);
  if (!site.legal) {
    const gained = addHeat(ctx, site.mode === "gather" ? INFERRED.heatGather : INFERRED.heatProcess);
    if (gained > 0) ctx.res.heat = round2((ctx.res.heat ?? 0) + gained);
  }
  const jackpotRoll = ctx.rng();
  if (site.jackpot) {
    const [item, base, n] = site.jackpot;
    if (jackpotRoll < chance(base * (1 + TALENT_PCT.prospectorJackpot * (c.talents.prospector ?? 0)))) {
      const fit = Math.min(n, roomFor(s, item));
      if (fit > 0) {
        give(c, item, fit);
        s.stats.jackpots++;
        ctx.res.gained[item] = (ctx.res.gained[item] ?? 0) + fit;
        ctx.res.jackpot = true;
        ctx.events.push({ kind: "jackpot", text: `struck ${ITEM[item].name} at ${site.name}` });
      }
    }
  }
  if (ctx.rng() < INFERRED.chestChancePerClick) findChest(ctx, site.name);
  if (ctx.rng() < CONTRACTS.paperDropChance) {
    s.papers += 1;
    ctx.res.papers = 1;
  }
  countClick(ctx);
  return null;
}

/** Positive whole units the player can part with: "all" or `n` clamped to what is held, or 0. */
function unitsHeld(c: CareerState, item: ItemId, n: number | "all"): number {
  const held = c.inventory[item] ?? 0;
  if (n === "all") return held;
  if (!Number.isInteger(n) || n < 1) return 0;
  return Math.min(n, held);
}

function doSell(ctx: Ctx, item: ItemId, n: number | "all"): string | null {
  const def = ITEM[item];
  if (!def) return "Unknown item.";
  if (def.sell <= 0) return "Nobody buys that raw.";
  if (factionOf(ctx.s) === "cop" && !def.legal) return "Officers do not fence contraband.";
  const units = unitsHeld(career(ctx.s), item, n);
  if (units < 1) return "You do not have that.";
  sellUnits(ctx, ctx.s.cityId, item, units, true);
  return null;
}

function doDrop(ctx: Ctx, item: ItemId, n: number | "all"): string | null {
  const def = ITEM[item];
  if (!def) return "Unknown item.";
  const c = career(ctx.s);
  const units = unitsHeld(c, item, n);
  if (units < 1) return "You do not have that.";
  take(c, item, units);
  ctx.res.message = `Dropped ${units} ${def.name}.`;
  return null;
}

/** Throw every illegal item away at once and halve the heat. Pays nothing. */
function doDitch(ctx: Ctx): string | null {
  const c = career(ctx.s);
  const units = illegalUnits(c);
  if (units === 0) return "Nothing to ditch.";
  for (const [id, n] of Object.entries(c.inventory)) if (n > 0 && ITEM[id] && !ITEM[id].legal) take(c, id, n);
  ctx.s.heat = round2(ctx.s.heat / 2);
  ctx.s.heatAt = ctx.now;
  ctx.res.message = `Ditched ${units} units of contraband.`;
  return null;
}

/** "Pay off your record": bribeCost clears the heat and keeps the bag; not in custody, not at heat 0. */
function doPayHeat(ctx: Ctx): string | null {
  const s = ctx.s;
  if (s.custody) return "Not available once you are in custody.";
  if (s.heat <= 0) return "Your record is clean.";
  const c = career(s);
  const cost = bribeCost(s);
  if (c.cash < cost) return `You are $${(cost - c.cash).toLocaleString("en-US")} short.`;
  addCash(ctx, c, -cost);
  s.heat = 0;
  s.heatAt = ctx.now;
  ctx.res.message = "Record cleared.";
  return null;
}

function doTravel(ctx: Ctx, city: CityId): string | null {
  const s = ctx.s;
  const dest = CITY[city];
  if (!dest) return "Unknown city.";
  if (city === s.cityId) return "You are already there.";
  s.travelTo = city;
  s.travelUntil = ctx.now + travelMs(s, city);
  ctx.res.message = `On the road to ${dest.name}.`;
  return null;
}

function doLicense(ctx: Ctx, id: string): string | null {
  const def = LICENSE[id];
  const c = career(ctx.s);
  if (!def || (def.faction ?? "civ") !== factionOf(ctx.s)) return "That licence is not for your career.";
  if (c.licenses.includes(id)) return "Already held.";
  if (c.cash < def.cost) return "Not enough cash.";
  addCash(ctx, c, -def.cost);
  c.licenses.push(id);
  gainXp(ctx, c, def.cost * INFERRED.purchaseXpPerDollar);
  return null;
}

function doSkill(ctx: Ctx, id: string): string | null {
  const def = SKILL[id];
  const c = career(ctx.s);
  if (!def || (def.faction !== "both" && def.faction !== factionOf(ctx.s))) return "That skill is not for your career.";
  const rank = c.skills[id] ?? 0;
  const cost = skillCost(def.costs, def.max, rank);
  if (cost === null) return "Already maxed.";
  if (c.cash < cost) return "Not enough cash.";
  addCash(ctx, c, -cost);
  c.skills[id] = rank + 1;
  gainXp(ctx, c, cost * INFERRED.purchaseXpPerDollar);
  return null;
}

function doTalent(ctx: Ctx, id: string): string | null {
  const def = TALENT[id];
  const c = career(ctx.s);
  if (!def || (def.faction !== "both" && def.faction !== factionOf(ctx.s))) return "That talent is not for your career.";
  const rank = c.talents[id] ?? 0;
  if (rank >= def.max) return "Already maxed.";
  if (level(ctx.s) < def.minLevel) return `Needs level ${def.minLevel}.`;
  const cost = def.costs[rank];
  if (talentPoints(c) < cost) return "Not enough talent points.";
  c.talents[id] = rank + 1;
  ctx.events.push({ kind: "level", text: `trained ${def.name} ${rank + 1}` });
  ctx.res.message = `Learned ${def.name} ${rank + 1}.`;
  return null;
}

function doRespec(ctx: Ctx): string | null {
  const c = career(ctx.s);
  if (talentSpent(c) <= 0) return "Nothing to refund.";
  const cost = respecCost(c);
  if (c.cash < cost) return "Not enough cash.";
  addCash(ctx, c, -cost);
  c.talents = {};
  c.respecs += 1;
  ctx.res.message = "Every talent point refunded.";
  return null;
}

/** Tools, vehicle and backpack move to the next tier (civilians only); checks top tier, level, cash in that order. */
function doTier(ctx: Ctx, what: "gear" | "pack" | ToolKind): string | null {
  const s = ctx.s;
  const c = career(s);
  if (factionOf(s) === "cop") return "Officers use standard issue.";
  let next: { name: string; cost: number; minLevel?: number; tier: number } | undefined;
  if (what === "gear") next = GEAR[c.gearTier + 1];
  else if (what === "pack") next = BACKPACKS[c.packTier + 1];
  else next = toolOf(what, c.tools[what] + 1);
  if (!next) return "Top of the ladder.";
  if (next.minLevel && level(s) < next.minLevel) return `Needs level ${next.minLevel}.`;
  if (c.cash < next.cost) return "Not enough cash.";
  addCash(ctx, c, -next.cost);
  if (what === "gear") c.gearTier = next.tier;
  else if (what === "pack") c.packTier = next.tier;
  else c.tools[what] = next.tier;
  gainXp(ctx, c, next.cost * INFERRED.purchaseXpPerDollar);
  return null;
}

/** APD equipment: the next tier needs its certification ("requires") and the cash. */
function doCopGear(ctx: Ctx): string | null {
  const s = ctx.s;
  const c = career(s);
  if (factionOf(s) !== "cop") return "Civilians cannot draw APD equipment.";
  const next = COP_GEAR[c.copGearTier + 1];
  if (!next) return "Top of the ladder.";
  if (next.requires && !c.licenses.includes(next.requires)) return `Needs the ${LICENSE[next.requires]?.name ?? next.requires}.`;
  if (c.cash < next.cost) return "Not enough cash.";
  addCash(ctx, c, -next.cost);
  c.copGearTier = next.tier;
  gainXp(ctx, c, next.cost * INFERRED.purchaseXpPerDollar);
  return null;
}

function doCrew(ctx: Ctx, site: SiteDef): string | null {
  const s = ctx.s;
  const c = career(s);
  if (factionOf(s) === "cop") return "Officers cannot hire crews.";
  if (site.mode !== "gather" || !CREW[site.id]) return "No crew works there.";
  const block = siteBlock(s, site, true);
  if (block) return block;
  const owned = c.crews[site.id] ?? 0;
  if (owned >= CONST.maxCrewsPerSite) return `Crew maxed (${owned})`;
  const cost = crewCost(site.id, owned);
  if (c.cash < cost) return "Not enough cash.";
  addCash(ctx, c, -cost);
  c.crews[site.id] = owned + 1;
  return null;
}

/** Park or resume the crews at one site, or every crew when siteId is null ("Pause all" / "Resume all"). */
function doCrewPause(ctx: Ctx, siteId: string | null, paused: boolean): string | null {
  const c = career(ctx.s);
  if (factionOf(ctx.s) === "cop") return "Officers cannot hire crews.";
  const sites = siteId === null ? Object.keys(c.crews).filter((id) => c.crews[id] > 0) : [siteId];
  if (siteId !== null && !(c.crews[siteId] > 0)) return "No crew at that site.";
  if (sites.length === 0) return "No crews yet.";
  for (const id of sites) {
    const i = c.pausedCrews.indexOf(id);
    if (paused && i < 0) c.pausedCrews.push(id);
    if (!paused && i >= 0) c.pausedCrews.splice(i, 1);
  }
  ctx.res.message = paused ? "Crews parked." : "Crews back to work.";
  return null;
}

function doWorker(ctx: Ctx, site: SiteDef, minutes: number, kind: ToolKind): string | null {
  const s = ctx.s;
  const c = career(s);
  if (factionOf(s) === "cop") return "Officers cannot hire contractors.";
  const rate = contractRate(site.id);
  if (rate === null || kind !== site.mode) return "That site takes no contracts.";
  const block = siteBlock(s, site, true);
  if (block) return block;
  const running = c.workers.find((w) => w.siteId === site.id);
  if (kind === "gather") {
    const entry = CONTRACTS.worker.find((w) => w.minutes === minutes);
    if (!entry) return "Unknown contract length.";
    if (!running && c.workers.length >= CONTRACTS.workerMaxActive) return `Already running ${CONTRACTS.workerMaxActive} contracts`;
    if (s.papers < entry.papers) return "Not enough contract papers.";
    s.papers -= entry.papers;
  } else {
    const entry = CONTRACTS.process.find((p) => p.minutes === minutes);
    if (!entry) return "Unknown contract length.";
    if (!running && c.workers.length >= CONTRACTS.workerMaxActive) return `Already running ${CONTRACTS.workerMaxActive} contracts`;
    if (s.processPapers < entry.contracts) return "Not enough processing contracts.";
    s.processPapers -= entry.contracts;
  }
  if (running) {
    running.until += minutes * 60_000;
    running.perMinute = rate;
    ctx.res.message = `Extended the contract at ${site.name} by ${minutes} min.`;
  } else {
    c.workers.push({ siteId: site.id, kind, perMinute: rate, startedAt: ctx.now, until: ctx.now + minutes * 60_000, lastTickAt: ctx.now, earned: 0 });
    ctx.res.message = `Contractor hired at ${site.name} for ${minutes} min.`;
  }
  return null;
}

function doCraftContract(ctx: Ctx, qty: number): string | null {
  const cost = qty * CONTRACTS.processContractPaperCost;
  if (!Number.isInteger(qty) || qty < 1) return "Bad action";
  if (ctx.s.papers < cost) return `Needs ${cost} papers — you have ${ctx.s.papers}`;
  ctx.s.papers -= cost;
  ctx.s.processPapers += qty;
  ctx.res.message = `Drew up ${qty} processing contract${qty === 1 ? "" : "s"}.`;
  return null;
}

/** Cash and xp scale with (1 + chestLevelScale * level); papers are one uniform roll in [min, max]. */
function doOpenChest(ctx: Ctx, rarity: ChestRarity): string | null {
  const def = CHEST[rarity];
  const s = ctx.s;
  if (!def || !(s.chests[rarity] > 0)) return "No such chest.";
  const c = career(s);
  const scale = 1 + INFERRED.chestLevelScale * level(s);
  const cash = Math.round(def.cash * scale);
  const [lo, hi] = CHEST_DETAILS[rarity].papers;
  const papers = lo + rngInt(ctx.rng, hi - lo + 1);
  s.chests[rarity] -= 1;
  addCash(ctx, c, cash);
  if (papers > 0) {
    s.papers += papers;
    ctx.res.papers = papers;
  }
  gainXp(ctx, c, CHEST_DETAILS[rarity].xp * scale);
  return null;
}

function doAutoSell(ctx: Ctx): string | null {
  const s = ctx.s;
  const c = career(s);
  if (factionOf(s) === "cop") return "Auto-sell is a civilian perk.";
  if (!c.autoSell && level(s) < CONST.autoSellUnlockLevel) return `Auto-sell unlocks at level ${CONST.autoSellUnlockLevel}.`;
  c.autoSell = !c.autoSell;
  ctx.res.message = c.autoSell ? "Auto-sell on." : "Auto-sell off.";
  return null;
}

function doWorkerAutoSell(ctx: Ctx): string | null {
  const c = career(ctx.s);
  c.workerAutoSell = !c.workerAutoSell;
  ctx.res.message = c.workerAutoSell ? "Contractor auto-sell on." : "Contractor auto-sell off.";
  return null;
}

/**
 * Prestige resets the active career (cash to starBankroll * rank, xp, licences, skills, talents,
 * respecs, equipment, bag, crews, contractors, auto-sell) and keeps chests, papers, stats, perks;
 * prestige and starPicks go up by one.
 */
function doPrestige(ctx: Ctx): string | null {
  const s = ctx.s;
  const c = career(s);
  const blockers = prestigeBlockers(c, factionOf(s));
  if (blockers.length) return blockers[0];
  const kept = { prestige: c.prestige + 1, starPicks: c.starPicks + 1, perks: c.perks };
  const fresh = newCareer(ctx.now);
  s.careers[factionOf(s)] = { ...fresh, ...kept, cash: STAR_PERK.starBankroll.value * (kept.perks.starBankroll ?? 0) };
  s.stamina = Math.min(s.stamina, staminaMax(career(s)));
  ctx.events.push({ kind: "raid", text: `retired a ${factionOf(s) === "cop" ? "APD" : "civilian"} run for star ${kept.prestige}` });
  ctx.res.message = `Star ${kept.prestige} earned.`;
  return null;
}

function doStarPerk(ctx: Ctx, id: string): string | null {
  const def = STAR_PERK[id];
  const c = career(ctx.s);
  if (!def || (def.faction !== "both" && def.faction !== factionOf(ctx.s))) return "That perk is not for your career.";
  if (c.starPicks < 1) return "No star to spend.";
  const rank = c.perks[id] ?? 0;
  if (rank >= def.max) return "Already maxed.";
  c.starPicks -= 1;
  c.perks[id] = rank + 1;
  ctx.res.message = `${def.name} ${rank + 1} attuned.`;
  return null;
}

/** The career picker; cops start their salary clock. */
function doFaction(ctx: Ctx, faction: Faction): string | null {
  const s = ctx.s;
  if (s.faction) return "You already have a career.";
  s.faction = faction;
  s.careers[faction].salaryAt = ctx.now;
  s.careers.civ.crewsAt = ctx.now;
  s.stamina = staminaMax(career(s));
  s.staminaAt = ctx.now;
  ctx.events.push({ kind: "join", text: faction === "cop" ? "joined the APD" : "landed on the island as a civilian" });
  return null;
}

/** "Switching careers": 15-minute cooldown, no badge while under investigation (heat above 1); the other career resumes where it left off. */
function doSwitch(ctx: Ctx, faction: Faction): string | null {
  const s = ctx.s;
  if (s.faction === faction) return faction === "cop" ? "You are already an APD officer." : "You are already a civilian.";
  if (s.careerSwitchReadyAt > ctx.now) return `Paperwork pending — ${Math.max(0, Math.ceil((s.careerSwitchReadyAt - ctx.now) / 1000))}s.`;
  if (faction === "cop" && s.heat > 1) return "The APD will not take you while you are under investigation. Let your heat cool.";
  s.faction = faction;
  s.careerSwitchReadyAt = ctx.now + CONST.careerSwitchCooldownMin * 60_000;
  if (faction === "cop") s.careers.cop.salaryAt = ctx.now;
  else s.careers.civ.crewsAt = ctx.now;
  s.stamina = Math.min(s.stamina, staminaMax(career(s)));
  s.blackjack = null;
  ctx.res.message = faction === "cop" ? "Badge on. Welcome to the APD." : "Badge handed in. Back to civilian life.";
  return null;
}

// ---- APD

function patrolStamina(c: CareerState): number {
  const gear = COP_GEAR[c.copGearTier] ?? COP_GEAR[0];
  return Math.max(1, INFERRED.patrolStamina + gear.staminaDelta - Math.floor((c.talents.rapidResponse ?? 0) / 2));
}

/** Reward of a paid dispatch call: base + per level, Rapid Response, Dispatch, Decorated Officer, gear bounty and manpower. */
export function caseReward(c: CareerState, manpowerMult: number): number {
  const gear = COP_GEAR[c.copGearTier] ?? COP_GEAR[0];
  const base = INFERRED.caseRewardBase + INFERRED.caseRewardPerLevel * levelOf(c);
  const rapid = 1 + TALENT_PCT.rapidResponsePayout * (c.talents.rapidResponse ?? 0);
  const dispatch = 1 + INFERRED.caseDispatchPct * (c.skills.dispatch ?? 0);
  const badge = 1 + STAR_PERK.starBadge.value * (c.perks.starBadge ?? 0);
  return Math.round(base * rapid * dispatch * badge * gear.bountyMult * manpowerMult);
}

function doCaseStart(ctx: Ctx, practice: boolean, manpowerMult: number): string | null {
  const s = ctx.s;
  const c = career(s);
  if (factionOf(s) !== "cop") return "Only APD officers take calls.";
  if (s.apdCase && s.apdCase.status === "active") return "Finish the open case first.";
  let reward = 0;
  if (!practice) {
    if (ctx.now < s.apdCaseReadyAt) return `Cooling down (${Math.max(0, Math.ceil((s.apdCaseReadyAt - ctx.now) / 1000))}s)`;
    const crime = npcCrimeAt(ctx.sh.npcCrime[s.cityId], ctx.now);
    if (crime < PAID_CALL_NPC_CRIME_MIN) return "No paid calls here";
    const cost = patrolStamina(c);
    if (!cheats(s).unlimitedStamina) {
      if (s.stamina < cost) return "Too tired";
      s.stamina -= cost;
    }
    ctx.sh.npcCrime[s.cityId] = { value: Math.max(0, crime - INFERRED.npcCrimeCostPerCase), at: ctx.now };
    s.stats.clicks++;
    reward = caseReward(c, manpowerMult);
    countClick(ctx);
  }
  const startsAt = ctx.now + INFERRED.caseReadyDelayMs;
  s.apdCase = {
    id: uuidFrom(ctx.rng), status: "active", practice, targetScore: INFERRED.caseTargetScore, reward,
    rounds: routeRounds(ctx.rng), answers: [], startsAt, until: startsAt + INFERRED.caseWindowMs,
  };
  return null;
}

function doCaseAnswer(ctx: Ctx, id: string, round: number, choice: number): string | null {
  const s = ctx.s;
  const c = career(s);
  const k = s.apdCase;
  if (!k || k.status !== "active") return "No open case.";
  if (k.id !== id) return "That case is closed.";
  if (ctx.now < k.startsAt) return "Get ready. The call has not started.";
  if (round !== k.answers.length) return "Answer the checkpoints in order.";
  if (!Number.isInteger(choice) || choice < 0 || choice >= k.rounds[round].options.length) return "Bad choice.";
  k.answers.push({ choice, score: routeScore(k.rounds[round], choice) });
  if (k.answers.length < k.rounds.length) return null;
  if (routeTotal(k.answers) >= k.targetScore) {
    k.status = "won";
    if (!k.practice) {
      addCash(ctx, c, k.reward);
      s.stats.earned += k.reward;
      gainXp(ctx, c, INFERRED.caseXp);
      if (ctx.rng() < INFERRED.chestChancePerClick) findChest(ctx, `a ${CITY[s.cityId].name} patrol`);
      s.apdCaseReadyAt = ctx.now + INFERRED.caseCooldownMs;
    }
  } else {
    k.status = "lost";
    if (!k.practice) s.apdCaseReadyAt = ctx.now + INFERRED.caseCooldownMs;
  }
  return null;
}

/** An arrest needs a wanted civilian in the officer's city; alone on the island there is never one. */
function doBust(ctx: Ctx, targetId: string): string | null {
  const s = ctx.s;
  if (factionOf(s) !== "cop") return "Only APD officers make arrests.";
  if (!cheats(s).unlimitedStamina && s.stamina < ARREST_STAMINA_MIN) return "Too tired";
  if (s.duel && s.duel.status !== "resolved") return "You are already in a pursuit.";
  void targetId;
  return "No such suspect.";
}

// ---- custody actions

function doRelease(ctx: Ctx): string | null {
  const s = ctx.s;
  const c = career(s);
  if (!s.custody) return "You are not in custody.";
  const cost = releaseCost(s.custody, ctx.now);
  if (c.cash < cost) return `You are $${(cost - c.cash).toLocaleString("en-US")} short.`;
  addCash(ctx, c, -cost);
  s.custody = null;
  ctx.res.message = "Released.";
  return null;
}

function doPrisonStart(ctx: Ctx): string | null {
  const s = ctx.s;
  if (!s.custody) return "You are not in custody.";
  if (s.custody.job) return "A work detail is already running.";
  const credit = custodyCredit(s, ctx.now);
  if (credit.availableCreditSeconds <= 0) {
    return credit.workRemainingSeconds <= 0
      ? "You've worked off as much of this sentence as the rules allow — ride out the rest, or pay to leave."
      : "No eligible work time yet — the first 60 seconds of any sentence must be served.";
  }
  s.custody.job = newPrisonJob(ctx.rng, ctx.now, PRISON.jobSeconds);
  return null;
}

function jobCheck(s: PlayerState, custodyId: string, jobId: string): string | null {
  if (!s.custody) return "You are not in custody.";
  if (s.custody.id !== custodyId || !s.custody.job || s.custody.job.id !== jobId) return "No such work detail.";
  return null;
}

function doPrisonRotate(ctx: Ctx, custodyId: string, jobId: string, tile: number): string | null {
  const err = jobCheck(ctx.s, custodyId, jobId);
  if (err) return err;
  if (!Number.isInteger(tile) || tile < 0 || tile > 8) return "Bad tile.";
  const job = ctx.s.custody!.job!;
  job.tiles[tile] = rotateTile(job.tiles[tile]);
  return null;
}

function doPrisonComplete(ctx: Ctx, custodyId: string, jobId: string): string | null {
  const s = ctx.s;
  const err = jobCheck(s, custodyId, jobId);
  if (err) return err;
  const custody = s.custody!;
  const job = custody.job!;
  if (ctx.now < job.readyAt) return `Working... ${Math.max(0, Math.ceil((job.readyAt - ctx.now) / 1000))}s`;
  custody.job = null;
  if (!pipesSolved(job.tiles)) {
    ctx.res.message = "The pipes leak. Try again.";
    return null;
  }
  const credit = custodyCredit(s, ctx.now).availableCreditSeconds;
  custody.creditedSeconds += credit;
  custody.jailedUntil -= credit * 1000;
  if (ctx.now >= custody.jailedUntil) s.custody = null;
  ctx.res.message = `Repair accepted. ${credit}s off your sentence.`;
  return null;
}

// ---- pursuit (the player's side of a duel; needs an officer and a civilian, so alone it never starts)

function duelCheck(s: PlayerState, id: string): string | null {
  if (!s.duel || s.duel.status === "resolved") return "No active pursuit.";
  if (s.duel.id !== id) return "That pursuit is over.";
  return null;
}

function doPursuitReady(ctx: Ctx, id: string): string | null {
  const err = duelCheck(ctx.s, id);
  if (err) return err;
  const d = ctx.s.duel!;
  if (d.status !== "pending") return "The pursuit is already under way.";
  d.myReady = true;
  if (d.opponentReady) {
    d.status = "active";
    d.startsAt = ctx.now + INFERRED.duelStartDelayMs;
    d.until = d.startsAt + INFERRED.duelWindowMs;
  }
  return null;
}

function doPursuitAnswer(ctx: Ctx, id: string, round: number, choice: number): string | null {
  const err = duelCheck(ctx.s, id);
  if (err) return err;
  const d = ctx.s.duel!;
  if (d.status !== "active") return "The pursuit has not started.";
  if (ctx.now < d.startsAt) return "Get ready. The pursuit has not started.";
  if (round !== d.myAnswers.length) return "Answer the checkpoints in order.";
  if (!Number.isInteger(choice) || choice < 0 || choice >= d.rounds[round].options.length) return "Bad choice.";
  d.myAnswers.push({ choice, score: routeScore(d.rounds[round], choice) });
  if (d.myAnswers.length === d.rounds.length && d.opponentAnswers.length === d.rounds.length) settleActiveDuel(ctx, d);
  return null;
}

function doPursuitSurrender(ctx: Ctx, id: string): string | null {
  const err = duelCheck(ctx.s, id);
  if (err) return err;
  const d = ctx.s.duel!;
  if (d.role !== "civ") return "Officers do not surrender.";
  resolveDuel(ctx, d, "capture", "You surrendered and were taken into custody.");
  return null;
}

/** Both sides of a fresh pursuit, mirrored, for the store to hand each player; exported for tests. */
export function newDuelPair(cop: { id: string; name: string }, civ: { id: string; name: string }, rng: Rng, now: number): { cop: Duel; civ: Duel } {
  const id = uuidFrom(rng);
  const rounds = routeRounds(rng);
  const base = { id, status: "pending" as const, readyUntil: now + INFERRED.duelReadyMs, startsAt: 0, until: 0, rounds, myAnswers: [], opponentAnswers: [], myReady: false, opponentReady: false, outcome: null, reason: null };
  return {
    cop: { ...base, role: "cop", opponentId: civ.id, opponentName: civ.name },
    civ: { ...base, role: "civ", opponentId: cop.id, opponentName: cop.name },
  };
}

// ---- checkpoint (anti-automation)

function doVerify(ctx: Ctx, id: string, answer: string): string | null {
  const s = ctx.s;
  const cp = s.checkpoint;
  if (!cp) return "No checkpoint pending.";
  if (cp.lockedUntil > ctx.now) return "Too many misses. A fresh checkpoint opens when the timer runs out.";
  if (cp.id !== id) return "That checkpoint has expired.";
  if (answer === cp.target) {
    s.checkpoint = null;
    s.checkpointClicks = 0;
    return null;
  }
  cp.misses += 1;
  if (cp.misses >= INFERRED.checkpointMaxMisses) {
    s.checkpoint = { ...newCheckpoint(ctx.rng), lockedUntil: ctx.now + INFERRED.checkpointLockMs };
    ctx.fail = "Too many misses. A fresh checkpoint opens when the timer runs out.";
    return null;
  }
  ctx.fail = "Wrong one. Try again.";
  return null;
}

/** The hidden "Claim free cash" button: only automation finds it. */
function doHoneypot(ctx: Ctx): string | null {
  ctx.s.activityLockUntil = ctx.now + INFERRED.honeypotLockMs;
  return null;
}

function doChat(text: string): string | null {
  const t = text.trim();
  if (!t) return "Say something.";
  if (t.length > CONST.chatMaxLen) return `Keep it under ${CONST.chatMaxLen} characters.`;
  return null;
}

// ---- gangs

export function gangCap(level: number): number {
  return Math.min(GANG.maxCap, GANG.baseCap + Math.floor(level / 2));
}

/** The invite code for the current window: rolls every inviteWindowMs and on every use. */
export function gangInvite(g: GangRecord, now: number): { code: string; expiresAt: number } {
  const epoch = Math.floor(now / GANG.inviteWindowMs);
  return { code: inviteCodeFrom(g.codeSeed, epoch, g.codeBumps), expiresAt: (epoch + 1) * GANG.inviteWindowMs };
}

function doGangCreate(ctx: Ctx, name: string, tag: string): string | null {
  const s = ctx.s;
  const c = career(s);
  if (factionOf(s) !== "civ") return "Gangs are a civilian thing.";
  if (s.gangId && ctx.sh.gangs[s.gangId]) return "Leave your gang first.";
  if (level(s) < GANG.minLevel) return `Needs level ${GANG.minLevel}.`;
  const n = name.trim();
  const t = tag.trim().toUpperCase();
  if (n.length < 3 || n.length > 20) return "Gang name must be 3-20 characters.";
  if (t.length < 2 || t.length > 4 || !/^[A-Z0-9]+$/.test(t)) return "Tag must be 2-4 letters or digits.";
  for (const g of Object.values(ctx.sh.gangs)) {
    if (g.tag === t) return "That tag is taken.";
    if (g.name.toLowerCase() === n.toLowerCase()) return "That name is taken.";
  }
  if (c.cash < GANG.createCost) return "Not enough cash.";
  addCash(ctx, c, -GANG.createCost);
  const id = cuidFrom(ctx.rng);
  ctx.sh.gangs[id] = { id, name: n, tag: t, leaderId: s.steamId, private: false, codeSeed: uuidFrom(ctx.rng), codeBumps: 0, xp: 0, createdAt: ctx.now, members: [{ steamId: s.steamId, joinedAt: ctx.now }] };
  s.gangId = id;
  ctx.events.push({ kind: "join", text: `founded [${t}] ${n}` });
  return null;
}

function doGangJoin(ctx: Ctx, gangId: string, code: string): string | null {
  const s = ctx.s;
  if (factionOf(s) !== "civ") return "Gangs are a civilian thing.";
  if (s.gangId && ctx.sh.gangs[s.gangId]) return "Leave your gang first.";
  const g = ctx.sh.gangs[gangId];
  if (!g) return "That gang no longer exists.";
  if (g.members.length >= gangCap(gangLevelFromXp(g.xp).level)) return "Full — slots unlock as the gang levels";
  if (g.private) {
    if (code.trim().toUpperCase() !== gangInvite(g, ctx.now).code) return "Wrong invite code.";
    g.codeBumps += 1;
  }
  g.members.push({ steamId: s.steamId, joinedAt: ctx.now });
  s.gangId = g.id;
  ctx.res.message = `Joined [${g.tag}] ${g.name}.`;
  return null;
}

/** Leaving passes the lead to the longest-standing member; the last member dissolves the gang. */
function doGangLeave(ctx: Ctx): string | null {
  const s = ctx.s;
  const g = gangOf(s, ctx.sh);
  if (!g) {
    s.gangId = null;
    return "You are not in a gang.";
  }
  g.members = g.members.filter((m) => m.steamId !== s.steamId);
  if (g.members.length === 0) delete ctx.sh.gangs[g.id];
  else if (g.leaderId === s.steamId) g.leaderId = [...g.members].sort((a, b) => a.joinedAt - b.joinedAt)[0].steamId;
  s.gangId = null;
  ctx.res.message = `Left [${g.tag}] ${g.name}.`;
  return null;
}

function doGangKick(ctx: Ctx, targetId: string): string | null {
  const s = ctx.s;
  const g = gangOf(s, ctx.sh);
  if (!g) return "You are not in a gang.";
  if (g.leaderId !== s.steamId) return "Only the leader can kick.";
  if (targetId === s.steamId) return "You cannot kick yourself.";
  if (!g.members.some((m) => m.steamId === targetId)) return "They are not in your gang.";
  g.members = g.members.filter((m) => m.steamId !== targetId);
  ctx.res.message = "Kicked.";
  return null;
}

function doGangPrivacy(ctx: Ctx, isPrivate: boolean): string | null {
  const s = ctx.s;
  const g = gangOf(s, ctx.sh);
  if (!g) return "You are not in a gang.";
  if (g.leaderId !== s.steamId) return "Only the leader can change this.";
  g.private = isPrivate;
  ctx.res.message = isPrivate ? "Gang set to private." : "Gang set to public.";
  return null;
}

// ---- casino

function wagerCheck(c: CareerState, bet: number): string | null {
  if (!Number.isInteger(bet) || bet < 1) return "Bad wager.";
  if (c.cash < bet) return "Not enough cash.";
  return null;
}

function doBlackjackDeal(ctx: Ctx, bet: number): string | null {
  const s = ctx.s;
  const c = career(s);
  if (s.blackjack && s.blackjack.status === "playing") return "Finish the hand first.";
  const err = wagerCheck(c, bet);
  if (err) return err;
  c.cash -= bet;
  s.blackjack = blackjackDeal(ctx.rng, bet);
  settleBlackjack(ctx);
  return null;
}

function settleBlackjack(ctx: Ctx): void {
  const h = ctx.s.blackjack;
  if (!h || h.status === "playing") return;
  const c = career(ctx.s);
  c.cash += h.payout;
  const net = h.payout - h.bet;
  if (net !== 0) ctx.res.cash = net;
  ctx.res.message = h.status === "won" ? "You won the hand." : h.status === "push" ? "Push." : "Dealer won.";
}

function doBlackjackHit(ctx: Ctx): string | null {
  const s = ctx.s;
  if (!s.blackjack || s.blackjack.status !== "playing") return "No hand in play.";
  s.blackjack = blackjackHit(s.blackjack);
  settleBlackjack(ctx);
  return null;
}

function doBlackjackStand(ctx: Ctx): string | null {
  const s = ctx.s;
  if (!s.blackjack || s.blackjack.status !== "playing") return "No hand in play.";
  s.blackjack = blackjackStand(s.blackjack);
  settleBlackjack(ctx);
  return null;
}

function doSlots(ctx: Ctx, bet: number): string | null {
  const c = career(ctx.s);
  const err = wagerCheck(c, bet);
  if (err) return err;
  const r = spinSlots(ctx.rng, bet);
  c.cash += r.payout - bet;
  if (r.payout !== bet) ctx.res.cash = r.payout - bet;
  ctx.res.casino = r;
  return null;
}

function doRoulette(ctx: Ctx, bet: number, choice: RouletteChoice, number: number): string | null {
  const c = career(ctx.s);
  const err = wagerCheck(c, bet);
  if (err) return err;
  if (choice === "number" && (!Number.isInteger(number) || number < 0 || number > 36)) return "Pick a number 0-36.";
  const r = spinRoulette(ctx.rng, bet, choice, number);
  c.cash += r.payout - bet;
  if (r.payout !== bet) ctx.res.cash = r.payout - bet;
  ctx.res.casino = r;
  return null;
}

function doPokerJoin(ctx: Ctx, buyIn: number): string | null {
  const s = ctx.s;
  const c = career(s);
  const t = ctx.sh.poker;
  if (t.seats.some((x) => x.steamId === s.steamId)) return "You are already seated.";
  if (t.seats.length >= CASINO.pokerMaxPlayers) return "The table is full.";
  const err = wagerCheck(c, buyIn);
  if (err) return err;
  if (t.buyIn !== null && buyIn !== t.buyIn) return `Buy-in (table requires $${t.buyIn.toLocaleString("en-US")})`;
  addCash(ctx, c, -buyIn);
  t.seats.push({ steamId: s.steamId, name: s.name, buyIn, faction: factionOf(s) });
  t.pot += buyIn;
  t.buyIn = buyIn;
  return null;
}

/** The showdown pays the winners; the caller credits every winner other than this player. */
function doPokerDeal(ctx: Ctx): string | null {
  const s = ctx.s;
  const t = ctx.sh.poker;
  if (!t.seats.some((x) => x.steamId === s.steamId)) return "Take a seat first.";
  if (t.seats.length < t.minPlayers) return "Waiting for one more player.";
  const result = pokerShowdown(ctx.rng, t.seats, t.pot);
  const mine = result.winners.find((w) => w.steamId === s.steamId);
  if (mine) addCash(ctx, career(s), mine.payout);
  t.lastResult = result;
  t.seats = [];
  t.pot = 0;
  t.buyIn = null;
  ctx.res.message = mine ? "You took the pot." : "The pot went elsewhere.";
  return null;
}

function doPokerLeave(ctx: Ctx): string | null {
  const s = ctx.s;
  const t = ctx.sh.poker;
  const seat = t.seats.find((x) => x.steamId === s.steamId);
  if (!seat) return "You are not seated.";
  t.seats = t.seats.filter((x) => x.steamId !== s.steamId);
  t.pot -= seat.buyIn;
  if (t.seats.length === 0) t.buyIn = null;
  addCash(ctx, career(s), seat.buyIn);
  return null;
}

// ---- dispatch

/** Actions that go through in custody, on the road, under a lock and during a checkpoint. */
const ALWAYS_OK = new Set<Action["type"]>(["hp", "verify", "chat", "release", "prisonstart", "prisonrotate", "prisoncomplete", "pursuitready", "pursuitanswer", "pursuitsurrender", "reset"]);

function run(ctx: Ctx, action: Action, manpowerMult: number): string | null {
  const s = ctx.s;
  switch (action.type) {
    case "work": {
      const site = SITE[action.siteId];
      return site ? doWork(ctx, site) : "Unknown site.";
    }
    case "sell":
      return doSell(ctx, action.itemId, action.amount);
    case "drop":
      return doDrop(ctx, action.itemId, action.amount);
    case "ditch":
      return doDitch(ctx);
    case "payheat":
      return doPayHeat(ctx);
    case "travel":
      return doTravel(ctx, action.cityId);
    case "license":
      return doLicense(ctx, action.licenseId);
    case "skill":
      return doSkill(ctx, action.skillId);
    case "talent":
      return doTalent(ctx, action.talentId);
    case "respec":
      return doRespec(ctx);
    case "tool":
      return doTier(ctx, action.kind);
    case "gear":
      return doTier(ctx, "gear");
    case "pack":
      return doTier(ctx, "pack");
    case "copgear":
      return doCopGear(ctx);
    case "crew": {
      const site = SITE[action.siteId];
      return site ? doCrew(ctx, site) : "Unknown site.";
    }
    case "crewpause":
      if (action.siteId !== null && !SITE[action.siteId]) return "Unknown site.";
      return doCrewPause(ctx, action.siteId, action.paused);
    case "worker": {
      const site = SITE[action.siteId];
      return site ? doWorker(ctx, site, action.minutes, action.kind) : "Unknown site.";
    }
    case "craftcontract":
      return doCraftContract(ctx, action.qty);
    case "openchest":
      return doOpenChest(ctx, action.rarity);
    case "autosell":
      return doAutoSell(ctx);
    case "workerautosell":
      return doWorkerAutoSell(ctx);
    case "prestige":
      return doPrestige(ctx);
    case "starperk":
      return doStarPerk(ctx, action.perkId);
    case "faction":
      return doFaction(ctx, action.faction);
    case "switch":
      return doSwitch(ctx, action.faction);
    case "casestart":
      return doCaseStart(ctx, action.practice, manpowerMult);
    case "caseanswer":
      return doCaseAnswer(ctx, action.id, action.round, action.choice);
    case "bust":
      return doBust(ctx, action.targetId);
    case "release":
      return doRelease(ctx);
    case "prisonstart":
      return doPrisonStart(ctx);
    case "prisonrotate":
      return doPrisonRotate(ctx, action.custodyId, action.jobId, action.tile);
    case "prisoncomplete":
      return doPrisonComplete(ctx, action.custodyId, action.jobId);
    case "pursuitready":
      return doPursuitReady(ctx, action.id);
    case "pursuitanswer":
      return doPursuitAnswer(ctx, action.id, action.round, action.choice);
    case "pursuitsurrender":
      return doPursuitSurrender(ctx, action.id);
    case "verify":
      return doVerify(ctx, action.id, action.answer);
    case "hp":
      return doHoneypot(ctx);
    case "chat":
      return doChat(action.text);
    case "gangcreate":
      return doGangCreate(ctx, action.name, action.tag);
    case "gangjoin":
      return doGangJoin(ctx, action.gangId, action.code);
    case "gangleave":
      return doGangLeave(ctx);
    case "gangkick":
      return doGangKick(ctx, action.targetId);
    case "gangprivacy":
      return doGangPrivacy(ctx, action.private);
    case "blackjackdeal":
      return doBlackjackDeal(ctx, action.bet);
    case "blackjackhit":
      return doBlackjackHit(ctx);
    case "blackjackstand":
      return doBlackjackStand(ctx);
    case "slots":
      return doSlots(ctx, action.bet);
    case "roulette":
      return doRoulette(ctx, action.bet, action.choice, action.number);
    case "pokerjoin":
      return doPokerJoin(ctx, action.buyIn);
    case "pokerdeal":
      return doPokerDeal(ctx);
    case "pokerleave":
      return doPokerLeave(ctx);
    case "reset":
      return null;
    default:
      void s;
      return "Bad action";
  }
}

/** The rate limit is reported as this string; the route turns it into HTTP 429. */
export const TOO_FAST = "Too fast";

/**
 * Apply one action. Order: tick, the 200 ms rate limit, reset, the career picker, then the gates
 * (checkpoint, activity lock, custody, road) for everything outside ALWAYS_OK, then the action.
 * The inputs are never written to. On a rejection the ticked save is still returned (and should be
 * persisted) with `result.ok === false`.
 */
export function apply(state: PlayerState, shared: Shared, action: Action, now: number, rng: Rng, manpowerMult = 1): ApplyOutcome {
  const ticked = tick(state, shared, now);
  const ctx: Ctx = { s: ticked.state, sh: ticked.shared, now, rng, events: ticked.events, res: { ok: true } };
  const s = ctx.s;
  const reject = (error: string): ApplyOutcome => ({ state: ticked.state, shared: ticked.shared, events: ticked.events, result: { ok: false, error } });
  if (!cheats(s).noRateLimit && now - s.lastActionAt < ACTION_GAP_MS) return reject(TOO_FAST);
  if (action.type === "reset") {
    const next = newState(s.steamId, s.name, now);
    next.lastActionAt = now;
    const sh = cloneShared(ticked.shared);
    if (s.gangId && sh.gangs[s.gangId]) {
      const g = sh.gangs[s.gangId];
      g.members = g.members.filter((m) => m.steamId !== s.steamId);
      if (g.members.length === 0) delete sh.gangs[g.id];
      else if (g.leaderId === s.steamId) g.leaderId = [...g.members].sort((a, b) => a.joinedAt - b.joinedAt)[0].steamId;
    }
    sh.poker.seats = sh.poker.seats.filter((x) => x.steamId !== s.steamId);
    return { state: next, shared: sh, events: ticked.events, result: { ok: true } };
  }
  if (!s.faction && action.type !== "faction") return reject("Pick a career first.");
  if (!ALWAYS_OK.has(action.type)) {
    if (s.checkpoint) return reject("Answer the checkpoint first.");
    if (s.activityLockUntil > now) return reject(`Locked out. Try again in ${Math.ceil((s.activityLockUntil - now) / 1000)}s.`);
    if (s.custody) return reject("You are in custody.");
    if (s.travelTo) return reject("You are on the road.");
  }
  // Work on a private copy so a mid-handler rejection leaves only the tick behind.
  const work: Ctx = { ...ctx, s: clone(ctx.s), sh: cloneShared(ctx.sh), events: [...ctx.events] };
  const error = run(work, action, manpowerMult);
  if (error) return reject(error);
  work.s.lastActionAt = now;
  const result: ActionResult = work.fail ? { ok: false, error: work.fail } : work.res;
  return { state: work.s, shared: work.sh, events: work.events, result };
}

