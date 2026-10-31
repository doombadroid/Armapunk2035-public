// parseAction: the 52 reference action types with their payload keys; ids validated against the tables.
import { describe, expect, it } from "vitest";
import { ACTION_TYPES, parseAction } from "../parse";

describe("parseAction (reference vocabulary)", () => {
  it("rejects non-objects, unknown types and the v2 vocabulary", () => {
    expect(parseAction(null)).toBeNull();
    expect(parseAction("work")).toBeNull();
    expect(parseAction({})).toBeNull();
    expect(parseAction({ type: "crewPause", site: "kav_apple" })).toBeNull();
    expect(parseAction({ type: "work", site: "kav_apple" })).toBeNull();
    expect(parseAction({ type: "vehicle" })).toBeNull();
  });

  it("knows all 52 types", () => {
    expect(ACTION_TYPES).toHaveLength(52);
    const sample: Record<string, object> = {
      work: { siteId: "kav_apple" }, sell: { itemId: "apple", amount: "all" }, drop: { itemId: "apple", amount: 1 }, travel: { cityId: "neochori" },
      license: { licenseId: "farming" }, skill: { skillId: "endurance" }, talent: { talentId: "mule" }, starperk: { perkId: "starXp" }, tool: { kind: "gather" },
      crew: { siteId: "kav_apple" }, crewpause: { siteId: "kav_apple", paused: true }, worker: { siteId: "kav_apple", minutes: 15, kind: "gather" },
      craftcontract: { qty: 1 }, openchest: { rarity: "rare" }, faction: { faction: "civ" }, switch: { faction: "cop" }, bust: { targetId: "76561190000000002" },
      casestart: { practice: true }, caseanswer: { id: "abc", round: 0, choice: 1 }, prisonrotate: { custodyId: "a", jobId: "b", tile: 4 },
      prisoncomplete: { custodyId: "a", jobId: "b" }, pursuitready: { id: "a" }, pursuitanswer: { id: "a", round: 2, choice: 0 }, pursuitsurrender: { id: "a" },
      verify: { id: "a", answer: "anchor" }, chat: { text: "gg" }, gangcreate: { name: "Gang", tag: "GG" }, gangjoin: { gangId: "cmtn68eldr16y", code: "" },
      gangkick: { targetId: "76561190000000002" }, gangprivacy: { private: true }, blackjackdeal: { bet: 5000 }, slots: { bet: 1 },
      roulette: { bet: 10, choice: "number", number: 17 }, pokerjoin: { buyIn: 5000 },
    };
    for (const t of ACTION_TYPES) {
      const a = parseAction({ type: t, ...(sample[t] ?? {}) });
      expect(a, t).not.toBeNull();
      expect(a?.type).toBe(t);
    }
  });

  it("site, city and id payloads are checked against the tables (own properties only)", () => {
    expect(parseAction({ type: "work", siteId: "kav_apple" })).toEqual({ type: "work", siteId: "kav_apple" });
    expect(parseAction({ type: "work", siteId: "tri_apple" })).toBeNull();
    expect(parseAction({ type: "work", siteId: "__proto__" })).toBeNull();
    expect(parseAction({ type: "travel", cityId: "kavala" })).toEqual({ type: "travel", cityId: "kavala" });
    expect(parseAction({ type: "travel", cityId: "trinite" })).toBeNull();
    expect(parseAction({ type: "license", licenseId: "constructor" })).toBeNull();
    expect(parseAction({ type: "talent", talentId: "bumperCrop" })).toEqual({ type: "talent", talentId: "bumperCrop" });
    expect(parseAction({ type: "starperk", perkId: "starBadge" })).toEqual({ type: "starperk", perkId: "starBadge" });
    expect(parseAction({ type: "tool", kind: "gun" })).toBeNull();
  });

  it("sell and drop take amount as a count or all; crewpause takes a null siteId for all crews", () => {
    expect(parseAction({ type: "sell", itemId: "glass", amount: 10 })).toEqual({ type: "sell", itemId: "glass", amount: 10 });
    expect(parseAction({ type: "sell", itemId: "glass", amount: "all" })).toEqual({ type: "sell", itemId: "glass", amount: "all" });
    expect(parseAction({ type: "drop", itemId: "glass", amount: 0 })).toBeNull();
    expect(parseAction({ type: "sell", itemId: "glass", amount: 1.5 })).toBeNull();
    expect(parseAction({ type: "crewpause", siteId: null, paused: false })).toEqual({ type: "crewpause", siteId: null, paused: false });
    expect(parseAction({ type: "crewpause", siteId: "kav_apple", paused: "yes" })).toBeNull();
  });

  it("contracts, chests, casino and gang payloads", () => {
    expect(parseAction({ type: "worker", siteId: "kav_apple", minutes: -5, kind: "gather" })).toBeNull();
    expect(parseAction({ type: "craftcontract", qty: 5 })).toEqual({ type: "craftcontract", qty: 5 });
    expect(parseAction({ type: "craftcontract", qty: 0 })).toBeNull();
    expect(parseAction({ type: "openchest", rarity: "mythic" })).toBeNull();
    expect(parseAction({ type: "blackjackdeal", bet: 0 })).toBeNull();
    expect(parseAction({ type: "roulette", bet: 10, choice: "red" })).toEqual({ type: "roulette", bet: 10, choice: "red", number: 0 });
    expect(parseAction({ type: "roulette", bet: 10, choice: "number", number: 37 })).toBeNull();
    expect(parseAction({ type: "roulette", bet: 10, choice: "purple", number: 1 })).toBeNull();
    expect(parseAction({ type: "gangcreate", name: "Gang", tag: 12 })).toBeNull();
    expect(parseAction({ type: "gangjoin", gangId: "../x", code: "" })).toBeNull();
    expect(parseAction({ type: "faction", faction: "medic" })).toBeNull();
    expect(parseAction({ type: "bust", targetId: "not-a-steamid" })).toBeNull();
  });

  it("bare actions pass through without extra fields", () => {
    for (const t of ["gear", "pack", "copgear", "autosell", "workerautosell", "payheat", "ditch", "respec", "prestige", "reset", "release", "prisonstart", "hp", "gangleave", "blackjackhit", "blackjackstand", "pokerdeal", "pokerleave"] as const) {
      expect(parseAction({ type: t, junk: 1 })).toEqual({ type: t });
    }
  });
});
