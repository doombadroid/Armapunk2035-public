// Armapunk Pixel v3 civilian rules, one block per rule, on the reference ids and vocabulary
// (`work {siteId}`, `sell {itemId, amount}`) and the reference `result` shape. Time is a fixed `now`;
// randomness is a scripted queue that throws when the engine asks for more than the test planned.
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { BACKPACKS, CHESTS, CONST, CONTRACTS, CREW, GEAR, INFERRED, LICENSE, PRESTIGE, PROCESS_RATES, SITE, SKILL, TALENT, TOOLS, XP_CURVE } from "../content";
import {
  apply, bribeCost, capacityKg, carriedKg, contractRate, crewCost, crewRate, fineEstimate, levelFromXp, marketKey, marketMultAt, netWorth, newState,
  perClick, prestigeBlockers, prestigeFee, respecCost, seizable, siteBlock, staminaMax, staminaRegen, talentPoints, talentSpent, tick, travelMs,
  unitPrice, visibleAt, xpMultiplier,
} from "../engine";
import { snapshot } from "../view";
import type { Action, GangRecord } from "../types";
import { EMPTY_WORLD, MIN, NOW, QUIET, STEAM, atLevel, c, err, fresh, noRng, ok, rngOf, shared, withBag, withCareer, withCash, withPerks, withSkills, withTalents, xpAt } from "./helpers";

const SH = shared;

describe("newState", () => {
  it("is a v3 save with no career, in Kavala, full stamina, every clock set to now, both careers empty", () => {
    const s = newState(STEAM, "Tester", NOW);
    expect(s).toMatchObject({
      v: 3, steamId: STEAM, name: "Tester", createdAt: NOW, lastActionAt: 0, faction: null, cityId: "kavala", travelTo: null, travelUntil: 0,
      stamina: INFERRED.staminaBase, staminaAt: NOW, heat: 0, heatAt: NOW, papers: 0, processPapers: 0,
      chests: { common: 0, rare: 0, epic: 0, legendary: 0 }, careerSwitchReadyAt: 0, activityLockUntil: 0, custody: null, checkpoint: null,
      checkpointClicks: 0, duel: null, apdCase: null, apdCaseReadyAt: 0, gangId: null, blackjack: null, freePursuitRespec: true,
    });
    expect(s.careers.civ).toMatchObject({ cash: 0, xp: 0, licenses: [], skills: {}, talents: {}, respecs: 0, tools: { gather: 0, process: 0 }, gearTier: 0, packTier: 0, copGearTier: 0, inventory: {}, crews: {}, workers: [], prestige: 0, starPicks: 0, perks: {}, crewsAt: NOW, salaryAt: NOW });
    expect(s.careers.cop).toEqual(s.careers.civ);
    expect(s.stats).toEqual({ clicks: 0, gathered: 0, processed: 0, sold: 0, earned: 0, busts: 0, timesBusted: 0, timesFled: 0, timesResisted: 0, jackpots: 0, chestsFound: 0 });
  });

  it("before the picker only `faction` goes through; picking is permanent", () => {
    const s = fresh({}, null);
    expect(err(apply(s, SH(), { type: "work", siteId: "kav_apple" }, NOW + 1, noRng))).toBe("Pick a career first.");
    const r = ok(apply(s, SH(), { type: "faction", faction: "civ" }, NOW + 1, noRng));
    expect(r.state.faction).toBe("civ");
    expect(r.events).toEqual([{ kind: "join", text: "landed on the island as a civilian" }]);
    expect(err(apply(r.state, SH(), { type: "faction", faction: "cop" }, NOW + 500, noRng))).toBe("You already have a career.");
    expect(ok(apply(s, SH(), { type: "faction", faction: "cop" }, NOW + 1, noRng)).events[0].text).toBe("joined the APD");
  });
});

describe("rule 1: level and talent points", () => {
  it("levelFromXp reads XP_CURVE; xpNeeded is 1 at the cap as in the snapshot", () => {
    expect(levelFromXp(0)).toEqual({ level: 1, xpInto: 0, xpNeeded: 120 });
    expect(levelFromXp(119)).toEqual({ level: 1, xpInto: 119, xpNeeded: 120 });
    expect(levelFromXp(120)).toEqual({ level: 2, xpInto: 0, xpNeeded: 404 - 120 });
    expect(levelFromXp(XP_CURVE[99])).toEqual({ level: 100, xpInto: 0, xpNeeded: 1 });
    expect(levelFromXp(2_144_716)).toEqual({ level: 100, xpInto: 1_268_130, xpNeeded: 1 });
  });

  it("talentSpent sums costs[0..rank-1]; talentPoints is level - 1 - spent, never below 0", () => {
    expect(talentPoints(c(fresh()))).toBe(0);
    const s = withTalents(atLevel(fresh(), 10), { quickLearner: 3, mule: 1 });
    expect(talentSpent(c(s))).toBe(1 + 1 + 2 + 1);
    expect(talentPoints(c(s))).toBe(9 - 5);
    expect(talentPoints(c(withTalents(atLevel(fresh(), 2), { quickLearner: 5 })))).toBe(0);
    expect(TALENT.quickLearner.costs).toEqual([1, 1, 2, 2, 3]);
  });
});

describe("rule 2: xp", () => {
  it("multiplier is (1 + 0.08 quickLearner) * (1 + 0.08 starXp) * (1 + 0.01 gang level)", () => {
    expect(xpMultiplier(c(fresh()))).toBe(1);
    expect(xpMultiplier(c(withTalents(fresh(), { quickLearner: 5 })))).toBeCloseTo(1.4);
    expect(xpMultiplier(c(withPerks(fresh(), { starXp: 2 })))).toBeCloseTo(1.16);
    expect(xpMultiplier(c(fresh()), 10)).toBeCloseTo(1.1);
  });

  it("a work click grants round(clickXpPerStamina * site.stamina * mult) in the result: apple 6, or 8 with five Quick Learner", () => {
    const a = ok(apply(fresh(), SH(), { type: "work", siteId: "kav_apple" }, NOW + 1, rngOf(...QUIET)));
    expect(a.result).toEqual({ ok: true, gained: { apple: 12 }, xp: 6 });
    const s = withTalents(atLevel(fresh(), 20), { quickLearner: 5 });
    const b = ok(apply(s, SH(), { type: "work", siteId: "kav_apple" }, NOW + 1, rngOf(...QUIET)));
    expect(b.result.xp).toBe(Math.round(6 * 1.4));
  });

  it("a gang at level 10 adds 10 % yield and XP, and half of every XP gain feeds the gang", () => {
    const gang: GangRecord = { id: "cgang", name: "G", tag: "G", leaderId: STEAM, private: false, codeSeed: "x", codeBumps: 0, xp: 605_425, createdAt: NOW, members: [{ steamId: STEAM, joinedAt: NOW }] };
    const r = ok(apply(fresh({ gangId: "cgang" }), SH({ gangs: { cgang: gang } }), { type: "work", siteId: "kav_apple" }, NOW + 1, rngOf(...QUIET)));
    expect(r.result).toEqual({ ok: true, gained: { apple: 13 }, xp: 7 });
    expect(r.shared.gangs.cgang.xp).toBe(605_425 + 4);
  });
});

describe("rule 3: stamina", () => {
  it("staminaMax = 100 + 15 endurance + 10 starStamina (snapshot: 300 at 12 / 2)", () => {
    expect(staminaMax(c(fresh()))).toBe(100);
    expect(staminaMax(c(withPerks(withSkills(fresh(), { endurance: 12 }), { starStamina: 2 })))).toBe(300);
  });

  it("staminaRegen = (1.6 + 0.22 endurance) * (1 + 0.12 secondWind) per second (snapshot: 6.78 at 12 / 5)", () => {
    expect(staminaRegen(c(fresh()))).toBeCloseTo(1.6);
    expect(staminaRegen(c(withTalents(withSkills(fresh(), { endurance: 12 }), { secondWind: 5 })))).toBeCloseTo(6.78, 2);
  });
});

describe("rule 4: capacity", () => {
  it("capacityKg = round((gear + pack) * (1 + 0.08 strength) * (1 + 0.10 mule)) (snapshot: 10447)", () => {
    expect(capacityKg(fresh())).toBe(45);
    expect(capacityKg(withSkills(withCareer(fresh(), { gearTier: 5, packTier: 4 }), { strength: 12 }))).toBe(10447);
    expect(capacityKg(withTalents(fresh(), { mule: 5 }))).toBe(Math.round(45 * 1.5));
    expect(GEAR[5].capacity + BACKPACKS[4].capacity).toBe(5330);
  });

  it("carriedKg sums unit weights (snapshot: 3921)", () => {
    expect(carriedKg(c(withBag(fresh(), { uraniumu: 1255, uraniump: 78 })))).toBe(3921);
  });
});

describe("tick: stamina, heat, travel", () => {
  it("returns new objects and never mutates its input", () => {
    const s = withCareer(fresh({ stamina: 10, heat: 10 }), { crews: { kav_apple: 1 }, workers: [{ siteId: "kav_apple", kind: "gather", perMinute: 27.5, startedAt: NOW, until: NOW + 15 * MIN, lastTickAt: NOW, earned: 0 }] });
    const snap = structuredClone(s);
    const t = tick(s, SH(), NOW + 5 * MIN);
    expect(s).toEqual(snap);
    expect(t.state).not.toBe(s);
    expect(t.state.careers.civ.workers[0]).not.toBe(s.careers.civ.workers[0]);
  });

  it("regenerates stamina per second up to the max and moves staminaAt", () => {
    const t = tick(fresh({ stamina: 10 }), SH(), NOW + 10_000).state;
    expect(t.stamina).toBeCloseTo(26);
    expect(t.staminaAt).toBe(NOW + 10_000);
    expect(tick(fresh({ stamina: 99 }), SH(), NOW + 60_000).state.stamina).toBe(100);
  });

  it("cools heat at 2 * (1 + 0.05 stealth) per minute, fractional minutes included, floored at 0", () => {
    expect(tick(fresh({ heat: 10 }), SH(), NOW + 2.5 * MIN).state.heat).toBe(5);
    expect(tick(withSkills(fresh({ heat: 10 }), { stealth: 4 }), SH(), NOW + 2.5 * MIN).state.heat).toBe(4);
    expect(tick(fresh({ heat: 1 }), SH(), NOW + 60 * MIN).state.heat).toBe(0);
  });

  it("completes travel once now reaches travelUntil", () => {
    const s = fresh({ travelTo: "neochori", travelUntil: NOW + 7000 });
    expect(tick(s, SH(), NOW + 6999).state).toMatchObject({ cityId: "kavala", travelTo: "neochori" });
    expect(tick(s, SH(), NOW + 7000).state).toMatchObject({ cityId: "neochori", travelTo: null, travelUntil: 0 });
  });
});

describe("rule 11 (tick): crews", () => {
  it("settle per whole minute since crewsAt: floor(rate * n * minutes) units, clamped to the bag, remainder minute kept", () => {
    const t = tick(withCareer(fresh(), { crews: { kav_apple: 2 } }), SH(), NOW + 3.5 * MIN).state;
    expect(t.careers.civ.inventory).toEqual({ apple: 45 });
    expect(t.careers.civ.crewsAt).toBe(NOW + 3 * MIN);
    expect(t.stats.gathered).toBe(45);
    expect(tick(withCareer(fresh(), { crews: { kav_apple: 1 } }), SH(), NOW + MIN).state.careers.civ.inventory).toEqual({ apple: 11 });
  });

  it("crewRate is perMinute * (1 + 0.15 logistics); crew XP is a third of the hand rate per unit", () => {
    expect(crewRate(c(fresh()), "kav_apple")).toBe(11);
    expect(crewRate(c(withTalents(fresh(), { logistics: 2 })), "kav_apple")).toBeCloseTo(14.3);
    const t = tick(withCareer(fresh(), { crews: { kav_apple: 2 } }), SH(), NOW + 3 * MIN).state;
    expect(t.careers.civ.xp).toBe(Math.round((1 / 3) * ((2 * 3) / 12) * 45));
  });

  it("a paused crew makes nothing; an illegal crew adds heat through the reductions; crews sleep on APD duty", () => {
    const t = tick(withCareer(fresh(), { crews: { kav_apple: 2, kav_weed: 1 }, pausedCrews: ["kav_apple", "kav_weed"] }), SH(), NOW + 5 * MIN).state;
    expect(t.careers.civ.inventory).toEqual({});
    expect(t.heat).toBe(0);
    expect(tick(withCareer(fresh(), { crews: { kav_weed: 1 } }), SH(), NOW + 2 * MIN).state.heat).toBe(1);
    expect(tick(withCareer(fresh({ heat: 10 }), { crews: { kav_weed: 1 } }), SH(), NOW + 2 * MIN).state.heat).toBe(7);
    const cop = fresh({}, "cop");
    cop.careers.civ.crews = { kav_apple: 2 };
    const asCop = tick(cop, SH(), NOW + 3 * MIN).state;
    expect(asCop.careers.civ.inventory).toEqual({});
    expect(asCop.careers.civ.crewsAt).toBe(NOW + 3 * MIN);
  });
});

describe("rule 12 (tick): contractors", () => {
  const worker = (over = {}) => ({ siteId: "kav_apple", kind: "gather" as const, perMinute: 27.5, startedAt: NOW, until: NOW + 15 * MIN, lastTickAt: NOW, earned: 0, ...over });

  it("settles floor(perMinute * wholeMinutes) into the bag while it fits; stops at until and is removed", () => {
    const t = tick(withCareer(fresh(), { workers: [worker()] }), SH(), NOW + 2.5 * MIN).state;
    expect(t.careers.civ.inventory).toEqual({ apple: 45 });
    expect(t.careers.civ.workers[0].lastTickAt).toBe(NOW + 2 * MIN);
    const done = tick(withCareer(fresh(), { workers: [worker()], gearTier: 5 }), SH(), NOW + 20 * MIN).state;
    expect(done.careers.civ.inventory).toEqual({ apple: Math.floor(27.5 * 15) });
    expect(done.careers.civ.workers).toEqual([]);
  });

  it("with workerAutoSell the output is sold at the site's city resting price and earned grows", () => {
    const t = tick(withCareer(fresh(), { workers: [worker()], workerAutoSell: true }), SH(), NOW + 2 * MIN).state;
    expect(t.careers.civ.inventory).toEqual({});
    expect(t.careers.civ.cash).toBe(55 * 8);
    expect(t.careers.civ.workers[0].earned).toBe(440);
    expect(t.stats.sold).toBe(55);
  });

  it("a processing contract consumes inputPer per unit from the bag and makes only what the inputs allow", () => {
    const w = worker({ siteId: "kav_gin", kind: "process", perMinute: PROCESS_RATES.kav_gin * CONTRACTS.workerRateMult });
    expect(w.perMinute).toBe(7.5);
    expect(tick(withCareer(fresh(), { workers: [w], inventory: { cottonR: 10 } }), SH(), NOW + 2 * MIN).state.careers.civ.inventory).toEqual({ cotton: 10 });
    expect(tick(withCareer(fresh(), { workers: [w], inventory: { cottonR: 40 } }), SH(), NOW + 2 * MIN).state.careers.civ.inventory).toEqual({ cottonR: 25, cotton: 15 });
  });
});

describe("apply: purity, tick first, rate limit, gates", () => {
  it("never mutates the input state or shared rows and returns new objects", () => {
    const s = withBag(fresh(), { apple: 3 });
    const sh = SH({ market: { "kavala:apple": { mult: 0.9, at: NOW } } });
    const snapS = structuredClone(s);
    const snapSh = structuredClone(sh);
    const r = ok(apply(s, sh, { type: "sell", itemId: "apple", amount: 3 }, NOW + 1000, noRng));
    expect(s).toEqual(snapS);
    expect(sh).toEqual(snapSh);
    expect(r.state).not.toBe(s);
    expect(r.shared.market["kavala:apple"]).not.toBe(sh.market["kavala:apple"]);
  });

  it("ticks first and stamps lastActionAt on success only", () => {
    const r = ok(apply(fresh({ stamina: 1 }), SH(), { type: "work", siteId: "kav_apple" }, NOW + 10_000, rngOf(...QUIET)));
    expect(r.state.stamina).toBeCloseTo(1 + 16 - 3);
    expect(r.state.lastActionAt).toBe(NOW + 10_000);
    const bad = apply(fresh(), SH(), { type: "travel", cityId: "kavala" }, NOW + 1, noRng);
    expect(bad.result).toEqual({ ok: false, error: "You are already there." });
    expect(bad.state.lastActionAt).toBe(0);
  });

  it("rejects an action under 200 ms after the previous one with `Too fast`, before every other check", () => {
    const s = fresh({ lastActionAt: NOW, travelTo: "neochori", travelUntil: NOW + 7000 });
    expect(err(apply(s, SH(), { type: "work", siteId: "kav_apple" }, NOW + 199, noRng))).toBe("Too fast");
    expect(err(apply(s, SH(), { type: "work", siteId: "kav_apple" }, NOW + 200, noRng))).toBe("You are on the road.");
  });

  it("on a rejection the ticked save comes back (crews settled, level-ups reported)", () => {
    const s = withCareer(fresh(), { crews: { kav_apple: 10 }, xp: 118, gearTier: 5 });
    const r = apply(s, SH(), { type: "travel", cityId: "kavala" }, NOW + 3 * MIN, noRng);
    expect(r.result.ok).toBe(false);
    expect(r.state.careers.civ.inventory.apple).toBe(330);
    expect(r.events).toContainEqual({ kind: "level", text: "reached level 2" });
  });

  it("rejects an unknown action type", () => {
    expect(err(apply(fresh(), SH(), { type: "dance" } as unknown as Action, NOW + 1, noRng))).toBe("Bad action");
  });
});

describe("rule 5: travel", () => {
  it("travelMs is travel[from][to] * vehicle speed * 1000, 0 for the current city", () => {
    expect(travelMs(fresh(), "neochori")).toBe(7000);
    expect(travelMs(fresh(), "sofia")).toBe(22_000);
    expect(travelMs(withCareer(fresh(), { gearTier: 2 }), "neochori")).toBe(5250);
    expect(travelMs(fresh(), "kavala")).toBe(0);
  });

  it("sets travelTo and travelUntil with a message; rejects the current city", () => {
    const r = ok(apply(fresh(), SH(), { type: "travel", cityId: "neochori" }, NOW + 1, noRng));
    expect(r.state).toMatchObject({ travelTo: "neochori", travelUntil: NOW + 1 + 7000, cityId: "kavala" });
    expect(r.result).toEqual({ ok: true, message: "On the road to Neochori." });
    expect(err(apply(fresh(), SH(), { type: "travel", cityId: "kavala" }, NOW + 1, noRng))).toBe("You are already there.");
  });

  it("on the road every action waits except chat, verify, hp, release and the custody / pursuit ones", () => {
    const road = atLevel(withCash(withBag(fresh({ travelTo: "neochori", travelUntil: NOW + 7000, papers: 10, heat: 5 }), { apple: 5, marijuana: 2 }), 1_000_000), 20);
    const blocked: Action[] = [
      { type: "work", siteId: "kav_apple" }, { type: "sell", itemId: "apple", amount: 1 }, { type: "drop", itemId: "apple", amount: 1 }, { type: "ditch" },
      { type: "license", licenseId: "farming" }, { type: "skill", skillId: "endurance" }, { type: "tool", kind: "gather" }, { type: "gear" }, { type: "pack" },
      { type: "craftcontract", qty: 1 }, { type: "autosell" }, { type: "payheat" }, { type: "talent", talentId: "quickLearner" }, { type: "travel", cityId: "athira" },
      { type: "gangcreate", name: "Gang", tag: "GG" }, { type: "slots", bet: 1 }, { type: "switch", faction: "cop" }, { type: "prestige" },
    ];
    for (const a of blocked) expect(err(apply(road, SH(), a, NOW + 1, noRng)), a.type).toBe("You are on the road.");
    expect(apply(road, SH(), { type: "chat", text: "gg" }, NOW + 1, noRng).result.ok).toBe(true);
    expect(err(apply(road, SH(), { type: "release" }, NOW + 1, noRng))).toBe("You are not in custody.");
  });

  it("arrival is applied by the tick before the action runs", () => {
    const road = atLevel(fresh({ travelTo: "neochori", travelUntil: NOW + 7000 }), 2);
    const r = ok(apply(road, SH(), { type: "work", siteId: "neo_timber" }, NOW + 7000, rngOf(...QUIET)));
    expect(r.state.cityId).toBe("neochori");
    expect(r.result.gained).toEqual({ timber: 4 });
  });
});

describe("rule 6: site gate, in order, with the client's button labels", () => {
  it("unknown site, city, level, licence, stamina, then room or input", () => {
    expect(err(apply(fresh(), SH(), { type: "work", siteId: "nope" }, NOW + 1, noRng))).toBe("Unknown site.");
    expect(siteBlock(fresh({ cityId: "neochori" }), SITE.kav_cotton)).toBe("That site is not in this city.");
    expect(siteBlock(fresh(), SITE.kav_cotton)).toBe("Level 2");
    expect(siteBlock(atLevel(fresh(), 2), SITE.kav_cotton)).toBe("Farming License");
    expect(siteBlock(atLevel(withCareer(fresh({ stamina: 4 }), { licenses: ["farming"] }), 2), SITE.kav_cotton)).toBe("Too tired");
    expect(siteBlock(atLevel(withCareer(fresh(), { licenses: ["farming"], inventory: { apple: 45 } }), 2), SITE.kav_cotton)).toBe("Pack full");
    expect(siteBlock(atLevel(withCareer(fresh(), { licenses: ["farming"] }), 2), SITE.kav_cotton)).toBeNull();
    expect(siteBlock(atLevel(fresh(), 2), SITE.kav_gin)).toBe("Need Raw Cotton");
    expect(siteBlock(atLevel(withBag(fresh(), { cottonR: 1 }), 2), SITE.kav_gin)).toBeNull();
    expect(err(apply(withBag(fresh(), { apple: 45 }), SH(), { type: "work", siteId: "kav_apple" }, NOW + 1, noRng))).toBe("Pack full");
  });
});

describe("rule 7: work", () => {
  it("perClick = max(1, floor(yield * tool * (1 + 0.12 skill) * (1 + 0.06 starYield)))", () => {
    expect(perClick(fresh(), SITE.kav_apple)).toBe(12);
    expect(perClick(withCareer(fresh(), { tools: { gather: 1, process: 0 } }), SITE.kav_apple)).toBe(14);
    expect(perClick(withSkills(withCareer(fresh(), { tools: { gather: 1, process: 0 } }), { harvesting: 5 }), SITE.kav_apple)).toBe(22);
    expect(perClick(withPerks(withSkills(withCareer(fresh(), { tools: { gather: 1, process: 0 } }), { harvesting: 5 }), { starYield: 5 }), SITE.kav_apple)).toBe(29);
    expect(perClick(withCareer(fresh(), { tools: { gather: 6, process: 0 } }), SITE.pyr_turtle)).toBe(3);
    expect(perClick(withSkills(withCareer(fresh(), { tools: { gather: 0, process: 2 } }), { refining: 3 }), SITE.kav_gin)).toBe(Math.floor(3 * 1.42 * 1.36));
    expect(TOOLS.find((t) => t.kind === "gather" && t.tier === 1)?.mult).toBe(1.18);
  });

  it("gather: units into the bag, stamina down, xp, stats, result { gained, xp }", () => {
    const r = ok(apply(fresh(), SH(), { type: "work", siteId: "kav_apple" }, NOW + 1, rngOf(...QUIET)));
    expect(r.state.careers.civ.inventory).toEqual({ apple: 12 });
    expect(r.state.stamina).toBeCloseTo(97);
    expect(r.state.stats).toMatchObject({ clicks: 1, gathered: 12 });
    expect(r.result).toEqual({ ok: true, gained: { apple: 12 }, xp: 6 });
    expect(r.events).toEqual([]);
    expect(ok(apply(withBag(fresh(), { apple: 40 }), SH(), { type: "work", siteId: "kav_apple" }, NOW + 1, rngOf(...QUIET))).result.gained).toEqual({ apple: 5 });
  });

  it("bumper crop: the first roll under 0.08 * rank doubles a gather", () => {
    const s = withTalents(atLevel(fresh(), 10), { bumperCrop: 5 });
    expect(ok(apply(s, SH(), { type: "work", siteId: "kav_apple" }, NOW + 1, rngOf(0.39, 1, 1, 1))).result.gained).toEqual({ apple: 24 });
    expect(ok(apply(s, SH(), { type: "work", siteId: "kav_apple" }, NOW + 1, rngOf(0.4, 1, 1, 1))).result.gained).toEqual({ apple: 12 });
  });

  it("process: consumes inputPer * yield, produces perClick; less than a batch scales down; refining boosts output only", () => {
    const r = ok(apply(atLevel(withBag(fresh(), { cottonR: 10 }), 2), SH(), { type: "work", siteId: "kav_gin" }, NOW + 1, rngOf(...QUIET)));
    expect(r.state.careers.civ.inventory).toEqual({ cottonR: 7, cotton: 3 });
    expect(r.result).toEqual({ ok: true, gained: { cotton: 3 }, xp: 8 });
    expect(r.state.stats).toMatchObject({ processed: 3, gathered: 0 });
    expect(ok(apply(atLevel(withBag(fresh(), { sand: 10 }), 2), SH(), { type: "work", siteId: "kav_glass" }, NOW + 1, rngOf(...QUIET))).state.careers.civ.inventory).toEqual({ sand: 6, glass: 2 });
    expect(ok(apply(atLevel(withBag(fresh(), { cottonR: 2 }), 2), SH(), { type: "work", siteId: "kav_gin" }, NOW + 1, rngOf(...QUIET))).state.careers.civ.inventory).toEqual({ cotton: 2 });
    const boosted = withSkills(atLevel(withBag(fresh(), { cottonR: 10 }), 2), { refining: 12 });
    expect(ok(apply(boosted, SH(), { type: "work", siteId: "kav_gin" }, NOW + 1, rngOf(...QUIET))).state.careers.civ.inventory).toEqual({ cottonR: 7, cotton: 7 });
  });

  it("efficiency: the first roll under 0.07 * rank skips the input", () => {
    const s = withTalents(atLevel(withBag(fresh(), { cottonR: 10 }), 10), { efficiency: 5 });
    expect(ok(apply(s, SH(), { type: "work", siteId: "kav_gin" }, NOW + 1, rngOf(0.34, 1, 1, 1))).state.careers.civ.inventory).toEqual({ cottonR: 10, cotton: 3 });
    expect(ok(apply(s, SH(), { type: "work", siteId: "kav_gin" }, NOW + 1, rngOf(0.35, 1, 1, 1))).state.careers.civ.inventory).toEqual({ cottonR: 7, cotton: 3 });
  });

  it("jackpot: the second roll under chance * (1 + 0.30 prospector) adds the prize to gained with jackpot: true and a feed line", () => {
    const s = atLevel(withCareer(fresh(), { licenses: ["diving"] }), 4);
    const hit = ok(apply(s, SH(), { type: "work", siteId: "kav_oyster" }, NOW + 1, rngOf(1, 0.079, 1, 1)));
    expect(hit.result).toEqual({ ok: true, gained: { oysteru: 3, pearl: 1 }, xp: 10, jackpot: true });
    expect(hit.state.stats.jackpots).toBe(1);
    expect(hit.events).toEqual([{ kind: "jackpot", text: "struck Pearl at Oyster Beds" }]);
    expect(ok(apply(s, SH(), { type: "work", siteId: "kav_oyster" }, NOW + 1, rngOf(1, 0.08, 1, 1))).result.gained).toEqual({ oysteru: 3 });
    const p = withTalents(atLevel(withCareer(fresh(), { licenses: ["diving"] }), 10), { prospector: 5 });
    expect(ok(apply(p, SH(), { type: "work", siteId: "kav_oyster" }, NOW + 1, rngOf(1, 0.19, 1, 1))).result.gained).toEqual({ oysteru: 3, pearl: 1 });
  });

  it("every click consumes bumper, jackpot, chest and paper rolls in that order, plus the rarity roll on a chest hit", () => {
    expect(() => apply(fresh(), SH(), { type: "work", siteId: "kav_apple" }, NOW + 1, rngOf(1, 1, 1))).toThrow("rng exhausted");
    expect(() => apply(fresh(), SH(), { type: "work", siteId: "kav_apple" }, NOW + 1, rngOf(1, 1, 0, 1))).toThrow("rng exhausted");
    expect(apply(fresh(), SH(), { type: "work", siteId: "kav_apple" }, NOW + 1, rngOf(1, 1, 0, 0.5, 1)).result.ok).toBe(true);
  });

  it("chest: the third roll under chestChancePerClick finds one; rarity walks the weights; epic and up hit the feed", () => {
    const common = ok(apply(fresh(), SH(), { type: "work", siteId: "kav_apple" }, NOW + 1, rngOf(1, 1, 0.019, 0.5, 1)));
    expect(common.state.chests).toEqual({ common: 1, rare: 0, epic: 0, legendary: 0 });
    expect(common.result.chest).toBe("common");
    expect(common.events).toEqual([]);
    expect(ok(apply(fresh(), SH(), { type: "work", siteId: "kav_apple" }, NOW + 1, rngOf(1, 1, 0, 0.74, 1))).state.chests.rare).toBe(1);
    const epic = ok(apply(fresh(), SH(), { type: "work", siteId: "kav_apple" }, NOW + 1, rngOf(1, 1, 0, 0.93, 1)));
    expect(epic.state.chests.epic).toBe(1);
    expect(epic.events).toEqual([{ kind: "jackpot", text: "unearthed a Smuggler's Cache at Apple Orchard" }]);
    expect(ok(apply(fresh(), SH(), { type: "work", siteId: "kav_apple" }, NOW + 1, rngOf(1, 1, 0, 0.99, 1))).state.chests.legendary).toBe(1);
    expect(CHESTS.reduce((t, ch) => t + ch.weight, 0)).toBe(100);
  });

  it("paper: the last roll under paperDropChance finds a contract paper", () => {
    const r = ok(apply(fresh(), SH(), { type: "work", siteId: "kav_apple" }, NOW + 1, rngOf(1, 1, 1, 0.014)));
    expect(r.state.papers).toBe(1);
    expect(r.result.papers).toBe(1);
    expect(ok(apply(fresh(), SH(), { type: "work", siteId: "kav_apple" }, NOW + 1, rngOf(1, 1, 1, 0.015))).state.papers).toBe(0);
  });

  it("an illegal site adds heatGather or heatProcess scaled by stealth, ghost and starGhost; the result carries the gain", () => {
    const s = atLevel(fresh(), 2);
    const weed = ok(apply(s, SH(), { type: "work", siteId: "kav_weed" }, NOW + 1, rngOf(...QUIET)));
    expect(weed.state.heat).toBe(2);
    expect(weed.result.heat).toBe(2);
    expect(ok(apply(withBag(s, { cannabis: 5 }), SH(), { type: "work", siteId: "kav_weedp" }, NOW + 1, rngOf(...QUIET))).state.heat).toBe(3);
    const sneaky = withPerks(withTalents(withSkills(atLevel(fresh(), 20), { stealth: 12 }), { ghost: 5 }), { starGhost: 5 });
    expect(ok(apply(sneaky, SH(), { type: "work", siteId: "kav_weed" }, NOW + 1, rngOf(...QUIET))).state.heat).toBe(0.11);
    expect(ok(apply(fresh(), SH(), { type: "work", siteId: "kav_apple" }, NOW + 1, rngOf(...QUIET))).result.heat).toBeUndefined();
  });

  it("levelling up: 20 apple clicks reach level 2, the feed says so and the result carries the talent point", () => {
    let s = fresh();
    let feed = 0;
    let points = 0;
    for (let i = 0; i < 20; i++) {
      const r = ok(apply(withBag({ ...s, lastActionAt: 0 }, {}), SH(), { type: "work", siteId: "kav_apple" }, NOW + 1, rngOf(...QUIET)));
      feed += r.events.filter((e) => e.kind === "level").length;
      points += r.result.talentPoints ?? 0;
      s = r.state;
    }
    expect(levelFromXp(s.careers.civ.xp).level).toBe(2);
    expect(feed).toBe(1);
    expect(points).toBe(1);
  });

  it("auto-sell (on, level >= 6, priced output): the haul is sold at the local price, never enters the bag, moves the market", () => {
    const s = atLevel(withCareer(fresh(), { autoSell: true }), 6);
    const r = ok(apply(s, SH(), { type: "work", siteId: "kav_apple" }, NOW + 1, rngOf(...QUIET)));
    expect(r.state.careers.civ.inventory).toEqual({});
    expect(r.result).toEqual({ ok: true, gained: { apple: 12 }, cash: 96, xp: 6 });
    expect(r.shared.market["kavala:apple"].mult).toBeCloseTo(1.18 * (1 - 0.02 * Math.log(13)));
    expect(ok(apply(withBag(s, { apple: 45 }), SH(), { type: "work", siteId: "kav_apple" }, NOW + 1, rngOf(...QUIET))).result.cash).toBe(96);
    const j = ok(apply(atLevel(withCareer(fresh(), { autoSell: true, licenses: ["diving"] }), 6), SH(), { type: "work", siteId: "kav_oyster" }, NOW + 1, rngOf(1, 0, 1, 1)));
    expect(j.state.careers.civ.inventory).toEqual({ pearl: 1 });
    const raw = atLevel(withCareer(fresh(), { autoSell: true, licenses: ["mining"] }), 6);
    expect(ok(apply(raw, SH(), { type: "work", siteId: "kav_quarry" }, NOW + 1, rngOf(...QUIET))).state.careers.civ.inventory).toEqual({ sand: 4 });
  });
});

describe("rule 8: heat, wanted, bribe, ditch", () => {
  it("visibleAt is wantedAt + 3 per Low Profile; wanted when heat reaches it", () => {
    expect(visibleAt(c(fresh()))).toBe(22);
    expect(visibleAt(c(withTalents(fresh(), { lowProfile: 5 })))).toBe(37);
    expect(snapshot(fresh({ heat: 21.99 }), SH(), EMPTY_WORLD, NOW, false).me.wanted).toBe(false);
    expect(snapshot(fresh({ heat: 22 }), SH(), EMPTY_WORLD, NOW, false).me.wanted).toBe(true);
  });

  it("seizable is illegal units at base price; fineEstimate is fineBase + finePerLevel * level (snapshot 17,385 at 100)", () => {
    expect(seizable(c(withBag(fresh(), { marijuana: 20, apple: 5 })))).toBe(20 * 380);
    expect(fineEstimate(c(fresh()))).toBe(2385 + 150);
    expect(fineEstimate(c(atLevel(fresh(), 100)))).toBe(17_385);
  });

  it("bribeCost = 1000 * heat + 0.35204 * seizable; payheat charges it, zeroes the heat, keeps the bag", () => {
    expect(bribeCost(withBag(fresh({ heat: 10 }), { marijuana: 20 }))).toBe(Math.round(10_000 + 0.35204 * 7600));
    const s = withCash(withBag(fresh({ heat: 10 }), { marijuana: 20 }), 20_000);
    const r = ok(apply(s, SH(), { type: "payheat" }, NOW + 1, noRng));
    expect(r.state.heat).toBe(0);
    expect(r.state.careers.civ.cash).toBe(20_000 - 12_676);
    expect(r.state.careers.civ.inventory).toEqual({ marijuana: 20 });
    expect(r.result).toEqual({ ok: true, cash: -12_676, message: "Record cleared." });
    expect(err(apply(withBag(fresh(), { marijuana: 20 }), SH(), { type: "payheat" }, NOW + 1, noRng))).toBe("Your record is clean.");
    expect(err(apply(withCash(s, 100), SH(), { type: "payheat" }, NOW + 1, noRng))).toBe("You are $12,576 short.");
  });

  it("ditch drops every illegal item, keeps legal ones and halves heat; nothing illegal is rejected", () => {
    const r = ok(apply(withBag(fresh({ heat: 15.5 }), { marijuana: 20, cannabis: 3, apple: 5 }), SH(), { type: "ditch" }, NOW + 1, noRng));
    expect(r.state.careers.civ.inventory).toEqual({ apple: 5 });
    expect(r.state.heat).toBe(7.75);
    expect(r.result).toEqual({ ok: true, message: "Ditched 23 units of contraband." });
    expect(err(apply(withBag(fresh({ heat: 5 }), { apple: 5 }), SH(), { type: "ditch" }, NOW + 1, noRng))).toBe("Nothing to ditch.");
  });
});

describe("rule 9: market and selling", () => {
  it("marketMultAt rests at 1.18 and recovers 0.004 per minute", () => {
    expect(marketKey("athira", "glass")).toBe("athira:glass");
    expect(marketMultAt(undefined, NOW)).toBe(1.18);
    expect(marketMultAt({ mult: 0.98, at: NOW }, NOW + 10 * MIN)).toBeCloseTo(1.02);
    expect(marketMultAt({ mult: 0.98, at: NOW }, NOW + 50 * MIN)).toBe(1.18);
  });

  it("unitPrice reproduces the snapshot: apple 11 and meth 8762 at haggling 12 / fence 5 in Kavala; demand and stars apply", () => {
    expect(unitPrice("apple", "kavala", {}, c(fresh()), NOW)).toBe(8);
    expect(unitPrice("apple", "kavala", {}, c(withSkills(fresh(), { haggling: 12 })), NOW)).toBe(11);
    expect(unitPrice("meth", "kavala", {}, c(withTalents(withSkills(fresh(), { haggling: 12 }), { fence: 5 })), NOW)).toBe(8762);
    expect(unitPrice("apple", "sofia", {}, c(fresh()), NOW)).toBe(Math.round(7 * 1.18 * 1.12));
    expect(unitPrice("apple", "kavala", { "kavala:apple": { mult: 0.9, at: NOW } }, c(fresh()), NOW)).toBe(Math.round(7 * 0.9));
    expect(unitPrice("marijuana", "kavala", {}, c(withPerks(fresh(), { starHaggle: 5 })), NOW)).toBe(Math.round(380 * 1.18 * 1.2));
    expect(unitPrice("sand", "kavala", {}, c(fresh()), NOW)).toBe(0);
  });

  it("sell {itemId, amount}: pays unitPrice * n, drops the multiplier, result { cash, xp }", () => {
    const r = ok(apply(withBag(fresh(), { apple: 40 }), SH(), { type: "sell", itemId: "apple", amount: 36 }, NOW + 1, noRng));
    expect(r.state.careers.civ.inventory).toEqual({ apple: 4 });
    expect(r.state.careers.civ.cash).toBe(288);
    expect(r.state.stats).toMatchObject({ sold: 36, earned: 288 });
    expect(r.result).toEqual({ ok: true, cash: 288, xp: 1 });
    expect(r.shared.market["kavala:apple"]).toEqual({ mult: 1.18 * (1 - 0.02 * Math.log(37)), at: NOW + 1 });
    expect(r.events).toEqual([]);
  });

  it("sell all, clamping, and the rejections", () => {
    expect(ok(apply(withBag(fresh(), { apple: 40 }), SH(), { type: "sell", itemId: "apple", amount: "all" }, NOW + 1, noRng)).state.careers.civ.inventory).toEqual({});
    expect(ok(apply(withBag(fresh(), { apple: 40 }), SH(), { type: "sell", itemId: "apple", amount: 99 }, NOW + 1, noRng)).state.careers.civ.cash).toBe(320);
    expect(err(apply(fresh(), SH(), { type: "sell", itemId: "apple", amount: 1 }, NOW + 1, noRng))).toBe("You do not have that.");
    expect(err(apply(withBag(fresh(), { sand: 5 }), SH(), { type: "sell", itemId: "sand", amount: 1 }, NOW + 1, noRng))).toBe("Nobody buys that raw.");
    expect(err(apply(fresh(), SH(), { type: "sell", itemId: "unobtainium", amount: 1 }, NOW + 1, noRng))).toBe("Unknown item.");
  });

  it("a big sale hits the feed as `moved Nx Item for $X` and can cross several levels", () => {
    const r = ok(apply(withBag(fresh(), { diamondc: 100 }), SH(), { type: "sell", itemId: "diamondc", amount: "all" }, NOW + 1, noRng));
    expect(r.events[0]).toEqual({ kind: "sale", text: "moved 100x Diamond (Cut) for $253,700" });
    const lv = levelFromXp(r.state.careers.civ.xp).level;
    expect(lv).toBeGreaterThan(2);
    expect(r.events.filter((e) => e.kind === "level").map((e) => e.text)).toEqual(Array.from({ length: lv - 1 }, (_, i) => `reached level ${i + 2}`));
    expect(r.result.talentPoints).toBe(lv - 1);
  });

  it("the drop per sale never exceeds marketDropMin and the multiplier never falls below marketFloor", () => {
    const big = ok(apply(withBag(fresh(), { apple: 30_000 }), SH(), { type: "sell", itemId: "apple", amount: "all" }, NOW + 1, noRng));
    expect(big.shared.market["kavala:apple"].mult).toBeCloseTo(1.18 * 0.8);
    const low = ok(apply(withBag(fresh(), { apple: 30_000 }), SH({ market: { "kavala:apple": { mult: 0.45, at: NOW } } }), { type: "sell", itemId: "apple", amount: "all" }, NOW + 1, noRng));
    expect(low.shared.market["kavala:apple"].mult).toBe(INFERRED.marketFloor);
  });

  it("illegal sales add max(1, units / 10) heat through the reductions and report it", () => {
    const r = ok(apply(withBag(fresh(), { marijuana: 20 }), SH(), { type: "sell", itemId: "marijuana", amount: 20 }, NOW + 1, noRng));
    expect(r.state.heat).toBe(2);
    expect(r.result.heat).toBe(2);
    expect(ok(apply(withBag(fresh(), { marijuana: 5 }), SH(), { type: "sell", itemId: "marijuana", amount: 5 }, NOW + 1, noRng)).state.heat).toBe(1);
    expect(ok(apply(withSkills(withBag(fresh(), { marijuana: 20 }), { stealth: 10 }), SH(), { type: "sell", itemId: "marijuana", amount: 20 }, NOW + 1, noRng)).state.heat).toBe(0.6);
  });

  it("netWorth is cash plus the bag at base prices; drop discards for nothing", () => {
    expect(netWorth(c(withCash(withBag(fresh(), { apple: 10, sand: 5 }), 100)))).toBe(170);
    const r = ok(apply(withBag(fresh(), { apple: 5 }), SH(), { type: "drop", itemId: "apple", amount: 3 }, NOW + 1, noRng));
    expect(r.state.careers.civ.inventory).toEqual({ apple: 2 });
    expect(r.result).toEqual({ ok: true, message: "Dropped 3 Apple." });
    expect(ok(apply(withBag(fresh(), { apple: 5 }), SH(), { type: "drop", itemId: "apple", amount: "all" }, NOW + 1, noRng)).state.careers.civ.inventory).toEqual({});
    expect(err(apply(fresh(), SH(), { type: "drop", itemId: "apple", amount: 1 }, NOW + 1, noRng))).toBe("You do not have that.");
  });
});

describe("rule 10: licences, skills, talents, respec, tiers, star perks", () => {
  it("license {licenseId}: once, for the career, for cash, with purchase XP; result { cash, xp }", () => {
    const r = ok(apply(withCash(fresh(), 5000), SH(), { type: "license", licenseId: "farming" }, NOW + 1, noRng));
    expect(r.state.careers.civ.licenses).toEqual(["farming"]);
    expect(r.state.careers.civ.cash).toBe(1000);
    expect(r.result).toEqual({ ok: true, cash: -4000, xp: 4 });
    expect(err(apply(r.state, SH(), { type: "license", licenseId: "farming" }, NOW + 500, noRng))).toBe("Already held.");
    expect(err(apply(withCash(fresh(), 3999), SH(), { type: "license", licenseId: "farming" }, NOW + 1, noRng))).toBe("Not enough cash.");
    expect(err(apply(withCash(fresh(), 1e9), SH(), { type: "license", licenseId: "firearms" }, NOW + 1, noRng))).toBe("That licence is not for your career.");
    expect(LICENSE.farming.cost).toBe(4000);
  });

  it("skill {skillId}: rank r costs costs[r-1], max 12, civ and shared skills only", () => {
    const r = ok(apply(withCash(fresh(), 2000), SH(), { type: "skill", skillId: "endurance" }, NOW + 1, noRng));
    expect(r.state.careers.civ.skills.endurance).toBe(1);
    expect(r.result).toEqual({ ok: true, cash: -1400, xp: 1 });
    expect(err(apply(r.state, SH(), { type: "skill", skillId: "endurance" }, NOW + 500, noRng))).toBe("Not enough cash.");
    expect(err(apply(withSkills(withCash(fresh(), 1e9), { endurance: 12 }), SH(), { type: "skill", skillId: "endurance" }, NOW + 1, noRng))).toBe("Already maxed.");
    expect(err(apply(withCash(fresh(), 1e9), SH(), { type: "skill", skillId: "pursuit" }, NOW + 1, noRng))).toBe("That skill is not for your career.");
    expect(SKILL.endurance.costs[1]).toBe(5797);
  });

  it("talent {talentId}: level and points; the feed says `trained X N`", () => {
    const r = ok(apply(atLevel(fresh(), 2), SH(), { type: "talent", talentId: "quickLearner" }, NOW + 1, noRng));
    expect(r.state.careers.civ.talents).toEqual({ quickLearner: 1 });
    expect(r.events).toEqual([{ kind: "level", text: "trained Quick Learner 1" }]);
    expect(r.result).toEqual({ ok: true, message: "Learned Quick Learner 1." });
    expect(err(apply(r.state, SH(), { type: "talent", talentId: "quickLearner" }, NOW + 500, noRng))).toBe("Not enough talent points.");
    expect(err(apply(fresh(), SH(), { type: "talent", talentId: "quickLearner" }, NOW + 1, noRng))).toBe("Needs level 2.");
    expect(err(apply(withTalents(atLevel(fresh(), 50), { quickLearner: 5 }), SH(), { type: "talent", talentId: "quickLearner" }, NOW + 1, noRng))).toBe("Already maxed.");
    expect(err(apply(atLevel(fresh(), 50), SH(), { type: "talent", talentId: "warrant" }, NOW + 1, noRng))).toBe("That talent is not for your career.");
  });

  it("respec: (17,000 + 2,000 * spent) * (1 + 0.5 * respecs), charged first, refunds every point", () => {
    const s = withTalents(atLevel(withCash(fresh(), 21_000), 10), { quickLearner: 2 });
    expect(respecCost(c(s))).toBe(21_000);
    const r = ok(apply(s, SH(), { type: "respec" }, NOW + 1, noRng));
    expect(r.state.careers.civ.talents).toEqual({});
    expect(r.state.careers.civ.respecs).toBe(1);
    expect(r.state.careers.civ.cash).toBe(0);
    expect(talentPoints(c(r.state))).toBe(9);
    expect(respecCost(c(withTalents(r.state, { quickLearner: 3, mule: 1 })))).toBe(Math.round((17_000 + 2_000 * 5) * 1.5));
    expect(err(apply(withCash(s, 20_999), SH(), { type: "respec" }, NOW + 1, noRng))).toBe("Not enough cash.");
    expect(err(apply(atLevel(withCash(fresh(), 1e9), 10), SH(), { type: "respec" }, NOW + 1, noRng))).toBe("Nothing to refund.");
  });

  it("tool {kind}, gear, pack: the next tier, checking top tier, level, cash; result { cash, xp }", () => {
    expect(err(apply(withCash(fresh(), 1e9), SH(), { type: "tool", kind: "gather" }, NOW + 1, noRng))).toBe("Needs level 2.");
    expect(err(apply(atLevel(withCash(fresh(), 8999), 2), SH(), { type: "tool", kind: "gather" }, NOW + 1, noRng))).toBe("Not enough cash.");
    const tool = ok(apply(atLevel(withCash(fresh(), 9000), 2), SH(), { type: "tool", kind: "gather" }, NOW + 1, noRng));
    expect(tool.state.careers.civ.tools).toEqual({ gather: 1, process: 0 });
    expect(tool.result).toEqual({ ok: true, cash: -9000, xp: 9 });
    expect(err(apply(atLevel(withCareer(withCash(fresh(), 1e9), { tools: { gather: 6, process: 0 } }), 100), SH(), { type: "tool", kind: "gather" }, NOW + 1, noRng))).toBe("Top of the ladder.");
    const car = ok(apply(withCash(fresh(), 12_000), SH(), { type: "gear" }, NOW + 1, noRng));
    expect(car.state.careers.civ.gearTier).toBe(1);
    expect(car.result).toEqual({ ok: true, cash: -12_000, xp: 12 });
    expect(err(apply(withCash(fresh(), 1e9), SH(), { type: "pack" }, NOW + 1, noRng))).toBe("Needs level 3.");
    const pack = ok(apply(atLevel(withCash(fresh(), 15_000), 3), SH(), { type: "pack" }, NOW + 1, noRng));
    expect(capacityKg(pack.state)).toBe(90);
    expect(err(apply(withCareer(withCash(fresh(), 1e9), { packTier: 4 }), SH(), { type: "pack" }, NOW + 1, noRng))).toBe("Top of the ladder.");
  });

  it("starperk {perkId}: one pick buys one rank of a civ or shared perk", () => {
    const r = ok(apply(withCareer(fresh(), { starPicks: 2 }), SH(), { type: "starperk", perkId: "starXp" }, NOW + 1, noRng));
    expect(r.state.careers.civ.perks).toEqual({ starXp: 1 });
    expect(r.state.careers.civ.starPicks).toBe(1);
    expect(err(apply(fresh(), SH(), { type: "starperk", perkId: "starXp" }, NOW + 1, noRng))).toBe("No star to spend.");
    expect(err(apply(withPerks(withCareer(fresh(), { starPicks: 1 }), { starXp: 5 }), SH(), { type: "starperk", perkId: "starXp" }, NOW + 1, noRng))).toBe("Already maxed.");
    expect(err(apply(withCareer(fresh(), { starPicks: 1 }), SH(), { type: "starperk", perkId: "starBadge" }, NOW + 1, noRng))).toBe("That perk is not for your career.");
  });

  it("autosell toggles and unlocks at level 6; workerautosell always toggles", () => {
    expect(err(apply(atLevel(fresh(), 5), SH(), { type: "autosell" }, NOW + 1, noRng))).toBe("Auto-sell unlocks at level 6.");
    const on = ok(apply(atLevel(fresh(), 6), SH(), { type: "autosell" }, NOW + 1, noRng));
    expect(on.state.careers.civ.autoSell).toBe(true);
    expect(on.result).toEqual({ ok: true, message: "Auto-sell on." });
    expect(ok(apply(withCareer(fresh(), { autoSell: true }), SH(), { type: "autosell" }, NOW + 1, noRng)).state.careers.civ.autoSell).toBe(false);
    expect(ok(apply(fresh(), SH(), { type: "workerautosell" }, NOW + 1, noRng)).state.careers.civ.workerAutoSell).toBe(true);
  });
});

describe("rule 11: crews (actions)", () => {
  it("crewCost is CREW cost * 1.65^owned (9529 for the second orchard crew); crew {siteId} charges it", () => {
    expect(crewCost("kav_apple", 0)).toBe(5775);
    expect(crewCost("kav_apple", 1)).toBe(9529);
    expect(crewCost("kav_gin", 0)).toBe(0);
    const one = ok(apply(withBag(withCash(fresh({ stamina: 0 }), 5775), { apple: 45 }), SH(), { type: "crew", siteId: "kav_apple" }, NOW + 1, noRng));
    expect(one.state.careers.civ.crews).toEqual({ kav_apple: 1 });
    expect(one.result).toEqual({ ok: true, cash: -5775 });
    expect(err(apply(withCash(one.state, 9528), SH(), { type: "crew", siteId: "kav_apple" }, NOW + 500, noRng))).toBe("Not enough cash.");
    expect(ok(apply(withCash(one.state, 9529), SH(), { type: "crew", siteId: "kav_apple" }, NOW + 500, noRng)).state.careers.civ.crews).toEqual({ kav_apple: 2 });
    expect(err(apply(withCash(fresh(), 1e9), SH(), { type: "crew", siteId: "kav_gin" }, NOW + 1, noRng))).toBe("No crew works there.");
    expect(err(apply(withCash(fresh({ cityId: "neochori" }), 1e9), SH(), { type: "crew", siteId: "kav_apple" }, NOW + 1, noRng))).toBe("That site is not in this city.");
    expect(err(apply(withCash(fresh(), 1e9), SH(), { type: "crew", siteId: "kav_cotton" }, NOW + 1, noRng))).toBe("Level 2");
    expect(err(apply(withCareer(withCash(fresh(), 1e9), { crews: { kav_apple: 10 } }), SH(), { type: "crew", siteId: "kav_apple" }, NOW + 1, noRng))).toBe("Crew maxed (10)");
    expect(CREW.kav_apple.perMinute).toBe(11);
  });

  it("crewpause {siteId, paused} parks or resumes one site; siteId null means every crew", () => {
    const s = withCareer(fresh(), { crews: { kav_apple: 1, kav_peach: 2 } });
    const p = ok(apply(s, SH(), { type: "crewpause", siteId: "kav_apple", paused: true }, NOW + 1, noRng));
    expect(p.state.careers.civ.pausedCrews).toEqual(["kav_apple"]);
    const all = ok(apply(p.state, SH(), { type: "crewpause", siteId: null, paused: true }, NOW + 500, noRng));
    expect(all.state.careers.civ.pausedCrews.sort()).toEqual(["kav_apple", "kav_peach"]);
    const back = ok(apply(all.state, SH(), { type: "crewpause", siteId: null, paused: false }, NOW + 1000, noRng));
    expect(back.state.careers.civ.pausedCrews).toEqual([]);
    expect(err(apply(fresh(), SH(), { type: "crewpause", siteId: "kav_apple", paused: true }, NOW + 1, noRng))).toBe("No crew at that site.");
    expect(err(apply(fresh(), SH(), { type: "crewpause", siteId: null, paused: true }, NOW + 1, noRng))).toBe("No crews yet.");
  });
});

describe("rule 12: contractors (actions)", () => {
  it("contractRate is CREW perMinute * 2.5 (gather) or processRates * 2.5 (process), null without a priced output", () => {
    expect(contractRate("kav_apple")).toBe(27.5);
    expect(contractRate("kav_gin")).toBe(7.5);
    expect(contractRate("kav_quarry")).toBeNull();
    expect(contractRate("kav_weed")).toBeNull();
    expect(contractRate("nope")).toBeNull();
  });

  it("worker {siteId, minutes, kind}: a gather contract costs the papers for its length", () => {
    const r = ok(apply(fresh({ papers: 3 }), SH(), { type: "worker", siteId: "kav_apple", minutes: 15, kind: "gather" }, NOW + 1, noRng));
    expect(r.state.careers.civ.workers).toEqual([{ siteId: "kav_apple", kind: "gather", perMinute: 27.5, startedAt: NOW + 1, until: NOW + 1 + 15 * MIN, lastTickAt: NOW + 1, earned: 0 }]);
    expect(r.state.papers).toBe(0);
    expect(r.result).toEqual({ ok: true, message: "Contractor hired at Apple Orchard for 15 min." });
    expect(err(apply(fresh({ papers: 2 }), SH(), { type: "worker", siteId: "kav_apple", minutes: 15, kind: "gather" }, NOW + 1, noRng))).toBe("Not enough contract papers.");
    expect(err(apply(fresh({ papers: 9 }), SH(), { type: "worker", siteId: "kav_apple", minutes: 10, kind: "gather" }, NOW + 1, noRng))).toBe("Unknown contract length.");
    expect(err(apply(fresh({ papers: 9 }), SH(), { type: "worker", siteId: "kav_quarry", minutes: 15, kind: "gather" }, NOW + 1, noRng))).toBe("That site takes no contracts.");
    expect(err(apply(fresh({ papers: 9 }), SH(), { type: "worker", siteId: "kav_apple", minutes: 15, kind: "process" }, NOW + 1, noRng))).toBe("That site takes no contracts.");
  });

  it("three contracts may run; a fourth site is refused, the same site extends its window", () => {
    const w = (siteId: string) => ({ siteId, kind: "gather" as const, perMinute: 27.5, startedAt: NOW, until: NOW + 15 * MIN, lastTickAt: NOW, earned: 0 });
    const busy = withCareer(fresh({ papers: 20 }), { workers: [w("kav_apple"), w("kav_peach"), w("kav_cotton")], licenses: ["farming", "diving"] });
    expect(err(apply(atLevel(busy, 4), SH(), { type: "worker", siteId: "kav_oyster", minutes: 15, kind: "gather" }, NOW + 1, noRng))).toBe("Already running 3 contracts");
    const ext = ok(apply(busy, SH(), { type: "worker", siteId: "kav_apple", minutes: 20, kind: "gather" }, NOW + 1, noRng));
    expect(ext.state.careers.civ.workers[0].until).toBe(NOW + 35 * MIN);
    expect(ext.state.papers).toBe(15);
    expect(ext.result.message).toBe("Extended the contract at Apple Orchard by 20 min.");
  });

  it("a processing contract costs crafted contracts; craftcontract {qty} turns qty * 5 papers into contracts", () => {
    const r = ok(apply(atLevel(fresh({ processPapers: 2 }), 2), SH(), { type: "worker", siteId: "kav_gin", minutes: 20, kind: "process" }, NOW + 1, noRng));
    expect(r.state.careers.civ.workers[0]).toMatchObject({ siteId: "kav_gin", kind: "process", perMinute: 7.5, until: NOW + 1 + 20 * MIN });
    expect(r.state.processPapers).toBe(0);
    expect(err(apply(atLevel(fresh({ processPapers: 1 }), 2), SH(), { type: "worker", siteId: "kav_gin", minutes: 20, kind: "process" }, NOW + 1, noRng))).toBe("Not enough processing contracts.");
    const craft = ok(apply(fresh({ papers: 27 }), SH(), { type: "craftcontract", qty: 5 }, NOW + 1, noRng));
    expect(craft.state.papers).toBe(2);
    expect(craft.state.processPapers).toBe(5);
    expect(craft.result).toEqual({ ok: true, message: "Drew up 5 processing contracts." });
    expect(err(apply(fresh({ papers: 4 }), SH(), { type: "craftcontract", qty: 1 }, NOW + 1, noRng))).toBe("Needs 5 papers — you have 4");
  });
});

describe("rule 13: chests", () => {
  it("openchest {rarity} pays cash and xp scaled by (1 + level / 20) and papers from one uniform roll; result { cash, xp, papers }", () => {
    const s = fresh({ chests: { common: 1, rare: 0, epic: 0, legendary: 0 } });
    const r = ok(apply(s, SH(), { type: "openchest", rarity: "common" }, NOW + 1, rngOf(0.5)));
    expect(r.state.careers.civ.cash).toBe(1575);
    expect(r.state.papers).toBe(1);
    expect(r.state.chests.common).toBe(0);
    expect(r.result).toEqual({ ok: true, cash: 1575, papers: 1, xp: Math.round(30 * 1.05) });
    expect(ok(apply(s, SH(), { type: "openchest", rarity: "common" }, NOW + 1, rngOf(0.49))).result.papers).toBeUndefined();
    const big = atLevel(fresh({ chests: { common: 0, rare: 0, epic: 0, legendary: 1 } }), 100);
    const v = ok(apply(big, SH(), { type: "openchest", rarity: "legendary" }, NOW + 1, rngOf(0.99)));
    expect(v.state.careers.civ.cash).toBe(120_000 * 6);
    expect(v.state.papers).toBe(12);
    expect(err(apply(fresh(), SH(), { type: "openchest", rarity: "common" }, NOW + 1, noRng))).toBe("No such chest.");
  });
});

describe("rule 14: prestige and stars", () => {
  const ready = (over = {}) => atLevel(withCareer(fresh(), {
    cash: 1_000_000, licenses: ["driving", "farming", "mining", "oil", "diving", "gem", "rebel", "chemist", "cartel"],
    tools: { gather: 6, process: 6 }, gearTier: 5, packTier: 4, ...over,
  }), 100);

  it("prestigeBlockers lists every missing requirement in order; the fee rises per star", () => {
    expect(prestigeBlockers(c(ready()), "civ")).toEqual([]);
    expect(prestigeBlockers(c(fresh()), "civ")).toEqual([
      "Needs level 100",
      "Needs the Driver's License", "Needs the Farming License", "Needs the Mining License", "Needs the Oil License", "Needs the Diving License",
      "Needs the Gem Cutting License", "Needs the Rebel Training", "Needs the Chemistry Training", "Needs the Cartel Contacts",
      "Needs the Seismic Bore", "Needs the Industrial Cracker", "Needs the Tempest Device", "Needs the Bergen Hauler",
      "Needs $1,000,000 in cash",
    ]);
    expect(prestigeBlockers(c(ready({ prestige: 2, cash: 1_499_999 })), "civ")).toEqual(["Needs $1,500,000 in cash"]);
    expect(prestigeBlockers(c(ready({ prestige: 25, cash: 1e9 })), "civ")).toEqual(["Already at the top star"]);
    expect(prestigeFee(c(withCareer(fresh(), { prestige: 3 })))).toBe(1_000_000 + 3 * 250_000);
    expect(PRESTIGE.max).toBe(25);
  });

  it("prestige resets the career, keeps chests, papers, stats and perks, grants a star pick, feeds a `raid` line", () => {
    const s = ready({
      inventory: { apple: 5 }, crews: { kav_apple: 3 }, pausedCrews: ["kav_apple"], respecs: 2, autoSell: true, talents: { quickLearner: 2 },
      perks: { starBankroll: 2 }, skills: { endurance: 3 },
    });
    const full = { ...s, papers: 4, processPapers: 1, chests: { common: 2, rare: 0, epic: 0, legendary: 0 }, heat: 3, stats: { ...s.stats, clicks: 9 } };
    const r = ok(apply(full, SH(), { type: "prestige" }, NOW + 1, noRng));
    expect(r.state.careers.civ).toMatchObject({
      prestige: 1, starPicks: 1, cash: 200_000, xp: 0, licenses: [], talents: {}, respecs: 0, tools: { gather: 0, process: 0 }, gearTier: 0, packTier: 0,
      inventory: {}, crews: {}, pausedCrews: [], workers: [], autoSell: false, skills: {}, perks: { starBankroll: 2 },
    });
    expect(r.state).toMatchObject({ papers: 4, processPapers: 1, chests: { common: 2, rare: 0, epic: 0, legendary: 0 }, heat: 3, cityId: "kavala" });
    expect(r.state.stats.clicks).toBe(9);
    expect(r.events).toEqual([{ kind: "raid", text: "retired a civilian run for star 1" }]);
    expect(ok(apply(ready(), SH(), { type: "prestige" }, NOW + 1, noRng)).state.careers.civ.cash).toBe(0);
    expect(err(apply(fresh(), SH(), { type: "prestige" }, NOW + 1, noRng))).toBe("Needs level 100");
    expect(err(apply(ready({ cash: 5 }), SH(), { type: "prestige" }, NOW + 1, noRng))).toBe("Needs $1,000,000 in cash");
  });
});

describe("rule 15: reset, determinism, hygiene", () => {
  it("reset replaces the save with a fresh one at the career picker, stamped now, leaving the market alone", () => {
    const s = withCareer(fresh({ travelTo: "neochori", travelUntil: NOW + 7000 }), { cash: 5, xp: 999, prestige: 3 });
    const sh = SH({ market: { "kavala:apple": { mult: 0.9, at: NOW } } });
    const r = ok(apply(s, sh, { type: "reset" }, NOW + 5000, noRng));
    expect(r.state).toEqual({ ...newState(STEAM, "Tester", NOW + 5000), lastActionAt: NOW + 5000 });
    expect(r.state.faction).toBeNull();
    expect(r.shared.market).toEqual(sh.market);
    expect(r.result).toEqual({ ok: true });
  });

  it("the same inputs and rng sequence give the same result, twice", () => {
    const s = atLevel(withCareer(fresh({ heat: 3 }), { licenses: ["diving"], inventory: { marijuana: 20 }, crews: { kav_apple: 1 }, gearTier: 1 }), 6);
    const sh = SH({ market: { "kavala:marijuana": { mult: 0.8, at: NOW - 3 * MIN } } });
    const script = [0.1, 0.05, 0.01, 0.6, 0.001];
    const run = () => {
      const a = ok(apply(s, sh, { type: "work", siteId: "kav_oyster" }, NOW + 90_000, rngOf(...script)));
      return ok(apply({ ...a.state, lastActionAt: 0 }, a.shared, { type: "sell", itemId: "marijuana", amount: "all" }, NOW + 91_000, noRng));
    };
    expect(run()).toEqual(run());
  });

  it("engine sources never read the clock or the random source (prose included)", () => {
    for (const f of ["engine.ts", "economy.ts", "level.ts", "view.ts", "rules.ts", "casino.ts", "minigames.ts", "chat.ts", "content.ts", "cheats.ts"]) {
      const src = readFileSync(fileURLToPath(new URL(`../${f}`, import.meta.url)), "utf8");
      expect(src, f).not.toMatch(/Date\.now|Math\.random|new Date\(/);
    }
  });

  it("CONST.maxLevel is 100 and the site count is 61", () => {
    expect(CONST.maxLevel).toBe(100);
    expect(Object.keys(SITE)).toHaveLength(61);
    expect(xpAt(2)).toBe(120);
  });
});
