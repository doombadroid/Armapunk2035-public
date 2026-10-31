// The APD career as far as a single officer can drive it: the picker, equipment and certifications,
// cop skills / talents, salary, off-duty work at half rate, dispatch cases (practice and paid),
// the career switch with its cooldown and the "under investigation" rule. Arrests need a wanted
// civilian in the city, so `bust` always answers with the reference's own refusal alone.
import { describe, expect, it } from "vitest";
import { COP_GEAR, INFERRED } from "../content";
import { apply, capacityKg, caseReward, perClick, tick } from "../engine";
import { SITE } from "../content";
import { snapshot } from "../view";
import { EMPTY_WORLD, MIN, NOW, QUIET, atLevel, err, fresh, noRng, ok, rngOf, seeded, shared, withBag, withCareer, withCash, withSkills } from "./helpers";

const cop = (over = {}) => fresh(over, "cop");
const SH = shared;

describe("APD: equipment, certifications, skills, talents", () => {
  it("copgear moves up the ladder for cash; Interceptor needs Firearms Certification; civilians cannot", () => {
    const r = ok(apply(withCash(cop(), 55_000), SH(), { type: "copgear" }, NOW + 1, noRng));
    expect(r.state.careers.cop.copGearTier).toBe(1);
    expect(r.result).toEqual({ ok: true, cash: -55_000, xp: 55 });
    expect(err(apply(withCash(r.state, 1e9), SH(), { type: "copgear" }, NOW + 500, noRng))).toBe("Needs the Firearms Certification.");
    const certified = withCareer(withCash(r.state, 320_000), { licenses: ["firearms"] });
    expect(ok(apply(certified, SH(), { type: "copgear" }, NOW + 500, noRng)).state.careers.cop.copGearTier).toBe(2);
    expect(err(apply(withCareer(withCash(cop(), 1e9), { copGearTier: 4 }), SH(), { type: "copgear" }, NOW + 1, noRng))).toBe("Top of the ladder.");
    expect(err(apply(withCash(fresh(), 1e9), SH(), { type: "copgear" }, NOW + 1, noRng))).toBe("Civilians cannot draw APD equipment.");
    expect(COP_GEAR[2].requires).toBe("firearms");
  });

  it("cop licences, skills and talents are the cop tables; civ ones are refused; tools / gear / pack are standard issue", () => {
    expect(ok(apply(withCash(cop(), 25_000), SH(), { type: "license", licenseId: "firearms" }, NOW + 1, noRng)).state.careers.cop.licenses).toEqual(["firearms"]);
    expect(err(apply(withCash(cop(), 1e9), SH(), { type: "license", licenseId: "farming" }, NOW + 1, noRng))).toBe("That licence is not for your career.");
    expect(ok(apply(withCash(cop(), 3200), SH(), { type: "skill", skillId: "pursuit" }, NOW + 1, noRng)).state.careers.cop.skills.pursuit).toBe(1);
    expect(ok(apply(withCash(cop(), 1400), SH(), { type: "skill", skillId: "endurance" }, NOW + 1, noRng)).state.careers.cop.skills.endurance).toBe(1);
    expect(err(apply(withCash(cop(), 1e9), SH(), { type: "skill", skillId: "harvesting" }, NOW + 1, noRng))).toBe("That skill is not for your career.");
    expect(ok(apply(atLevel(cop(), 8), SH(), { type: "talent", talentId: "warrant" }, NOW + 1, noRng)).state.careers.cop.talents).toEqual({ warrant: 1 });
    expect(err(apply(atLevel(cop(), 50), SH(), { type: "talent", talentId: "bumperCrop" }, NOW + 1, noRng))).toBe("That talent is not for your career.");
    expect(err(apply(withCash(cop(), 1e9), SH(), { type: "tool", kind: "gather" }, NOW + 1, noRng))).toBe("Officers use standard issue.");
    expect(err(apply(withCash(cop(), 1e9), SH(), { type: "gear" }, NOW + 1, noRng))).toBe("Officers use standard issue.");
    expect(err(apply(withCash(cop(), 1e9), SH(), { type: "pack" }, NOW + 1, noRng))).toBe("Officers use standard issue.");
  });

  it("the two careers are separate builds: the civ bag, cash and equipment sleep while on duty", () => {
    const s = cop();
    s.careers.civ = { ...s.careers.civ, cash: 5000, inventory: { apple: 3 }, gearTier: 5, packTier: 4 };
    expect(capacityKg(s)).toBe(45);
    const v = snapshot(s, SH(), EMPTY_WORLD, NOW, false).me;
    expect(v).toMatchObject({ faction: "cop", cash: 0, inventory: {}, gearTier: 5, packTier: 4, copGearTier: 0, capacity: 45 });
    expect(Object.keys(v.skills).sort()).toEqual(["authority", "dispatch", "endurance", "forensics", "interrogation", "investigation", "pursuit"]);
  });
});

describe("APD: off-duty work, sales, crews", () => {
  it("officers work legal sites at half rate with the starter tool; illegal sites are APD personnel only", () => {
    expect(perClick(cop(), SITE.kav_apple)).toBe(6);
    expect(perClick(withCareer(cop(), { tools: { gather: 6, process: 6 } }), SITE.kav_apple)).toBe(6);
    const r = ok(apply(cop(), SH(), { type: "work", siteId: "kav_apple" }, NOW + 1, rngOf(...QUIET)));
    expect(r.result).toEqual({ ok: true, gained: { apple: 6 }, xp: 6 });
    expect(r.state.careers.cop.inventory).toEqual({ apple: 6 });
    expect(err(apply(atLevel(cop(), 2), SH(), { type: "work", siteId: "kav_weed" }, NOW + 1, noRng))).toBe("APD personnel cannot work illegal sites.");
  });

  it("officers do not fence contraband, hire crews or contractors, or auto-sell", () => {
    expect(err(apply(withBag(cop(), { marijuana: 2 }), SH(), { type: "sell", itemId: "marijuana", amount: 1 }, NOW + 1, noRng))).toBe("Officers do not fence contraband.");
    expect(ok(apply(withBag(cop(), { apple: 2 }), SH(), { type: "sell", itemId: "apple", amount: 1 }, NOW + 1, noRng)).result.cash).toBe(8);
    expect(err(apply(withCash(cop(), 1e9), SH(), { type: "crew", siteId: "kav_apple" }, NOW + 1, noRng))).toBe("Officers cannot hire crews.");
    expect(err(apply(cop({ papers: 9 }), SH(), { type: "worker", siteId: "kav_apple", minutes: 15, kind: "gather" }, NOW + 1, noRng))).toBe("Officers cannot hire contractors.");
    expect(err(apply(atLevel(cop(), 10), SH(), { type: "autosell" }, NOW + 1, noRng))).toBe("Auto-sell is a civilian perk.");
  });

  it("salary accrues per whole minute on duty, online or not: 100 + 5 * level", () => {
    expect(tick(cop(), SH(), NOW + 3.5 * MIN).state.careers.cop.cash).toBe(3 * 105);
    expect(tick(atLevel(cop(), 10), SH(), NOW + MIN).state.careers.cop.cash).toBe(150);
    expect(tick(fresh(), SH(), NOW + 3 * MIN).state.careers.cop.cash).toBe(0);
  });
});

describe("APD: dispatch cases", () => {
  it("casestart {practice: true} opens an unpaid case with three route rounds; answers score and settle it", () => {
    const r = ok(apply(cop(), SH(), { type: "casestart", practice: true }, NOW + 1, seeded(7)));
    const k = r.state.apdCase!;
    expect(k).toMatchObject({ status: "active", practice: true, targetScore: INFERRED.caseTargetScore, reward: 0, answers: [], startsAt: NOW + 1 + 3000, until: NOW + 1 + 3000 + 45_000 });
    expect(k.rounds).toHaveLength(3);
    expect(k.rounds[0].options.map((o) => o.label)).toEqual(["Left street", "Center street", "Right street"]);
    expect(k.rounds[1].prompt).toBe("Checkpoint 2: choose the lowest total route cost.");
    expect(r.state.stamina).toBe(100);
    expect(err(apply(r.state, SH(), { type: "caseanswer", id: k.id, round: 0, choice: 0 }, NOW + 500, noRng))).toBe("Get ready. The call has not started.");
    expect(err(apply(r.state, SH(), { type: "caseanswer", id: k.id, round: 1, choice: 0 }, NOW + 4000, noRng))).toBe("Answer the checkpoints in order.");
    expect(err(apply(r.state, SH(), { type: "caseanswer", id: "nope", round: 0, choice: 0 }, NOW + 4000, noRng))).toBe("That case is closed.");
    let s = r.state;
    for (let i = 0; i < 3; i++) {
      const round = s.apdCase!.rounds[i];
      const costs = round.options.map((o) => o.distance + o.obstacles * round.obstacleCost);
      const best = costs.indexOf(Math.min(...costs));
      s = ok(apply({ ...s, lastActionAt: 0 }, SH(), { type: "caseanswer", id: k.id, round: i, choice: best }, NOW + 4000, noRng)).state;
    }
    expect(s.apdCase!.answers.map((a) => a.score)).toEqual([100, 100, 100]);
    expect(s.apdCase!.status).toBe("won");
    expect(s.careers.cop.cash).toBe(0);
    expect(err(apply(s, SH(), { type: "caseanswer", id: k.id, round: 0, choice: 0 }, NOW + 5000, noRng))).toBe("No open case.");
  });

  it("a paid call costs patrol stamina and 20 city crime, pays caseReward on a win with XP and a chest roll, then cools down", () => {
    const sh = SH({ npcCrime: { kavala: { value: 100, at: NOW }, neochori: { value: 100, at: NOW }, athira: { value: 100, at: NOW }, pyrgos: { value: 100, at: NOW }, sofia: { value: 100, at: NOW } } });
    const r = ok(apply(cop(), sh, { type: "casestart", practice: false }, NOW + 1, seeded(9)));
    expect(r.state.stamina).toBe(92);
    expect(r.shared.npcCrime.kavala).toEqual({ value: 80, at: NOW + 1 });
    expect(r.state.apdCase!.reward).toBe(caseReward(r.state.careers.cop, 1));
    expect(caseReward(cop().careers.cop, 1)).toBe(420);
    expect(r.state.stats.clicks).toBe(1);
    let s = r.state;
    const id = s.apdCase!.id;
    let last = ok(apply({ ...s, lastActionAt: 0 }, sh, { type: "caseanswer", id, round: 0, choice: 0 }, NOW + 4000, noRng));
    const worst = (i: number) => {
      const round = s.apdCase!.rounds[i];
      const costs = round.options.map((o) => o.distance + o.obstacles * round.obstacleCost);
      return costs.indexOf(Math.max(...costs));
    };
    void worst;
    for (let i = 0; i < 3; i++) {
      const round = s.apdCase!.rounds[i];
      const costs = round.options.map((o) => o.distance + o.obstacles * round.obstacleCost);
      const best = costs.indexOf(Math.min(...costs));
      last = ok(apply({ ...s, lastActionAt: 0 }, sh, { type: "caseanswer", id, round: i, choice: best }, NOW + 4000, rngOf(1)));
      s = last.state;
    }
    expect(s.apdCase!.status).toBe("won");
    expect(last.result).toMatchObject({ cash: 420, xp: 30 });
    expect(s.careers.cop.cash).toBe(420);
    expect(s.apdCaseReadyAt).toBe(NOW + 4000 + INFERRED.caseCooldownMs);
    expect(err(apply({ ...s, lastActionAt: 0 }, sh, { type: "casestart", practice: false }, NOW + 5000, noRng))).toBe("Cooling down (59s)");
    expect(ok(apply({ ...s, lastActionAt: 0 }, sh, { type: "casestart", practice: true }, NOW + 5000, seeded(1))).state.apdCase!.practice).toBe(true);
  });

  it("no paid calls below 2 crime; too tired; an open case blocks another; the window expires by tick", () => {
    const quiet = SH({ npcCrime: { kavala: { value: 1, at: NOW } } as never });
    expect(err(apply(cop(), quiet, { type: "casestart", practice: false }, NOW + 1, noRng))).toBe("No paid calls here");
    expect(err(apply(cop({ stamina: 7 }), SH(), { type: "casestart", practice: false }, NOW + 1, noRng))).toBe("Too tired");
    const open = ok(apply(cop(), SH(), { type: "casestart", practice: true }, NOW + 1, seeded(2)));
    expect(err(apply(open.state, SH(), { type: "casestart", practice: true }, NOW + 500, noRng))).toBe("Finish the open case first.");
    expect(tick(open.state, SH(), NOW + 1 + 3000 + 45_001).state.apdCase!.status).toBe("expired");
    expect(err(apply(fresh(), SH(), { type: "casestart", practice: true }, NOW + 1, noRng))).toBe("Only APD officers take calls.");
  });

  it("a lost paid case pays nothing and still starts the cooldown", () => {
    const r = ok(apply(cop(), SH(), { type: "casestart", practice: false }, NOW + 1, seeded(11)));
    let s = r.state;
    for (let i = 0; i < 3; i++) {
      const round = s.apdCase!.rounds[i];
      const costs = round.options.map((o) => o.distance + o.obstacles * round.obstacleCost);
      const worst = costs.indexOf(Math.max(...costs));
      s = ok(apply({ ...s, lastActionAt: 0 }, SH(), { type: "caseanswer", id: s.apdCase!.id, round: i, choice: worst }, NOW + 4000, noRng)).state;
    }
    expect(s.apdCase!.status).toBe("lost");
    expect(s.careers.cop.cash).toBe(0);
    expect(s.apdCaseReadyAt).toBe(NOW + 4000 + INFERRED.caseCooldownMs);
  });

  it("bust {targetId} needs an officer, 14 stamina and a suspect in the city; alone there is never one", () => {
    expect(err(apply(fresh(), SH(), { type: "bust", targetId: "76561190000000002" }, NOW + 1, noRng))).toBe("Only APD officers make arrests.");
    expect(err(apply(cop({ stamina: 13 }), SH(), { type: "bust", targetId: "76561190000000002" }, NOW + 1, noRng))).toBe("Too tired");
    expect(err(apply(cop(), SH(), { type: "bust", targetId: "76561190000000002" }, NOW + 1, noRng))).toBe("No such suspect.");
  });
});

describe("switching careers", () => {
  it("switch {faction}: 15-minute cooldown, no badge while heat is above 1, the other career resumes where it left off", () => {
    const s = withCareer(fresh(), { cash: 500, inventory: { apple: 3 }, crews: { kav_apple: 1 } });
    expect(err(apply({ ...s, heat: 1.5 }, SH(), { type: "switch", faction: "cop" }, NOW + 1, noRng))).toBe("The APD will not take you while you are under investigation. Let your heat cool.");
    expect(err(apply(s, SH(), { type: "switch", faction: "civ" }, NOW + 1, noRng))).toBe("You are already a civilian.");
    const r = ok(apply({ ...s, heat: 1 }, SH(), { type: "switch", faction: "cop" }, NOW + 1, noRng));
    expect(r.state.faction).toBe("cop");
    expect(r.state.careerSwitchReadyAt).toBe(NOW + 1 + 15 * MIN);
    expect(r.state.careers.civ.inventory).toEqual({ apple: 3 });
    expect(r.state.careers.civ.cash).toBe(500);
    expect(r.state.careers.cop.cash).toBe(0);
    expect(r.result).toEqual({ ok: true, message: "Badge on. Welcome to the APD." });
    expect(err(apply(r.state, SH(), { type: "switch", faction: "civ" }, NOW + 2000, noRng))).toBe("Paperwork pending — 899s.");
    const back = ok(apply(r.state, SH(), { type: "switch", faction: "civ" }, NOW + 1 + 15 * MIN, noRng));
    expect(back.state.faction).toBe("civ");
    expect(back.state.careers.civ.inventory).toEqual({ apple: 3 });
    expect(back.state.careers.civ.crewsAt).toBe(NOW + 1 + 15 * MIN);
  });

  it("stamina is clamped to the new career's max and the civ heat keeps cooling on duty", () => {
    const s = withSkills(fresh({ stamina: 200, heat: 0.5 }), { endurance: 10 });
    const r = ok(apply(s, SH(), { type: "switch", faction: "cop" }, NOW + 1, noRng));
    expect(r.state.stamina).toBe(100);
    expect(tick(r.state, SH(), NOW + 1 + MIN).state.heat).toBe(0);
  });
});
