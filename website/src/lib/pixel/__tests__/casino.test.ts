// The casino with a scripted rng: blackjack (dealer stands on 17, natural 3:2, push returns the
// bet), the slot paytable (7s pay 25x), single-zero roulette payouts, the poker evaluator and a
// two-seat showdown, and the cash bookkeeping of every wager.
import { describe, expect, it } from "vitest";
import { bestOfSeven, blackjackHit, blackjackScore, blackjackStand, compareScores, newDeck, pokerShowdown, roulettePayout, rouletteColor, scoreFive, slotsPayout, spinRoulette, spinSlots } from "../casino";
import { apply } from "../engine";
import { casinoWire } from "../view";
import type { BlackjackHand } from "../types";
import { NOW, STEAM, err, fresh, noRng, ok, rngOf, seeded, shared, withCash } from "./helpers";

const SH = shared;
const hand = (over: Partial<BlackjackHand>): BlackjackHand => ({ deck: ["2C", "9D", "5H", "KS"], dealerCards: ["7S", "9H"], playerCards: ["10D", "8C"], status: "playing", bet: 100, payout: 0, ...over });

describe("blackjack", () => {
  it("scores aces as 11 while that does not bust", () => {
    expect(blackjackScore(["AS", "KD"])).toBe(21);
    expect(blackjackScore(["AS", "AD", "9C"])).toBe(21);
    expect(blackjackScore(["AS", "9C", "5D"])).toBe(15);
    expect(blackjackScore(["10H", "JD", "2C"])).toBe(22);
  });

  it("hit draws from the deck top; a bust loses; stand makes the dealer draw to 17 and settles 2x / push / 0", () => {
    const h = blackjackHit(hand({}));
    expect(h.playerCards).toEqual(["10D", "8C", "KS"]);
    expect(h.status).toBe("lost");
    const stand = blackjackStand(hand({ dealerCards: ["7S", "9H"], deck: ["AS"] }));
    expect(stand.dealerCards).toEqual(["7S", "9H", "AS"]);
    expect(stand).toMatchObject({ status: "won", payout: 200 });
    expect(blackjackStand(hand({ dealerCards: ["7S", "9H"], deck: ["2C"] }))).toMatchObject({ status: "push", payout: 100 });
    expect(blackjackStand(hand({ dealerCards: ["9S", "9H"] }))).toMatchObject({ status: "push", payout: 100 });
    expect(blackjackStand(hand({ dealerCards: ["10S", "9H"] }))).toMatchObject({ status: "lost", payout: 0 });
    expect(blackjackStand(hand({ dealerCards: ["6S", "9H"], deck: ["KS"] }))).toMatchObject({ status: "won", payout: 200 });
    expect(blackjackStand(hand({ dealerCards: ["AS", "6H"] })).dealerCards).toEqual(["AS", "6H"]);
  });

  it("blackjackdeal {bet} takes the wager, hit and stand settle into cash; the wire hides the hole card while playing", () => {
    const s = withCash(fresh(), 1000);
    const r = ok(apply(s, SH(), { type: "blackjackdeal", bet: 100 }, NOW + 1, seeded(4)));
    const h = r.state.blackjack!;
    expect(h.bet).toBe(100);
    expect(h.playerCards).toHaveLength(2);
    expect(h.dealerCards).toHaveLength(2);
    expect(h.deck).toHaveLength(48);
    expect(r.state.careers.civ.cash + (h.status === "playing" ? 100 : 100 - h.payout)).toBe(1000);
    if (h.status === "playing") {
      const wire = casinoWire(r.state, SH()).blackjack!;
      expect(wire.dealerCards).toEqual([h.dealerCards[0], null]);
      expect(wire.dealerScore).toBeNull();
      expect(wire.playerScore).toBe(blackjackScore(h.playerCards));
      expect(err(apply(r.state, SH(), { type: "blackjackdeal", bet: 100 }, NOW + 500, noRng))).toBe("Finish the hand first.");
      const stood = ok(apply(r.state, SH(), { type: "blackjackstand" }, NOW + 500, noRng));
      const done = stood.state.blackjack!;
      expect(done.status).not.toBe("playing");
      expect(stood.state.careers.civ.cash).toBe(900 + done.payout);
      expect(casinoWire(stood.state, SH()).blackjack!.dealerScore).toBe(blackjackScore(done.dealerCards));
      expect(stood.result.message).toBe(done.status === "won" ? "You won the hand." : done.status === "push" ? "Push." : "Dealer won.");
    }
    expect(err(apply(fresh(), SH(), { type: "blackjackhit" }, NOW + 1, noRng))).toBe("No hand in play.");
    expect(err(apply(withCash(fresh(), 50), SH(), { type: "blackjackdeal", bet: 100 }, NOW + 1, noRng))).toBe("Not enough cash.");
    expect(err(apply(withCash(fresh(), 50), SH(), { type: "blackjackdeal", bet: 0 }, NOW + 1, noRng))).toBe("Bad wager.");
  });

  it("a natural pays 3:2 at once", () => {
    let dealt: BlackjackHand | null = null;
    for (let seed = 1; seed < 400 && !dealt; seed++) {
      const r = ok(apply(withCash(fresh(), 1000), SH(), { type: "blackjackdeal", bet: 100 }, NOW + 1, seeded(seed)));
      if (blackjackScore(r.state.blackjack!.playerCards) === 21) dealt = r.state.blackjack;
    }
    expect(dealt).not.toBeNull();
    expect(dealt!.status === "push" ? dealt!.payout : dealt!.payout).toBe(dealt!.status === "push" ? 100 : 250);
  });
});

describe("slots", () => {
  it("pays 25x on 7-7-7, the INFERRED paytable otherwise, 1x on two cherries, nothing else", () => {
    expect(slotsPayout(["7", "7", "7"], 10)).toBe(250);
    expect(slotsPayout(["BAR", "BAR", "BAR"], 10)).toBe(100);
    expect(slotsPayout(["BELL", "BELL", "BELL"], 10)).toBe(60);
    expect(slotsPayout(["CHERRY", "CHERRY", "CHERRY"], 10)).toBe(40);
    expect(slotsPayout(["CHERRY", "BAR", "CHERRY"], 10)).toBe(10);
    expect(slotsPayout(["CHERRY", "BAR", "BELL"], 10)).toBe(0);
  });

  it("spinSlots reads three reels off the strip; slots {bet} nets the difference into cash and returns result.casino", () => {
    expect(spinSlots(rngOf(0.93, 0.93, 0.93), 10)).toEqual({ reels: ["7", "7", "7"], bet: 10, payout: 250 });
    const r = ok(apply(withCash(fresh(), 100), SH(), { type: "slots", bet: 10 }, NOW + 1, rngOf(0.93, 0.93, 0.93)));
    expect(r.state.careers.civ.cash).toBe(340);
    expect(r.result).toEqual({ ok: true, cash: 240, casino: { reels: ["7", "7", "7"], bet: 10, payout: 250 } });
    const lose = ok(apply(withCash(fresh(), 100), SH(), { type: "slots", bet: 10 }, NOW + 1, rngOf(0, 0.5, 0.8)));
    expect(lose.state.careers.civ.cash).toBe(90);
    expect(lose.result).toEqual({ ok: true, cash: -10, casino: { reels: ["CHERRY", "BAR", "BELL"], bet: 10, payout: 0 } });
    expect(err(apply(withCash(fresh(), 5), SH(), { type: "slots", bet: 10 }, NOW + 1, noRng))).toBe("Not enough cash.");
  });
});

describe("roulette", () => {
  it("colours a single-zero wheel and pays 2x on colour / parity, 36x on green or the exact number", () => {
    expect(rouletteColor(0)).toBe("green");
    expect(rouletteColor(1)).toBe("red");
    expect(rouletteColor(2)).toBe("black");
    expect(rouletteColor(19)).toBe("red");
    expect(roulettePayout(1, 10, "red", 0)).toBe(20);
    expect(roulettePayout(2, 10, "red", 0)).toBe(0);
    expect(roulettePayout(2, 10, "even", 0)).toBe(20);
    expect(roulettePayout(0, 10, "even", 0)).toBe(0);
    expect(roulettePayout(3, 10, "odd", 0)).toBe(20);
    expect(roulettePayout(0, 10, "green", 0)).toBe(360);
    expect(roulettePayout(17, 10, "number", 17)).toBe(360);
    expect(roulettePayout(18, 10, "number", 17)).toBe(0);
  });

  it("roulette {bet, choice, number} spins with the rng and nets into cash; the result carries number and colour", () => {
    expect(spinRoulette(rngOf(17.5 / 37), 10, "number", 17)).toEqual({ number: 17, color: "black", bet: 10, payout: 360 });
    const r = ok(apply(withCash(fresh(), 100), SH(), { type: "roulette", bet: 10, choice: "number", number: 17 }, NOW + 1, rngOf(17.5 / 37)));
    expect(r.state.careers.civ.cash).toBe(450);
    expect(r.result).toEqual({ ok: true, cash: 350, casino: { number: 17, color: "black", bet: 10, payout: 360 } });
    const push = ok(apply(withCash(fresh(), 100), SH(), { type: "roulette", bet: 10, choice: "red", number: 0 }, NOW + 1, rngOf(1.5 / 37)));
    expect(push.state.careers.civ.cash).toBe(110);
    expect(push.result).toEqual({ ok: true, cash: 10, casino: { number: 1, color: "red", bet: 10, payout: 20 } });
    expect(err(apply(withCash(fresh(), 100), SH(), { type: "roulette", bet: 10, choice: "number", number: 40 }, NOW + 1, noRng))).toBe("Pick a number 0-36.");
  });
});

describe("poker", () => {
  it("scoreFive ranks the categories and bestOfSeven names the hand", () => {
    expect(scoreFive(["AS", "KS", "QS", "JS", "10S"])[0]).toBe(9);
    expect(scoreFive(["9S", "8S", "7S", "6S", "5S"])[0]).toBe(8);
    expect(scoreFive(["9S", "9H", "9D", "9C", "5S"])[0]).toBe(7);
    expect(scoreFive(["9S", "9H", "9D", "5C", "5S"])[0]).toBe(6);
    expect(scoreFive(["2S", "9S", "7S", "6S", "KS"])[0]).toBe(5);
    expect(scoreFive(["AS", "2H", "3D", "4C", "5S"])).toEqual([4, 5]);
    expect(scoreFive(["9S", "9H", "9D", "6C", "5S"])[0]).toBe(3);
    expect(scoreFive(["9S", "9H", "5D", "5C", "KS"])).toEqual([2, 9, 5, 13]);
    expect(scoreFive(["9S", "9H", "2D", "5C", "KS"])).toEqual([1, 9, 13, 5, 2]);
    expect(scoreFive(["9S", "3H", "2D", "5C", "KS"])).toEqual([0, 13, 9, 5, 3, 2]);
    expect(compareScores([2, 9, 5, 13], [2, 9, 5, 12])).toBeGreaterThan(0);
    expect(bestOfSeven(["AS", "KS", "QS", "JS", "10S", "2C", "3D"]).name).toBe("Royal Flush");
    expect(bestOfSeven(["2S", "2H", "9D", "9C", "KS", "4C", "7D"]).name).toBe("Two Pair");
    expect(bestOfSeven(["2S", "5H", "9D", "JC", "KS", "4C", "7D"]).name).toBe("High Card");
  });

  it("a showdown deals a five-card board and two hole cards a seat from a fresh deck and gives the pot to the best hand", () => {
    const seats = [{ steamId: STEAM, name: "Tester", buyIn: 500, faction: "civ" as const }, { steamId: "76561190000000002", name: "Player1", buyIn: 500, faction: "civ" as const }];
    const r = pokerShowdown(seeded(21), seats, 1000);
    expect(r.board).toHaveLength(5);
    expect(r.players.map((p) => p.cards.length)).toEqual([2, 2]);
    expect(new Set([...r.board, ...r.players.flatMap((p) => p.cards)]).size).toBe(9);
    expect(r.winners.reduce((t, w) => t + w.payout, 0)).toBe(1000);
    expect(newDeck(seeded(1))).toHaveLength(52);
    expect(new Set(newDeck(seeded(1))).size).toBe(52);
  });

  it("pokerjoin {buyIn} seats the player and fixes the table buy-in; pokerdeal waits for a second player; pokerleave refunds", () => {
    const r = ok(apply(withCash(fresh(), 1000), SH(), { type: "pokerjoin", buyIn: 500 }, NOW + 1, noRng));
    expect(r.shared.poker).toEqual({ seats: [{ steamId: STEAM, name: "Tester", buyIn: 500, faction: "civ" }], pot: 500, buyIn: 500, minPlayers: 2, lastResult: null });
    expect(r.state.careers.civ.cash).toBe(500);
    expect(r.result).toEqual({ ok: true, cash: -500 });
    expect(err(apply(r.state, r.shared, { type: "pokerjoin", buyIn: 500 }, NOW + 500, noRng))).toBe("You are already seated.");
    expect(err(apply(r.state, r.shared, { type: "pokerdeal" }, NOW + 500, noRng))).toBe("Waiting for one more player.");
    const otherTable = { ...r.shared, poker: { ...r.shared.poker, seats: [{ steamId: "76561190000000002", name: "P", buyIn: 500, faction: "civ" as const }] } };
    expect(err(apply(withCash(fresh(), 1000), otherTable, { type: "pokerjoin", buyIn: 300 }, NOW + 1, noRng))).toBe("Buy-in (table requires $500)");
    const left = ok(apply(r.state, r.shared, { type: "pokerleave" }, NOW + 500, noRng));
    expect(left.shared.poker).toMatchObject({ seats: [], pot: 0, buyIn: null });
    expect(left.state.careers.civ.cash).toBe(1000);
    expect(err(apply(fresh(), SH(), { type: "pokerdeal" }, NOW + 1, noRng))).toBe("Take a seat first.");
    expect(err(apply(fresh(), SH(), { type: "pokerleave" }, NOW + 1, noRng))).toBe("You are not seated.");
  });

  it("a two-seat deal settles the pot, records lastResult and clears the table", () => {
    const table = SH({ poker: { seats: [{ steamId: "76561190000000002", name: "P", buyIn: 500, faction: "civ" }, { steamId: STEAM, name: "Tester", buyIn: 500, faction: "civ" }], pot: 1000, buyIn: 500, minPlayers: 2, lastResult: null } });
    const r = ok(apply(fresh(), table, { type: "pokerdeal" }, NOW + 1, seeded(33)));
    expect(r.shared.poker).toMatchObject({ seats: [], pot: 0, buyIn: null });
    expect(r.shared.poker.lastResult!.pot).toBe(1000);
    const mine = r.shared.poker.lastResult!.winners.find((w) => w.steamId === STEAM);
    expect(r.state.careers.civ.cash).toBe(mine ? mine.payout : 0);
    expect(r.result.message).toBe(mine ? "You took the pot." : "The pot went elsewhere.");
  });
});
