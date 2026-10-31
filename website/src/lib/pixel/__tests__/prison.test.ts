// Custody: an arrest seizes the contraband and sets a sentence; bail starts above the fine and gets
// cheaper as time is served; the prison workshop (3x3 pipes, inlet left of tile 0, outlet right of
// tile 8) shaves seconds off after the first minute; everything else waits in custody. Reachable
// only through a pursuit, so the tests jail the player directly.
import { describe, expect, it } from "vitest";
import { INFERRED } from "../content";
import { apply, custodyCredit, jailPlayer, releaseCost, tick } from "../engine";
import { PIPE, newPrisonJob, pipesSolved, rotateTile } from "../minigames";
import { snapshot } from "../view";
import type { PlayerState } from "../types";
import { EMPTY_WORLD, NOW, err, fresh, noRng, ok, seeded, shared, withBag, withCash } from "./helpers";

const SH = shared;

function jailed(heat = 20, cash = 1e6): PlayerState {
  const s = withCash(withBag(fresh({ heat }), { marijuana: 10, apple: 3 }), cash);
  jailPlayer(s, NOW, seeded(1));
  return s;
}

describe("arrest and bail", () => {
  it("jailPlayer seizes every illegal item, clears the heat, counts the bust and sets a sentence of 120 + 3 s per heat", () => {
    const s = jailed(20);
    expect(s.careers.civ.inventory).toEqual({ apple: 3 });
    expect(s.heat).toBe(0);
    expect(s.stats.timesBusted).toBe(1);
    expect(s.arrestFine).toBe(2535);
    expect(s.custody).toMatchObject({ startedAt: NOW, jailedUntil: NOW + 180_000, sentenceMs: 180_000, fine: 2535, creditedSeconds: 0, job: null });
    expect(s.custody!.id).toMatch(/^[0-9a-f-]{36}$/);
  });

  it("releaseCost starts at 1.5x the fine and falls to the fine as the sentence is served; release pays it", () => {
    const s = jailed(20);
    expect(releaseCost(s.custody!, NOW)).toBe(Math.round(2535 * 1.5));
    expect(releaseCost(s.custody!, NOW + 90_000)).toBe(Math.round(2535 * 1.25));
    expect(releaseCost(s.custody!, NOW + 180_000)).toBe(2535);
    const v = snapshot(s, SH(), EMPTY_WORLD, NOW, false).me;
    expect(v.jailedUntil).toBe(NOW + 180_000);
    expect(v.bailCost).toBe(Math.round(2535 * 1.5));
    expect(v.custody).toEqual({ id: s.custody!.id, releaseCost: Math.round(2535 * 1.5), job: null, availableCreditSeconds: 0, workRemainingSeconds: 90 });
    const cost = releaseCost(s.custody!, NOW + 1);
    const r = ok(apply(s, SH(), { type: "release" }, NOW + 1, noRng));
    expect(r.state.custody).toBeNull();
    expect(r.state.careers.civ.cash).toBe(1e6 - cost);
    expect(r.result).toEqual({ ok: true, cash: -cost, message: "Released." });
    expect(err(apply(jailed(20, 10), SH(), { type: "release" }, NOW + 1, noRng))).toBe(`You are $${(cost - 10).toLocaleString("en-US")} short.`);
    expect(err(apply(fresh(), SH(), { type: "release" }, NOW + 1, noRng))).toBe("You are not in custody.");
  });

  it("in custody every ordinary action waits; the sentence ends by tick; paying the record off is not available", () => {
    const s = jailed(20);
    expect(err(apply(s, SH(), { type: "work", siteId: "kav_apple" }, NOW + 1, noRng))).toBe("You are in custody.");
    expect(err(apply(s, SH(), { type: "travel", cityId: "neochori" }, NOW + 1, noRng))).toBe("You are in custody.");
    expect(err(apply(s, SH(), { type: "payheat" }, NOW + 1, noRng))).toBe("You are in custody.");
    expect(tick(s, SH(), NOW + 179_999).state.custody).not.toBeNull();
    expect(tick(s, SH(), NOW + 180_000).state.custody).toBeNull();
  });
});

describe("prison workshop", () => {
  it("rotateTile turns a quarter clockwise and pipesSolved follows the bits from the inlet to the outlet", () => {
    expect(rotateTile(PIPE.N)).toBe(PIPE.E);
    expect(rotateTile(PIPE.W)).toBe(PIPE.N);
    expect(rotateTile(PIPE.N | PIPE.S)).toBe(PIPE.E | PIPE.W);
    const straight = [PIPE.W | PIPE.E, PIPE.W | PIPE.E, PIPE.W | PIPE.S, 0, 0, PIPE.N | PIPE.S, 0, 0, PIPE.N | PIPE.E];
    expect(pipesSolved(straight)).toBe(true);
    expect(pipesSolved([...straight.slice(0, 8), PIPE.N | PIPE.W])).toBe(false);
    expect(pipesSolved([PIPE.E, ...straight.slice(1)])).toBe(false);
  });

  it("newPrisonJob is always solvable by rotations and ready 20 s later", () => {
    for (let seed = 1; seed <= 20; seed++) {
      const job = newPrisonJob(seeded(seed), NOW, 20);
      expect(job.tiles).toHaveLength(9);
      expect(job.readyAt).toBe(NOW + 20_000);
      expect(solve(job.tiles)).not.toBeNull();
    }
  });

  it("prisonstart needs the first 60 s served; the job is worth min(45, remaining) seconds; a solved repair takes them off the sentence", () => {
    const s = jailed(20);
    expect(err(apply(s, SH(), { type: "prisonstart" }, NOW + 59_000, noRng))).toBe("No eligible work time yet — the first 60 seconds of any sentence must be served.");
    expect(custodyCredit(s, NOW + 60_000)).toEqual({ availableCreditSeconds: 45, workRemainingSeconds: 90 });
    const started = ok(apply(s, SH(), { type: "prisonstart" }, NOW + 60_000, seeded(4)));
    const job = started.state.custody!.job!;
    expect(job.tiles).toHaveLength(9);
    const ids = { custodyId: s.custody!.id, jobId: job.id };
    expect(err(apply(started.state, SH(), { type: "prisonstart" }, NOW + 60_500, noRng))).toBe("A work detail is already running.");
    expect(err(apply(started.state, SH(), { type: "prisoncomplete", ...ids }, NOW + 61_000, noRng))).toBe("Working... 19s");
    expect(err(apply(started.state, SH(), { type: "prisonrotate", custodyId: "x", jobId: job.id, tile: 0 }, NOW + 61_000, noRng))).toBe("No such work detail.");
    let cur = started.state;
    const turns = solve(job.tiles)!;
    let t = NOW + 61_000;
    turns.forEach((n, tile) => {
      for (let k = 0; k < n; k++) {
        t += 300;
        cur = ok(apply(cur, SH(), { type: "prisonrotate", ...ids, tile }, t, noRng)).state;
      }
    });
    expect(pipesSolved(cur.custody!.job!.tiles)).toBe(true);
    const done = ok(apply(cur, SH(), { type: "prisoncomplete", ...ids }, NOW + 80_000, noRng));
    expect(done.result).toEqual({ ok: true, message: "Repair accepted. 45s off your sentence." });
    expect(done.state.custody).toMatchObject({ jailedUntil: NOW + 180_000 - 45_000, creditedSeconds: 45, job: null });
    expect(custodyCredit(done.state, NOW + 80_000)).toEqual({ availableCreditSeconds: 45, workRemainingSeconds: 45 });
    const again = ok(apply(done.state, SH(), { type: "prisonstart" }, NOW + 81_000, seeded(6)));
    const job2 = again.state.custody!.job!;
    let cur2 = again.state;
    let t2 = NOW + 82_000;
    solve(job2.tiles)!.forEach((n, tile) => {
      for (let k = 0; k < n; k++) {
        t2 += 300;
        cur2 = ok(apply(cur2, SH(), { type: "prisonrotate", custodyId: ids.custodyId, jobId: job2.id, tile }, t2, noRng)).state;
      }
    });
    const done2 = ok(apply(cur2, SH(), { type: "prisoncomplete", custodyId: ids.custodyId, jobId: job2.id }, NOW + 102_000, noRng));
    expect(done2.result).toEqual({ ok: true, message: "Repair accepted. 45s off your sentence." });
    expect(done2.state.custody).toBeNull();
    const capped = jailed(20);
    capped.custody!.creditedSeconds = 90;
    expect(custodyCredit(capped, NOW + 100_000)).toEqual({ availableCreditSeconds: 0, workRemainingSeconds: 0 });
    expect(err(apply(capped, SH(), { type: "prisonstart" }, NOW + 100_000, noRng))).toBe("You've worked off as much of this sentence as the rules allow — ride out the rest, or pay to leave.");
  });

  it("a leaking repair costs nothing and can be retried; a repair that ends the sentence releases", () => {
    const s = jailed(20);
    const started = ok(apply(s, SH(), { type: "prisonstart" }, NOW + 60_000, seeded(4)));
    const job = started.state.custody!.job!;
    let cur = started.state;
    if (pipesSolved(job.tiles)) cur = ok(apply(cur, SH(), { type: "prisonrotate", custodyId: s.custody!.id, jobId: job.id, tile: 0 }, NOW + 61_000, noRng)).state;
    const leak = ok(apply(cur, SH(), { type: "prisoncomplete", custodyId: s.custody!.id, jobId: job.id }, NOW + 80_000, noRng));
    expect(leak.result).toEqual({ ok: true, message: "The pipes leak. Try again." });
    expect(leak.state.custody).toMatchObject({ creditedSeconds: 0, job: null });
    const late = ok(apply(leak.state, SH(), { type: "prisonstart" }, NOW + 150_000, seeded(4)));
    const job2 = late.state.custody!.job!;
    let cur2 = late.state;
    let t = NOW + 151_000;
    solve(job2.tiles)!.forEach((n, tile) => {
      for (let k = 0; k < n; k++) {
        t += 300;
        cur2 = ok(apply(cur2, SH(), { type: "prisonrotate", custodyId: s.custody!.id, jobId: job2.id, tile }, t, noRng)).state;
      }
    });
    const out = ok(apply(cur2, SH(), { type: "prisoncomplete", custodyId: s.custody!.id, jobId: job2.id }, NOW + 171_000, noRng));
    expect(out.state.custody).toBeNull();
    expect(INFERRED.prisonJobCreditSeconds).toBe(45);
  });
});

/** Quarter turns per tile that solve the puzzle, by exhaustive search (4^9), or null. */
function solve(tiles: number[]): number[] | null {
  const turns = new Array(9).fill(0);
  const cur = [...tiles];
  const rec = (i: number): boolean => {
    if (i === 9) return pipesSolved(cur);
    const base = cur[i];
    for (let k = 0; k < 4; k++) {
      cur[i] = base;
      for (let r = 0; r < k; r++) cur[i] = rotateTile(cur[i]);
      turns[i] = k;
      if (rec(i + 1)) return true;
    }
    cur[i] = base;
    return false;
  };
  return rec(0) ? turns : null;
}
