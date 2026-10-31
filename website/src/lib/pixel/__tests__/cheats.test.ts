// The owner advantages (cheats.ts): who gets them, unlimited stamina, and the top prestige star.
// Everyone who is not the owner must still play the reference rules, so every case here has a
// negative twin.
import { describe, expect, it } from "vitest";
import { PRESTIGE, SITE, STAR_PERK } from "../content";
import { ACTION_GAP_MS, apply, cheatsFor, emptyShared, NO_CHEATS, perkRanksSpent, staminaMax, tick, TOO_FAST } from "../engine";
import type { PlayerState } from "../types";
import { snapshot } from "../view";
import { EMPTY_WORLD, fresh, NOW, STEAM, withCareer, withPerks } from "./helpers";

const OWNER = "76561190000000001";
const SHARED = () => emptyShared();

/** A save with the owner cheats on, however the store would have stamped them. */
function cheating(over: Partial<PlayerState> = {}): PlayerState {
  return fresh({ ...over, cheats: cheatsFor(OWNER, OWNER) });
}

describe("who gets the cheats", () => {
  it("gives the owner account both", () => {
    expect(cheatsFor(OWNER, OWNER)).toEqual({ unlimitedStamina: true, maxPrestige: true, noRateLimit: true });
  });
  it("gives every other account none", () => {
    expect(cheatsFor(STEAM, OWNER)).toEqual(NO_CHEATS);
  });
  it("gives nobody anything when the owner is not configured", () => {
    expect(cheatsFor(OWNER, undefined)).toEqual(NO_CHEATS);
    expect(cheatsFor(OWNER, "")).toEqual(NO_CHEATS);
  });
});

describe("unlimited stamina", () => {
  const site = SITE.kav_apple;

  it("works a site that a spent player cannot", () => {
    const spent = { stamina: 0, staminaAt: NOW };
    const owner = apply(cheating(spent), SHARED(), { type: "work", siteId: site.id }, NOW, () => 0.99, 1);
    expect(owner.result).toMatchObject({ ok: true });

    const other = apply(fresh(spent), SHARED(), { type: "work", siteId: site.id }, NOW, () => 0.99, 1);
    expect(other.result).toEqual({ ok: false, error: "Too tired" });
  });

  it("never spends stamina on a work click", () => {
    const out = apply(cheating(), SHARED(), { type: "work", siteId: site.id }, NOW, () => 0.99, 1);
    expect(out.state.stamina).toBe(staminaMax(out.state.careers.civ));
  });

  it("still charges everyone else", () => {
    const out = apply(fresh(), SHARED(), { type: "work", siteId: site.id }, NOW, () => 0.99, 1);
    expect(out.state.stamina).toBe(staminaMax(out.state.careers.civ) - site.stamina);
  });

  it("pins the bar to its maximum on a tick, from empty", () => {
    const t = tick(cheating({ stamina: 0, staminaAt: NOW }), SHARED(), NOW + 1000);
    expect(t.state.stamina).toBe(staminaMax(t.state.careers.civ));
  });

  it("pins to the maximum the player's own build earns", () => {
    const s = withCareer(cheating({ stamina: 0, staminaAt: NOW }), { skills: { endurance: 12 } });
    const t = tick(s, SHARED(), NOW + 1000);
    expect(t.state.stamina).toBe(staminaMax(t.state.careers.civ));
    expect(t.state.stamina).toBeGreaterThan(100);
  });
});

describe("max prestige", () => {
  it("puts both careers on the top star with every pick that tier grants", () => {
    const t = tick(cheating(), SHARED(), NOW + 1);
    expect(t.state.careers.civ.prestige).toBe(PRESTIGE.max);
    expect(t.state.careers.cop.prestige).toBe(PRESTIGE.max);
    expect(t.state.careers.civ.starPicks).toBe(PRESTIGE.max);
  });

  it("counts attuned perk ranks against the picks", () => {
    const s = withPerks(cheating(), { starYield: 5, starXp: 2 });
    const t = tick(s, SHARED(), NOW + 1);
    expect(perkRanksSpent(t.state.careers.civ)).toBe(7);
    expect(t.state.careers.civ.starPicks).toBe(PRESTIGE.max - 7);
  });

  it("is idempotent: attuning a rank costs a pick and ticking does not refund it", () => {
    const first = tick(cheating(), SHARED(), NOW + 1).state;
    const spent = apply(first, SHARED(), { type: "starperk", perkId: "starYield" }, NOW + 2, () => 0, 1);
    expect(spent.result).toMatchObject({ ok: true });
    expect(spent.state.careers.civ.perks.starYield).toBe(1);
    const after = tick(spent.state, SHARED(), NOW + 3).state;
    expect(after.careers.civ.starPicks).toBe(PRESTIGE.max - 1);
    expect(after.careers.civ.prestige).toBe(PRESTIGE.max);
  });

  it("never hands out a twenty-sixth star: prestige is blocked at the cap", () => {
    const s = tick(cheating(), SHARED(), NOW + 1).state;
    const out = apply(s, SHARED(), { type: "prestige" }, NOW + 2, () => 0, 1);
    expect(out.result).toEqual({ ok: false, error: "Already at the top star" });
    expect(out.state.careers.civ.prestige).toBe(PRESTIGE.max);
  });

  it("cannot attune past a perk's own rank cap", () => {
    const s = withPerks(tick(cheating(), SHARED(), NOW + 1).state, { starYield: STAR_PERK.starYield.max });
    const out = apply(s, SHARED(), { type: "starperk", perkId: "starYield" }, NOW + 2, () => 0, 1);
    expect(out.result).toMatchObject({ ok: false });
  });

  it("leaves every other account at square one", () => {
    const t = tick(fresh(), SHARED(), NOW + 1);
    expect(t.state.careers.civ.prestige).toBe(0);
    expect(t.state.careers.civ.starPicks).toBe(0);
  });
});

describe("no rate limit", () => {
  const site = SITE.kav_apple;
  const click = (s: PlayerState, at: number) => apply(s, SHARED(), { type: "work", siteId: site.id }, at, () => 0.99, 1);

  it("takes a second click inside the gap", () => {
    const first = click(cheating(), NOW);
    expect(first.result).toMatchObject({ ok: true });
    const second = click(first.state, NOW + 1);
    expect(second.result).toMatchObject({ ok: true });
    expect(second.state.careers.civ.inventory.apple).toBe(site.yield * 2);
  });

  it("still refuses everyone else inside the gap", () => {
    const first = click(fresh(), NOW);
    expect(first.result).toMatchObject({ ok: true });
    expect(click(first.state, NOW + 1).result).toEqual({ ok: false, error: TOO_FAST });
  });

  it("lets everyone else through once the gap has passed", () => {
    const first = click(fresh(), NOW);
    expect(click(first.state, NOW + ACTION_GAP_MS).result).toMatchObject({ ok: true });
  });
});

describe("the wire is unchanged", () => {
  it("stamps the flags on the save but keeps them out of the snapshot", () => {
    const t = tick(cheating(), SHARED(), NOW + 1);
    expect(t.state.cheats).toEqual({ unlimitedStamina: true, maxPrestige: true, noRateLimit: true });
    const wire = snapshot(t.state, t.shared, EMPTY_WORLD, NOW + 1, true);
    expect(JSON.stringify(wire)).not.toContain("cheats");
    expect(wire.me.stamina).toBe(staminaMax(t.state.careers.civ));
    expect(wire.me.prestige).toBe(PRESTIGE.max);
  });
});
