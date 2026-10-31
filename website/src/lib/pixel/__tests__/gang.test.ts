// Gangs: found (level 5, $250,000), join (cap, private invite code), leave (lead passes to the
// longest-standing member, last one dissolves), kick, privacy, level from XP, half of every member's
// XP feeding the gang, and the reference's directory / card shapes.
import { describe, expect, it } from "vitest";
import { GANG } from "../content";
import { apply, gangCap, gangInvite, gangLevelFromXp } from "../engine";
import { gangCard, gangProfile } from "../view";
import type { GangRecord } from "../types";
import { EMPTY_WORLD, MIN, NOW, QUIET, STEAM, atLevel, err, fresh, noRng, ok, rngOf, seeded, shared, withCash } from "./helpers";

const SH = shared;
const other = "76561190000000002";
function gangOf(over: Partial<GangRecord> = {}): GangRecord {
  return { id: "cothergang01", name: "Other Gang", tag: "OG", leaderId: other, private: false, codeSeed: "seed", codeBumps: 0, xp: 0, createdAt: NOW - MIN, members: [{ steamId: other, joinedAt: NOW - MIN }], ...over };
}

describe("gangcreate", () => {
  it("costs $250,000 at level 5+, names 3-20 and tags 2-4 uppercased, unique; the founder leads; a join feed line", () => {
    const s = atLevel(withCash(fresh(), 250_000), 5);
    const r = ok(apply(s, SH(), { type: "gangcreate", name: "Night Crew", tag: "nc" }, NOW + 1, seeded(5)));
    const id = r.state.gangId!;
    expect(id).toMatch(/^c[0-9a-z]{12}$/);
    expect(r.shared.gangs[id]).toMatchObject({ id, name: "Night Crew", tag: "NC", leaderId: STEAM, private: false, codeBumps: 0, xp: 0, createdAt: NOW + 1, members: [{ steamId: STEAM, joinedAt: NOW + 1 }] });
    expect(r.state.careers.civ.cash).toBe(0);
    expect(r.result).toEqual({ ok: true, cash: -250_000 });
    expect(r.events).toEqual([{ kind: "join", text: "founded [NC] Night Crew" }]);
    expect(err(apply(atLevel(withCash(fresh(), 250_000), 4), SH(), { type: "gangcreate", name: "Night Crew", tag: "NC" }, NOW + 1, noRng))).toBe("Needs level 5.");
    expect(err(apply(atLevel(withCash(fresh(), 249_999), 5), SH(), { type: "gangcreate", name: "Night Crew", tag: "NC" }, NOW + 1, noRng))).toBe("Not enough cash.");
    expect(err(apply(s, SH(), { type: "gangcreate", name: "NC", tag: "NC" }, NOW + 1, noRng))).toBe("Gang name must be 3-20 characters.");
    expect(err(apply(s, SH(), { type: "gangcreate", name: "Night Crew", tag: "N" }, NOW + 1, noRng))).toBe("Tag must be 2-4 letters or digits.");
    expect(err(apply(s, SH({ gangs: { x: gangOf({ tag: "NC" }) } }), { type: "gangcreate", name: "Night Crew", tag: "NC" }, NOW + 1, noRng))).toBe("That tag is taken.");
    expect(err(apply(s, SH({ gangs: { x: gangOf({ name: "night crew" }) } }), { type: "gangcreate", name: "Night Crew", tag: "NX" }, NOW + 1, noRng))).toBe("That name is taken.");
    expect(err(apply(r.state, r.shared, { type: "gangcreate", name: "Another", tag: "AN" }, NOW + 500, noRng))).toBe("Leave your gang first.");
    expect(err(apply(atLevel(withCash(fresh({}, "cop"), 1e9), 5), SH(), { type: "gangcreate", name: "Night Crew", tag: "NC" }, NOW + 1, noRng))).toBe("Gangs are a civilian thing.");
  });
});

describe("gangjoin / gangleave / gangkick / gangprivacy", () => {
  it("joins a public gang with a free slot; the cap is 5 + floor(level / 2) up to 10", () => {
    expect(gangCap(0)).toBe(5);
    expect(gangCap(3)).toBe(6);
    expect(gangCap(10)).toBe(10);
    const r = ok(apply(fresh(), SH({ gangs: { cothergang01: gangOf() } }), { type: "gangjoin", gangId: "cothergang01", code: "" }, NOW + 1, noRng));
    expect(r.state.gangId).toBe("cothergang01");
    expect(r.shared.gangs.cothergang01.members).toEqual([{ steamId: other, joinedAt: NOW - MIN }, { steamId: STEAM, joinedAt: NOW + 1 }]);
    expect(r.result).toEqual({ ok: true, message: "Joined [OG] Other Gang." });
    const full = gangOf({ members: Array.from({ length: 5 }, (_, i) => ({ steamId: `7656119800000000${i + 1}`, joinedAt: NOW })) });
    expect(err(apply(fresh(), SH({ gangs: { cothergang01: full } }), { type: "gangjoin", gangId: "cothergang01", code: "" }, NOW + 1, noRng))).toBe("Full — slots unlock as the gang levels");
    expect(err(apply(fresh(), SH(), { type: "gangjoin", gangId: "nope", code: "" }, NOW + 1, noRng))).toBe("That gang no longer exists.");
  });

  it("a private gang needs the current invite code, which rolls every 30 minutes and on every use", () => {
    const g = gangOf({ private: true });
    const invite = gangInvite(g, NOW + 1);
    expect(invite.code).toMatch(/^[A-Z2-9]{6}$/);
    expect(invite.expiresAt).toBe((Math.floor((NOW + 1) / GANG.inviteWindowMs) + 1) * GANG.inviteWindowMs);
    expect(gangInvite(g, NOW + 1).code).toBe(invite.code);
    expect(gangInvite(g, NOW + 1 + GANG.inviteWindowMs).code).not.toBe(invite.code);
    expect(gangInvite({ ...g, codeBumps: 1 }, NOW + 1).code).not.toBe(invite.code);
    expect(err(apply(fresh(), SH({ gangs: { cothergang01: g } }), { type: "gangjoin", gangId: "cothergang01", code: "WRONG1" }, NOW + 1, noRng))).toBe("Wrong invite code.");
    const r = ok(apply(fresh(), SH({ gangs: { cothergang01: g } }), { type: "gangjoin", gangId: "cothergang01", code: invite.code.toLowerCase() }, NOW + 1, noRng));
    expect(r.shared.gangs.cothergang01.codeBumps).toBe(1);
  });

  it("leaving passes the lead to the longest-standing member; the last member dissolves the gang", () => {
    const g = gangOf({ leaderId: STEAM, members: [{ steamId: STEAM, joinedAt: NOW - 3 * MIN }, { steamId: "76561190000000042", joinedAt: NOW - MIN }, { steamId: other, joinedAt: NOW - 2 * MIN }] });
    const r = ok(apply(fresh({ gangId: g.id }), SH({ gangs: { [g.id]: g } }), { type: "gangleave" }, NOW + 1, noRng));
    expect(r.state.gangId).toBeNull();
    expect(r.shared.gangs[g.id].leaderId).toBe(other);
    expect(r.shared.gangs[g.id].members.map((m) => m.steamId)).toEqual(["76561190000000042", other]);
    expect(r.result).toEqual({ ok: true, message: "Left [OG] Other Gang." });
    const solo = gangOf({ leaderId: STEAM, members: [{ steamId: STEAM, joinedAt: NOW }] });
    expect(ok(apply(fresh({ gangId: solo.id }), SH({ gangs: { [solo.id]: solo } }), { type: "gangleave" }, NOW + 1, noRng)).shared.gangs).toEqual({});
    expect(err(apply(fresh(), SH(), { type: "gangleave" }, NOW + 1, noRng))).toBe("You are not in a gang.");
  });

  it("only the leader kicks (never themselves) and sets privacy", () => {
    const g = gangOf({ leaderId: STEAM, members: [{ steamId: STEAM, joinedAt: NOW - MIN }, { steamId: other, joinedAt: NOW }] });
    const sh = SH({ gangs: { [g.id]: g } });
    const kicked = ok(apply(fresh({ gangId: g.id }), sh, { type: "gangkick", targetId: other }, NOW + 1, noRng));
    expect(kicked.shared.gangs[g.id].members.map((m) => m.steamId)).toEqual([STEAM]);
    expect(err(apply(fresh({ gangId: g.id }), sh, { type: "gangkick", targetId: STEAM }, NOW + 1, noRng))).toBe("You cannot kick yourself.");
    expect(err(apply(fresh({ gangId: g.id }), sh, { type: "gangkick", targetId: "76561190000000043" }, NOW + 1, noRng))).toBe("They are not in your gang.");
    const member = gangOf({ members: [{ steamId: other, joinedAt: NOW - MIN }, { steamId: STEAM, joinedAt: NOW }] });
    expect(err(apply(fresh({ gangId: member.id }), SH({ gangs: { [member.id]: member } }), { type: "gangkick", targetId: other }, NOW + 1, noRng))).toBe("Only the leader can kick.");
    expect(err(apply(fresh({ gangId: member.id }), SH({ gangs: { [member.id]: member } }), { type: "gangprivacy", private: true }, NOW + 1, noRng))).toBe("Only the leader can change this.");
    const priv = ok(apply(fresh({ gangId: g.id }), sh, { type: "gangprivacy", private: true }, NOW + 1, noRng));
    expect(priv.shared.gangs[g.id].private).toBe(true);
    expect(priv.result).toEqual({ ok: true, message: "Gang set to private." });
  });
});

describe("gang level, bonuses and the wire shapes", () => {
  it("gangLevelFromXp walks GANG.xpCurve and caps at 10 with xpNeeded 0", () => {
    expect(gangLevelFromXp(0)).toEqual({ level: 1, xpInto: 0, xpNeeded: 6000 });
    expect(gangLevelFromXp(6000)).toEqual({ level: 2, xpInto: 0, xpNeeded: 25723 - 6000 });
    expect(gangLevelFromXp(37_595_820)).toEqual({ level: 10, xpInto: 0, xpNeeded: 0 });
  });

  it("half of every member XP gain feeds the gang; the card and the profile carry the reference fields", () => {
    const g = gangOf({ leaderId: STEAM, members: [{ steamId: STEAM, joinedAt: NOW - MIN }, { steamId: other, joinedAt: NOW }] });
    const r = ok(apply(fresh({ gangId: g.id }), SH({ gangs: { [g.id]: g } }), { type: "work", siteId: "kav_apple" }, NOW + 1, rngOf(...QUIET)));
    expect(r.shared.gangs[g.id].xp).toBe(3);
    const world = { ...EMPTY_WORLD, gangMembers: { [STEAM]: { name: "Tester", level: 1, prestige: 0, online: true }, [other]: { name: "Player1", level: 47, prestige: 14, online: false } } };
    const card = gangCard(r.state, r.shared, world, NOW + 1)!;
    expect(card).toMatchObject({ id: g.id, name: "Other Gang", tag: "OG", level: 1, xp: 3, xpInto: 3, xpNeeded: 6000, cap: 5, yieldBonus: 0.01, xpBonus: 0.01, isLeader: true, isPrivate: false, inviteCode: null });
    expect(card.members).toEqual([
      { steamId: STEAM, name: "Tester", level: 1, prestige: 0, leader: true, online: true },
      { steamId: other, name: "Player1", level: 47, prestige: 14, leader: false, online: false },
    ]);
    expect(gangCard(fresh({ gangId: g.id }), SH({ gangs: { [g.id]: { ...g, private: true } } }), world, NOW + 1)!.inviteCode).toBe(gangInvite(g, NOW + 1).code);
    const profile = gangProfile(r.shared, g.id, other, world.gangMembers)!;
    expect(Object.keys(profile).sort()).toEqual(["cap", "createdAt", "id", "isMine", "leaderName", "level", "members", "name", "private", "tag", "xp", "xpBonus", "xpInto", "xpNeeded", "yieldBonus"]);
    expect(profile).toMatchObject({ leaderName: "Tester", isMine: true, createdAt: NOW - MIN });
    expect(gangProfile(r.shared, "nope", other, {})).toBeNull();
  });

  it("reset leaves the gang (dissolving it when alone)", () => {
    const solo = gangOf({ leaderId: STEAM, members: [{ steamId: STEAM, joinedAt: NOW }] });
    expect(ok(apply(fresh({ gangId: solo.id }), SH({ gangs: { [solo.id]: solo } }), { type: "reset" }, NOW + 1, noRng)).shared.gangs).toEqual({});
  });
});
