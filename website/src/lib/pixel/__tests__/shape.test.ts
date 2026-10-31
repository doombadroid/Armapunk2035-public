// The snapshot must have the reference's runtime shape: the top-level keys of state_example.json,
// `me` with all 66 keys (recursively, values differ), the row shapes of roster / feed / chat /
// leaderboard / gangs, the gang card, the duel and the worker rows.
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { newDuelPair } from "../engine";
import { snapshot } from "../view";
import type { GangRecord, World } from "../types";
import { EMPTY_WORLD, NOW, STEAM, fresh, seeded, withCareer } from "./helpers";

const example = JSON.parse(readFileSync(fileURLToPath(new URL("../reference/state_example.json", import.meta.url)), "utf8"));

/** Key sets must match at every level; arrays compare their first elements when both have one; a null in the example matches anything null-or-object. */
/** Objects keyed by ids (item, city, skill ...) compare value shapes, not key sets. */
const MAPS = new Set(["snapshot.headsByCity", "snapshot.prices", "snapshot.mults", "snapshot.npcCrime", "snapshot.me.skills", "snapshot.me.talents", "snapshot.me.perks", "snapshot.me.inventory", "snapshot.me.crews", "me.skills", "me.talents", "me.perks", "me.inventory", "me.crews"]);

function assertShape(actual: unknown, expected: unknown, path: string): void {
  if (MAPS.has(path)) {
    expect(actual !== null && typeof actual === "object", path).toBe(true);
    const ev = Object.values(expected as object)[0];
    for (const [k, v] of Object.entries(actual as object)) assertShape(v, ev, `${path}.${k}`);
    return;
  }
  if (expected === null) {
    expect(actual === null || typeof actual === "object", `${path} should be null or an object`).toBe(true);
    return;
  }
  if (Array.isArray(expected)) {
    expect(Array.isArray(actual), path).toBe(true);
    if (expected.length && (actual as unknown[]).length) assertShape((actual as unknown[])[0], expected[0], `${path}[0]`);
    return;
  }
  if (typeof expected === "object") {
    expect(actual !== null && typeof actual === "object", path).toBe(true);
    const a = Object.keys(actual as object).sort();
    const e = Object.keys(expected as object).sort();
    expect(a, path).toEqual(e);
    for (const k of e) assertShape((actual as Record<string, unknown>)[k], (expected as Record<string, unknown>)[k], `${path}.${k}`);
    return;
  }
  expect(typeof actual, path).toBe(typeof expected);
}

function exampleLike() {
  const gang: GangRecord = {
    id: "cmtn68eldr16y", name: "Gang 0", tag: "G0", leaderId: "76561190000000043", private: false, codeSeed: "seed", codeBumps: 0,
    xp: 37_595_820, createdAt: NOW - 1000, members: [{ steamId: "76561190000000043", joinedAt: NOW - 1000 }, { steamId: STEAM, joinedAt: NOW }],
  };
  const duel = newDuelPair({ id: "1", name: "Officer" }, { id: STEAM, name: "Tester" }, seeded(3), NOW).civ;
  duel.status = "resolved";
  duel.outcome = "capture";
  duel.reason = "Civilian did not ready up in time and was taken into custody.";
  let s = fresh({ gangId: gang.id, duel });
  s = withCareer(s, {
    xp: 2_144_716, cash: 5_495_846, inventory: { uraniumu: 1255, uraniump: 78 }, crews: { kav_uranium: 8 }, prestige: 2,
    skills: { endurance: 12, stealth: 12, harvesting: 12, refining: 12, haggling: 12, strength: 12 }, gearTier: 5, packTier: 4,
    talents: { secondWind: 5, bumperCrop: 5 }, perks: { starStamina: 2 }, licenses: ["driving", "farming"],
    workers: [{ siteId: "kav_nuclear", kind: "process", perMinute: 5, startedAt: NOW, until: NOW + 7_000_000, lastTickAt: NOW, earned: 0 }],
  });
  const world: World = {
    ...EMPTY_WORLD,
    avatarUrl: "https://avatars.fastly.steamstatic.com/x_full.jpg",
    roster: [{ steamId: STEAM, name: "Tester", avatarUrl: "", faction: "civ", cityId: "kavala", level: 100, prestige: 2, gangTag: "G0", netWorth: 1, jailed: false, travelling: false }],
    gangs: [{ id: gang.id, name: gang.name, tag: gang.tag, level: 10, members: 2, cap: 10, leaderName: "Player0", private: false }],
    online: 1,
    headsByCity: { kavala: 1 },
    feed: [{ id: 1, at: NOW, kind: "level", steamId: STEAM, name: "Tester", text: "reached level 2" }],
    chat: [{ id: 1, at: NOW, steamId: STEAM, name: "Tester", faction: "civ", text: "hello" }],
    chatOldestId: 1, chatRevision: 1, chatGeneration: "f6cbae88-8940-4aee-bb4f-06abc889fc21",
    leaderboard: [{ name: "Tester", avatarUrl: "", netWorth: 1, level: 100, faction: "civ" }],
    gangMembers: { "76561190000000043": { name: "Player0", level: 1, prestige: 1, online: false }, [STEAM]: { name: "Tester", level: 100, prestige: 2, online: true } },
  };
  return { s, world, gang };
}

describe("snapshot shape vs reference/state_example.json", () => {
  it("has the example's top-level keys", () => {
    const { s, world, gang } = exampleLike();
    const snap = snapshot(s, { market: {}, npcCrime: {} as never, gangs: { [gang.id]: gang }, poker: { seats: [], pot: 0, buyIn: null, minPlayers: 2, lastResult: null } }, world, NOW, true);
    expect(Object.keys(snap).sort()).toEqual(Object.keys(example).sort());
    assertShape(snap, example, "snapshot");
  });

  it("me carries every key of the example (63) with the example's nested shapes (gang, duel, workers, bustEstimate, stats)", () => {
    const { s, world, gang } = exampleLike();
    const snap = snapshot(s, { market: {}, npcCrime: {} as never, gangs: { [gang.id]: gang }, poker: { seats: [], pot: 0, buyIn: null, minPlayers: 2, lastResult: null } }, world, NOW, true);
    expect(Object.keys(example.me)).toHaveLength(63);
    expect(Object.keys(snap.me).sort()).toEqual(Object.keys(example.me).sort());
    assertShape(snap.me, example.me, "me");
    expect(snap.me.gang).not.toBeNull();
    expect(snap.me.duel).not.toBeNull();
    expect(snap.me.workers[0]).toEqual({ siteId: "kav_nuclear", perMinute: 5, until: NOW + 7_000_000, earned: 0, kind: "process" });
  });

  it("prices and mults cover every one of the 58 items, raw goods at 0", () => {
    const { s, world } = exampleLike();
    const snap = snapshot(s, { market: {}, npcCrime: {} as never, gangs: {}, poker: { seats: [], pot: 0, buyIn: null, minPlayers: 2, lastResult: null } }, world, NOW, false);
    expect(Object.keys(snap.prices).sort()).toEqual(Object.keys(example.prices).sort());
    expect(Object.keys(snap.mults).sort()).toEqual(Object.keys(example.mults).sort());
    expect(snap.prices.uraniumu).toBe(0);
    expect(snap.mults.apple).toBe(1.18);
    expect(snap.casino).toBeNull();
    expect(snap.npcCrime).toEqual({ kavala: 100, neochori: 100, athira: 100, pyrgos: 100, sofia: 100 });
    expect(snap.wantedAt).toBe(22);
    expect(snap.pursuitFleeCost).toBe(9);
  });

  it("the example's own figures come out of the same formulas: apple 11, meth 8762, capacity 10447, stamina 300, regen 6.78, visibleAt 22", () => {
    const { s, world } = exampleLike();
    const snap = snapshot(s, { market: {}, npcCrime: {} as never, gangs: {}, poker: { seats: [], pot: 0, buyIn: null, minPlayers: 2, lastResult: null } }, world, NOW, false);
    expect(snap.prices.apple).toBe(11);
    expect(snap.prices.cotton).toBe(514);
    expect(snap.me.capacity).toBe(10447);
    expect(snap.me.staminaMax).toBe(300);
    expect(snap.me.staminaRegen).toBe(6.78);
    expect(snap.me.visibleAt).toBe(22);
    expect(snap.me.netWorth).toBe(5_495_846 + 78 * 4200);
    expect(snap.me.bustEstimate).toEqual({ fine: 17385, fineCeiling: 17385, seized: 327_600, bounty: 4, bountyCeiling: 217 });
    expect(snap.me.bribeCost).toBe(115_328);
    expect(snap.me.level).toBe(100);
    expect(snap.me.xpNeeded).toBe(1);
    expect(snap.me.carried).toBe(3921);
  });

  it("a fresh save shows faction null (the career picker) and every key present", () => {
    const snap = snapshot(fresh({}, null), { market: {}, npcCrime: {} as never, gangs: {}, poker: { seats: [], pot: 0, buyIn: null, minPlayers: 2, lastResult: null } }, EMPTY_WORLD, NOW, true);
    expect(snap.me.faction).toBeNull();
    expect(Object.keys(snap.me).sort()).toEqual(Object.keys(example.me).sort());
    expect(snap.me.gang).toBeNull();
    expect(snap.me.custody).toBeNull();
    expect(snap.me.prestigeReady).toBe(false);
    expect(snap.casino).toEqual({ blackjack: null, poker: { seats: [], pot: 0, buyIn: null, minPlayers: 2, lastResult: null } });
  });
});
