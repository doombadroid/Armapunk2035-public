// The anti-automation checkpoint ("Tap the {target}"): issued every 150 work clicks, everything
// else waits until `verify {id, answer}` clears it, three misses lock it for a minute and roll a
// fresh one, and the hidden "Claim free cash" button (`hp`) locks the account for ten minutes.
import { describe, expect, it } from "vitest";
import { CHECKPOINT_ICONS, INFERRED } from "../content";
import { apply } from "../engine";
import { newCheckpoint } from "../minigames";
import { snapshot } from "../view";
import type { PlayerState } from "../types";
import { EMPTY_WORLD, NOW, QUIET, err, fresh, noRng, ok, rngOf, seeded, shared, withBag } from "./helpers";

const SH = shared;

function clicks(n: number, start: PlayerState = fresh()): PlayerState {
  let s = start;
  for (let i = 0; i < n; i++) s = ok(apply(withBag({ ...s, lastActionAt: 0, stamina: 100 }, {}), SH(), { type: "work", siteId: "kav_apple" }, NOW + 1, rngOf(...QUIET))).state;
  return s;
}

describe("checkpoint", () => {
  it("newCheckpoint picks a target among three distinct icons from the pool", () => {
    const cp = newCheckpoint(seeded(8));
    expect(cp.options).toHaveLength(3);
    expect(new Set(cp.options).size).toBe(3);
    expect(cp.options).toContain(cp.target);
    for (const o of cp.options) expect(CHECKPOINT_ICONS).toContain(o);
    expect(cp).toMatchObject({ lockedUntil: 0, misses: 0 });
  });

  it("the 150th work click issues a checkpoint (drawn from the rng after the click's own rolls) and every other action waits", () => {
    const s = clicks(INFERRED.checkpointEveryClicks - 1);
    expect(s.checkpoint).toBeNull();
    expect(s.checkpointClicks).toBe(149);
    const due = { ...withBag(s, {}), lastActionAt: 0 };
    expect(() => apply(due, SH(), { type: "work", siteId: "kav_apple" }, NOW + 1, rngOf(...QUIET))).toThrow("rng exhausted");
    const r = ok(apply(due, SH(), { type: "work", siteId: "kav_apple" }, NOW + 1, seeded(3)));
    expect(r.state.checkpoint).not.toBeNull();
    expect(r.state.checkpointClicks).toBe(0);
    const v = snapshot(r.state, SH(), EMPTY_WORLD, NOW + 1, false).me.checkpoint!;
    expect(Object.keys(v).sort()).toEqual(["id", "lockedUntil", "options", "target"]);
    expect(err(apply(r.state, SH(), { type: "work", siteId: "kav_apple" }, NOW + 500, noRng))).toBe("Answer the checkpoint first.");
    expect(err(apply(r.state, SH(), { type: "travel", cityId: "neochori" }, NOW + 500, noRng))).toBe("Answer the checkpoint first.");
    expect(apply(r.state, SH(), { type: "chat", text: "brb" }, NOW + 500, noRng).result.ok).toBe(true);
  });

  it("verify clears it on the right icon; misses are kept even though the answer is refused; three misses lock for a minute with a fresh checkpoint", () => {
    const s = clicks(INFERRED.checkpointEveryClicks - 1);
    const issued = ok(apply({ ...withBag(s, {}), lastActionAt: 0 }, SH(), { type: "work", siteId: "kav_apple" }, NOW + 1, seeded(3))).state;
    const cp = issued.checkpoint!;
    const wrong = cp.options.find((o) => o !== cp.target)!;
    expect(err(apply(issued, SH(), { type: "verify", id: "nope", answer: cp.target }, NOW + 500, noRng))).toBe("That checkpoint has expired.");
    const cleared = ok(apply(issued, SH(), { type: "verify", id: cp.id, answer: cp.target }, NOW + 500, noRng));
    expect(cleared.state.checkpoint).toBeNull();
    expect(cleared.result).toEqual({ ok: true });
    let s2 = issued;
    for (let i = 1; i <= 2; i++) {
      const r = apply({ ...s2, lastActionAt: 0 }, SH(), { type: "verify", id: cp.id, answer: wrong }, NOW + 500, noRng);
      expect(r.result).toEqual({ ok: false, error: "Wrong one. Try again." });
      expect(r.state.checkpoint!.misses).toBe(i);
      s2 = r.state;
    }
    const third = apply({ ...s2, lastActionAt: 0 }, SH(), { type: "verify", id: cp.id, answer: wrong }, NOW + 500, seeded(5));
    expect(third.result).toEqual({ ok: false, error: "Too many misses. A fresh checkpoint opens when the timer runs out." });
    const next = third.state.checkpoint!;
    expect(next.id).not.toBe(cp.id);
    expect(next).toMatchObject({ lockedUntil: NOW + 500 + INFERRED.checkpointLockMs, misses: 0 });
    expect(err(apply({ ...third.state, lastActionAt: 0 }, SH(), { type: "verify", id: next.id, answer: next.target }, NOW + 1000, noRng))).toBe("Too many misses. A fresh checkpoint opens when the timer runs out.");
    expect(err(apply({ ...third.state, lastActionAt: 0 }, SH(), { type: "work", siteId: "kav_apple" }, NOW + 1000, noRng))).toBe("Answer the checkpoint first.");
    const after = ok(apply({ ...third.state, lastActionAt: 0 }, SH(), { type: "verify", id: next.id, answer: next.target }, NOW + 500 + INFERRED.checkpointLockMs, noRng));
    expect(after.state.checkpoint).toBeNull();
    expect(ok(apply(after.state, SH(), { type: "work", siteId: "kav_apple" }, NOW + 500 + INFERRED.checkpointLockMs + 300, rngOf(...QUIET))).result.gained).toEqual({ apple: 12 });
  });

  it("the honeypot locks every activity for ten minutes and says so", () => {
    const r = ok(apply(fresh(), SH(), { type: "hp" }, NOW + 1, noRng));
    expect(r.state.activityLockUntil).toBe(NOW + 1 + INFERRED.honeypotLockMs);
    expect(r.result).toEqual({ ok: true });
    expect(err(apply(r.state, SH(), { type: "work", siteId: "kav_apple" }, NOW + 500, noRng))).toBe("Locked out. Try again in 600s.");
    expect(ok(apply(r.state, SH(), { type: "work", siteId: "kav_apple" }, NOW + 1 + INFERRED.honeypotLockMs, rngOf(...QUIET))).result.gained).toEqual({ apple: 12 });
  });
});
