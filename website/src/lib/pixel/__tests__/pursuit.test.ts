// Pursuits need an officer and a civilian, so alone they never start; the state machine still has
// to answer with the reference's own strings and to render: newDuelPair shapes the duel, ready /
// answer / surrender drive the player's side, the deadlines resolve by tick, a civilian capture is
// an arrest.
import { describe, expect, it } from "vitest";
import { INFERRED } from "../content";
import { apply, newDuelPair, tick } from "../engine";
import { routeScore } from "../minigames";
import { snapshot } from "../view";
import { EMPTY_WORLD, NOW, STEAM, err, fresh, noRng, ok, seeded, shared, withBag } from "./helpers";

const SH = shared;
const pair = () => newDuelPair({ id: "76561190000000002", name: "Officer" }, { id: STEAM, name: "Tester" }, seeded(12), NOW);

describe("pursuit", () => {
  it("newDuelPair mirrors one pursuit for both sides with three route rounds and a 30 s ready window", () => {
    const d = pair();
    expect(d.cop.id).toBe(d.civ.id);
    expect(d.cop.rounds).toEqual(d.civ.rounds);
    expect(d.civ).toMatchObject({ role: "civ", opponentId: "76561190000000002", opponentName: "Officer", status: "pending", readyUntil: NOW + INFERRED.duelReadyMs, startsAt: 0, until: 0, myAnswers: [], opponentAnswers: [], myReady: false, opponentReady: false, outcome: null, reason: null });
    expect(d.cop).toMatchObject({ role: "cop", opponentName: "Tester" });
    expect(d.civ.rounds).toHaveLength(3);
    expect(d.civ.rounds[2].prompt).toBe("Checkpoint 3: choose the lowest total route cost.");
    expect(d.civ.rounds[0].options.map((o) => o.label)).toEqual(["Left street", "Center street", "Right street"]);
    const v = snapshot(fresh({ duel: d.civ }), SH(), EMPTY_WORLD, NOW, false).me.duel!;
    expect(Object.keys(v).sort()).toEqual(["id", "myAnswers", "myReady", "opponentAnswers", "opponentName", "opponentReady", "outcome", "readyUntil", "reason", "role", "rounds", "startsAt", "status", "until"]);
  });

  it("without a pursuit every pursuit action answers `No active pursuit.`; a stale id answers `That pursuit is over.`", () => {
    expect(err(apply(fresh(), SH(), { type: "pursuitready", id: "x" }, NOW + 1, noRng))).toBe("No active pursuit.");
    expect(err(apply(fresh(), SH(), { type: "pursuitanswer", id: "x", round: 0, choice: 0 }, NOW + 1, noRng))).toBe("No active pursuit.");
    expect(err(apply(fresh(), SH(), { type: "pursuitsurrender", id: "x" }, NOW + 1, noRng))).toBe("No active pursuit.");
    expect(err(apply(fresh({ duel: pair().civ }), SH(), { type: "pursuitready", id: "x" }, NOW + 1, noRng))).toBe("That pursuit is over.");
  });

  it("ready marks the player's side; both ready start the run 3 s later with a 45 s window; answers score per checkpoint", () => {
    const d = pair().civ;
    const r = ok(apply(fresh({ duel: d }), SH(), { type: "pursuitready", id: d.id }, NOW + 1, noRng));
    expect(r.state.duel).toMatchObject({ myReady: true, status: "pending" });
    expect(err(apply(r.state, SH(), { type: "pursuitanswer", id: d.id, round: 0, choice: 0 }, NOW + 500, noRng))).toBe("The pursuit has not started.");
    const both = ok(apply(fresh({ duel: { ...d, opponentReady: true } }), SH(), { type: "pursuitready", id: d.id }, NOW + 1, noRng));
    expect(both.state.duel).toMatchObject({ status: "active", startsAt: NOW + 1 + 3000, until: NOW + 1 + 3000 + 45_000 });
    expect(err(apply(both.state, SH(), { type: "pursuitanswer", id: d.id, round: 0, choice: 0 }, NOW + 500, noRng))).toBe("Get ready. The pursuit has not started.");
    const a = ok(apply(both.state, SH(), { type: "pursuitanswer", id: d.id, round: 0, choice: 1 }, NOW + 5000, noRng));
    expect(a.state.duel!.myAnswers).toEqual([{ choice: 1, score: routeScore(d.rounds[0], 1) }]);
    expect(err(apply(a.state, SH(), { type: "pursuitanswer", id: d.id, round: 0, choice: 1 }, NOW + 5500, noRng))).toBe("Answer the checkpoints in order.");
  });

  it("routeScore gives 100 to the cheapest street and 0 to the dearest", () => {
    const round = { id: "r", prompt: "", obstacleCost: 5, options: [{ label: "Left street", distance: 6, obstacles: 4 }, { label: "Center street", distance: 16, obstacles: 2 }, { label: "Right street", distance: 10, obstacles: 3 }] };
    expect(round.options.map((_, i) => routeScore(round, i))).toEqual([0, 0, 100]);
    expect(routeScore({ ...round, options: [{ label: "a", distance: 5, obstacles: 0 }, { label: "b", distance: 10, obstacles: 0 }, { label: "c", distance: 15, obstacles: 0 }] }, 1)).toBe(50);
  });

  it("a civilian who does not ready up in time is taken into custody; a surrender is a capture too", () => {
    const d = pair().civ;
    const s = withBag(fresh({ duel: d, heat: 30 }), { marijuana: 4 });
    const late = tick(s, SH(), NOW + INFERRED.duelReadyMs).state;
    expect(late.duel).toMatchObject({ status: "resolved", outcome: "capture", reason: "Civilian did not ready up in time and was taken into custody." });
    expect(late.custody).not.toBeNull();
    expect(late.careers.civ.inventory).toEqual({});
    expect(late.stats.timesBusted).toBe(1);
    const sur = ok(apply(s, SH(), { type: "pursuitsurrender", id: d.id }, NOW + 1, seeded(2)));
    expect(sur.state.duel).toMatchObject({ status: "resolved", outcome: "capture" });
    expect(sur.state.custody).not.toBeNull();
    expect(err(apply(fresh({ duel: pair().cop }, "cop"), SH(), { type: "pursuitsurrender", id: d.id }, NOW + 1, noRng))).toBe("Officers do not surrender.");
  });

  it("an active run settles at the deadline: higher total wins, a tie escapes", () => {
    const d = { ...pair().civ, status: "active" as const, startsAt: NOW, until: NOW + 45_000, myReady: true, opponentReady: true };
    const tie = tick(fresh({ duel: { ...d, myAnswers: [{ choice: 0, score: 50 }], opponentAnswers: [{ choice: 0, score: 50 }] } }), SH(), NOW + 45_000).state;
    expect(tie.duel).toMatchObject({ status: "resolved", outcome: "escape" });
    expect(tie.stats.timesFled).toBe(1);
    const lost = tick(fresh({ duel: { ...d, myAnswers: [{ choice: 0, score: 10 }], opponentAnswers: [{ choice: 0, score: 90 }] } }), SH(), NOW + 45_000).state;
    expect(lost.duel).toMatchObject({ status: "resolved", outcome: "capture" });
    expect(lost.custody).not.toBeNull();
    const won = tick(fresh({ duel: { ...pair().cop, status: "active", startsAt: NOW, until: NOW + 45_000, myAnswers: [{ choice: 0, score: 90 }], opponentAnswers: [{ choice: 0, score: 10 }] } }, "cop"), SH(), NOW + 45_000).state;
    expect(won.duel).toMatchObject({ outcome: "capture" });
    expect(won.stats.busts).toBe(1);
  });

  it("an officer who does not ready up cancels the pursuit with no penalty", () => {
    const late = tick(fresh({ duel: pair().cop }, "cop"), SH(), NOW + INFERRED.duelReadyMs).state;
    expect(late.duel).toMatchObject({ status: "resolved", outcome: "cancelled" });
    expect(late.custody).toBeNull();
  });
});
