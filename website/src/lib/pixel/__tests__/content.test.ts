// Armapunk Pixel v3 content: the tables are the reference's statics, verbatim, and they agree with
// each other. A balance edit that breaks a cross-reference fails here before it reaches the engine.
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import {
  BACKPACKS, CHEST, CHEST_DETAILS, CHESTS, CITIES, CITY, CONST, CONTENT_TABLES, CONTRACTS, COP_GEAR, CREW, CREWS, GANG, GEAR, INFERRED, ITEM, ITEMS,
  LICENSE, LICENSES, PRESTIGE, PROCESS_RATES, SITE, SITES, SKILL, SKILLS, STAR_PERK, STAR_PERKS, TALENT, TALENTS, TOOLS, TRAVEL, XP_CURVE,
} from "../content";

const statics = JSON.parse(readFileSync(fileURLToPath(new URL("../reference/statics.json", import.meta.url)), "utf8"));

describe("content is the reference statics, verbatim", () => {
  it("CONTENT_TABLES deep-equals reference/statics.json", () => {
    expect(CONTENT_TABLES).toEqual(statics);
    expect(Object.keys(CONTENT_TABLES).sort()).toEqual(Object.keys(statics).sort());
  });

  it("the named tables are the same objects and the derived maps index them by id", () => {
    expect(CITIES).toBe(CONTENT_TABLES.cities);
    expect(SITES).toBe(CONTENT_TABLES.sites);
    expect(ITEMS).toBe(CONTENT_TABLES.items);
    expect(CITY.kavala.name).toBe("Kavala");
    expect(SITE.kav_apple.output).toBe("apple");
    expect(ITEM.pixied.name).toBe("Impure Pixie Dust");
    expect(SKILL.endurance.costs[0]).toBe(1400);
    expect(LICENSE.cartel.cost).toBe(400_000);
    expect(TALENT.ghost.minLevel).toBe(18);
    expect(CREW.kav_apple).toEqual({ id: "kav_apple", name: "Apple Orchard Crew", siteId: "kav_apple", cost: 5775, perMinute: 11 });
    expect(STAR_PERK.starBankroll.value).toBe(100_000);
    expect(CHEST.legendary.name).toBe("Cartel Vault");
    expect(CITIES).toHaveLength(5);
    expect(SITES).toHaveLength(61);
    expect(ITEMS).toHaveLength(58);
    expect(SKILLS).toHaveLength(12);
    expect(LICENSES).toHaveLength(13);
    expect(TALENTS).toHaveLength(14);
    expect(CREWS).toHaveLength(34);
    expect(Object.keys(PROCESS_RATES)).toHaveLength(27);
    expect(STAR_PERKS).toHaveLength(7);
    expect(COP_GEAR).toHaveLength(5);
  });

  it("constants and contracts read the statics scalars", () => {
    expect(CONST).toMatchObject({ talentPointsPerLevel: 1, maxLevel: 100, autoSellUnlockLevel: 6, careerSwitchCooldownMin: 15, wantedAt: 22, maxArrestBounty: 1_000_000, maxCrewsPerSite: 10, chatMaxLen: 240, crewCostGrowth: 1.65 });
    expect(CONTRACTS.worker).toEqual([{ minutes: 15, papers: 3 }, { minutes: 20, papers: 5 }, { minutes: 30, papers: 7 }]);
    expect(CONTRACTS.process).toEqual([{ minutes: 15, contracts: 1 }, { minutes: 20, contracts: 2 }, { minutes: 30, contracts: 3 }]);
    expect(CONTRACTS).toMatchObject({ processContractPaperCost: 5, workerRateMult: 2.5, workerMaxActive: 3, paperDropChance: 0.015 });
    expect(PRESTIGE).toEqual({ max: 25, cashBase: 1_000_000, cashStep: 250_000 });
    expect(GANG.xpCurve).toEqual([0, 6000, 25723, 60271, 110275, 176193, 258386, 357155, 472759, 605425]);
  });
});

describe("content: cross references", () => {
  it("every site output, input, jackpot item, licence and city exists; skill matches mode", () => {
    for (const site of SITES) {
      expect(ITEM[site.output], `${site.id} output`).toBeDefined();
      if (site.input) expect(ITEM[site.input], `${site.id} input`).toBeDefined();
      if (site.jackpot) expect(ITEM[site.jackpot[0]], `${site.id} jackpot`).toBeDefined();
      if (site.license) expect(LICENSE[site.license], `${site.id} licence`).toBeDefined();
      expect(CITY[site.cityId], site.id).toBeDefined();
      expect(site.skill).toBe(site.mode === "gather" ? "harvesting" : "refining");
      if (site.mode === "process") expect(site.inputPer, site.id).toBeGreaterThanOrEqual(1);
      else expect(site.input, site.id).toBeUndefined();
    }
    expect(new Set(SITES.map((s) => s.id)).size).toBe(SITES.length);
  });

  it("every crew keys a gather site and every processRates entry a process site", () => {
    for (const cr of CREWS) {
      expect(SITE[cr.siteId], cr.id).toBeDefined();
      expect(SITE[cr.siteId].mode, cr.id).toBe("gather");
      expect(cr.id).toBe(cr.siteId);
    }
    for (const id of Object.keys(PROCESS_RATES)) expect(SITE[id]?.mode, id).toBe("process");
  });

  it("skill costs follow round(base * rank^2.05); talents cost [1, 1, 2, 2, 3]", () => {
    for (const sk of SKILLS) {
      expect(sk.costs).toHaveLength(12);
      sk.costs.forEach((cost, i) => expect(cost, `${sk.id} rank ${i + 1}`).toBe(Math.round(sk.costs[0] * (i + 1) ** 2.05)));
    }
    for (const t of TALENTS) expect(t.costs, t.id).toEqual([1, 1, 2, 2, 3]);
  });

  it("gang xp curve is round(6000 * n^2.1)", () => {
    GANG.xpCurve.forEach((v, n) => expect(v).toBe(Math.round(6000 * n ** 2.1)));
  });

  it("XP_CURVE has 100 strictly increasing entries and levels 2-30 are round(120 * n^1.75)", () => {
    expect(XP_CURVE).toHaveLength(100);
    for (let i = 1; i < 100; i++) expect(XP_CURVE[i]).toBeGreaterThan(XP_CURVE[i - 1]);
    for (let n = 1; n <= 29; n++) expect(XP_CURVE[n], `index ${n}`).toBe(Math.round(120 * n ** 1.75));
  });

  it("tiers are contiguous from a free tier 0", () => {
    GEAR.forEach((g, i) => expect(g.tier).toBe(i));
    BACKPACKS.forEach((b, i) => expect(b.tier).toBe(i));
    COP_GEAR.forEach((g, i) => expect(g.tier).toBe(i));
    for (const kind of ["gather", "process"] as const) {
      const tiers = TOOLS.filter((t) => t.kind === kind);
      expect(tiers).toHaveLength(7);
      tiers.forEach((t, i) => expect(t.tier).toBe(i));
    }
    expect(GEAR[0].cost + BACKPACKS[0].cost + COP_GEAR[0].cost).toBe(0);
    for (const g of COP_GEAR) if (g.requires) expect(LICENSE[g.requires]?.faction).toBe("cop");
  });

  it("the travel matrix is symmetric with a zero diagonal; every city demand is positive", () => {
    for (const a of CITIES) {
      expect(a.demand).toBeGreaterThan(0);
      for (const b of CITIES) {
        expect(TRAVEL[a.id][b.id]).toBe(TRAVEL[b.id][a.id]);
        if (a.id === b.id) expect(TRAVEL[a.id][b.id]).toBe(0);
        else expect(TRAVEL[a.id][b.id]).toBeGreaterThan(0);
      }
    }
  });

  it("chest weights sum to 100 and the bundle details cover every rarity", () => {
    expect(CHESTS.reduce((t, ch) => t + ch.weight, 0)).toBe(100);
    for (const ch of CHESTS) {
      expect(CHEST_DETAILS[ch.rarity]).toBeDefined();
      expect(CHEST_DETAILS[ch.rarity].papers[0]).toBeLessThanOrEqual(CHEST_DETAILS[ch.rarity].papers[1]);
    }
    expect(CHEST_DETAILS.common).toEqual({ xp: 30, papers: [0, 1] });
    expect(CHEST_DETAILS.legendary).toEqual({ xp: 1500, papers: [8, 12] });
  });

  it("INFERRED reproduces the snapshot figures it was fitted to", () => {
    expect(INFERRED.staminaBase + 15 * 12 + 10 * 2).toBe(300);
    expect(Math.round(INFERRED.fineBase + INFERRED.finePerLevel * 100)).toBe(17_385);
    expect(Math.round(INFERRED.bribeSeizedPct * 327_600)).toBe(115_328);
    expect(Math.round(INFERRED.respecBase + INFERRED.respecPerPoint * 52)).toBe(121_000);
    expect(Math.round(78 * INFERRED.bountyPerUnitMin)).toBe(4);
    expect(Math.round(78 * INFERRED.bountyPerUnitMax)).toBe(217);
    expect(INFERRED.marketRest).toBe(1.18);
  });
});
