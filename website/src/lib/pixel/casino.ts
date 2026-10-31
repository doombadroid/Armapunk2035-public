// Armapunk Pixel v3 casino: blackjack (dealer stands on 17), a three-reel slot machine (7s pay 25x),
// single-zero roulette (red / black / even / odd 2x, green and straight 36x) and the Live Poker
// Showdown (2-4 seats, one deal, best five of seven, winner takes the pot). Pure: cards come from
// the caller's rng; cash moves are the engine's job.
import { INFERRED } from "./content";
import { CASINO } from "./rules";
import { shuffle, type Rng, rngInt } from "./minigames";
import type { BlackjackHand, PokerResult, PokerSeat, RouletteChoice, RouletteResult, SlotsResult } from "./types";

const RANKS = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"];
const SUITS = ["S", "H", "D", "C"];

/** A fresh 52-card deck, shuffled: cards are rank + suit letter ("10H", "AS"). */
export function newDeck(rng: Rng): string[] {
  const deck: string[] = [];
  for (const s of SUITS) for (const r of RANKS) deck.push(r + s);
  return shuffle(deck, rng);
}

export function cardRank(card: string): string {
  return card.slice(0, -1);
}

// ---- blackjack

/** Best blackjack total: aces count 11 while that does not bust. */
export function blackjackScore(cards: string[]): number {
  let total = 0;
  let aces = 0;
  for (const c of cards) {
    const r = cardRank(c);
    if (r === "A") {
      aces++;
      total += 11;
    } else if (r === "K" || r === "Q" || r === "J" || r === "10") total += 10;
    else total += Number(r);
  }
  while (total > 21 && aces > 0) {
    total -= 10;
    aces--;
  }
  return total;
}

/** Deal two each; a natural 21 settles at once (3:2, push against a dealer natural). */
export function blackjackDeal(rng: Rng, bet: number): BlackjackHand {
  const deck = newDeck(rng);
  const playerCards = [deck.pop() as string, deck.pop() as string];
  const dealerCards = [deck.pop() as string, deck.pop() as string];
  const hand: BlackjackHand = { deck, dealerCards, playerCards, status: "playing", bet, payout: 0 };
  const player = blackjackScore(playerCards);
  const dealer = blackjackScore(dealerCards);
  if (player === 21) {
    if (dealer === 21) {
      hand.status = "push";
      hand.payout = bet;
    } else {
      hand.status = "won";
      hand.payout = Math.round(bet * CASINO.blackjackNatural);
    }
  }
  return hand;
}

/** Take a card; over 21 loses the hand. */
export function blackjackHit(hand: BlackjackHand): BlackjackHand {
  const h = { ...hand, deck: [...hand.deck], playerCards: [...hand.playerCards] };
  h.playerCards.push(h.deck.pop() as string);
  if (blackjackScore(h.playerCards) > 21) {
    h.status = "lost";
    h.payout = 0;
  }
  return h;
}

/** Dealer draws to 17 (stands on every 17) and the totals settle: win 2x, push returns the bet. */
export function blackjackStand(hand: BlackjackHand): BlackjackHand {
  const h = { ...hand, deck: [...hand.deck], dealerCards: [...hand.dealerCards] };
  while (blackjackScore(h.dealerCards) < CASINO.blackjackStandsOn) h.dealerCards.push(h.deck.pop() as string);
  const player = blackjackScore(h.playerCards);
  const dealer = blackjackScore(h.dealerCards);
  if (dealer > 21 || player > dealer) {
    h.status = "won";
    h.payout = h.bet * CASINO.blackjackWin;
  } else if (player === dealer) {
    h.status = "push";
    h.payout = h.bet;
  } else {
    h.status = "lost";
    h.payout = 0;
  }
  return h;
}

// ---- slots

/** Three reels off the weighted strip; 7-7-7 pays 25x, the rest per the INFERRED paytable. */
export function spinSlots(rng: Rng, bet: number): SlotsResult {
  const strip = INFERRED.slotsReel;
  const reels = [0, 1, 2].map(() => strip[rngInt(rng, strip.length)]);
  return { reels, bet, payout: slotsPayout(reels, bet) };
}

export function slotsPayout(reels: string[], bet: number): number {
  const [a, b, c] = reels;
  if (a === b && b === c) {
    if (a === "7") return bet * CASINO.slotsSevens;
    if (a === "BAR") return bet * INFERRED.slotsBar;
    if (a === "BELL") return bet * INFERRED.slotsBell;
    if (a === "CHERRY") return bet * INFERRED.slotsCherry;
  }
  const cherries = reels.filter((r) => r === "CHERRY").length;
  if (cherries === 2) return bet * INFERRED.slotsTwoCherries;
  return 0;
}

// ---- roulette (single zero)

const REDS = new Set([1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]);

export function rouletteColor(n: number): "red" | "black" | "green" {
  if (n === 0) return "green";
  return REDS.has(n) ? "red" : "black";
}

export function spinRoulette(rng: Rng, bet: number, choice: RouletteChoice, number: number): RouletteResult {
  const n = rngInt(rng, 37);
  return { number: n, color: rouletteColor(n), bet, payout: roulettePayout(n, bet, choice, number) };
}

export function roulettePayout(n: number, bet: number, choice: RouletteChoice, number: number): number {
  const color = rouletteColor(n);
  switch (choice) {
    case "red":
      return color === "red" ? bet * CASINO.rouletteEven : 0;
    case "black":
      return color === "black" ? bet * CASINO.rouletteEven : 0;
    case "even":
      return n !== 0 && n % 2 === 0 ? bet * CASINO.rouletteEven : 0;
    case "odd":
      return n % 2 === 1 ? bet * CASINO.rouletteEven : 0;
    case "green":
      return n === 0 ? bet * CASINO.rouletteStraight : 0;
    case "number":
      return n === number ? bet * CASINO.rouletteStraight : 0;
  }
}

// ---- poker showdown

const RANK_VALUE: Record<string, number> = Object.fromEntries(RANKS.map((r, i) => [r, i + 2]));
const HAND_NAMES = ["High Card", "Pair", "Two Pair", "Three of a Kind", "Straight", "Flush", "Full House", "Four of a Kind", "Straight Flush", "Royal Flush"];

/** Score of a five-card hand as [category, tiebreakers...]; higher arrays win lexicographically. */
export function scoreFive(cards: string[]): number[] {
  const values = cards.map((c) => RANK_VALUE[cardRank(c)]).sort((a, b) => b - a);
  const suits = cards.map((c) => c.slice(-1));
  const flush = suits.every((s) => s === suits[0]);
  const uniq = [...new Set(values)];
  let straightHigh = 0;
  if (uniq.length === 5) {
    if (uniq[0] - uniq[4] === 4) straightHigh = uniq[0];
    else if (uniq.join(",") === "14,5,4,3,2") straightHigh = 5;
  }
  const counts = new Map<number, number>();
  for (const v of values) counts.set(v, (counts.get(v) ?? 0) + 1);
  const groups = [...counts.entries()].sort((a, b) => b[1] - a[1] || b[0] - a[0]);
  const byGroup = groups.map((g) => g[0]);
  if (straightHigh && flush) return [straightHigh === 14 ? 9 : 8, straightHigh];
  if (groups[0][1] === 4) return [7, ...byGroup];
  if (groups[0][1] === 3 && groups[1][1] === 2) return [6, ...byGroup];
  if (flush) return [5, ...values];
  if (straightHigh) return [4, straightHigh];
  if (groups[0][1] === 3) return [3, ...byGroup];
  if (groups[0][1] === 2 && groups[1][1] === 2) return [2, ...byGroup];
  if (groups[0][1] === 2) return [1, ...byGroup];
  return [0, ...values];
}

export function compareScores(a: number[], b: number[]): number {
  for (let i = 0; i < Math.max(a.length, b.length); i++) {
    const d = (a[i] ?? 0) - (b[i] ?? 0);
    if (d !== 0) return d;
  }
  return 0;
}

/** Best five of seven cards. */
export function bestOfSeven(cards: string[]): { score: number[]; name: string } {
  let best: number[] | null = null;
  for (let i = 0; i < cards.length; i++) {
    for (let j = i + 1; j < cards.length; j++) {
      const five = cards.filter((_, k) => k !== i && k !== j);
      const s = scoreFive(five);
      if (!best || compareScores(s, best) > 0) best = s;
    }
  }
  const score = best as number[];
  return { score, name: HAND_NAMES[score[0]] };
}

/** One showdown: a five-card board, two hole cards a seat, the pot split among the best hands. */
export function pokerShowdown(rng: Rng, seats: PokerSeat[], pot: number): PokerResult {
  const deck = newDeck(rng);
  const board = [0, 1, 2, 3, 4].map(() => deck.pop() as string);
  const players = seats.map((seat) => {
    const cards = [deck.pop() as string, deck.pop() as string];
    const best = bestOfSeven([...cards, ...board]);
    return { steamId: seat.steamId, name: seat.name, cards, hand: best.name, score: best.score };
  });
  let top: number[] | null = null;
  for (const p of players) if (!top || compareScores(p.score, top) > 0) top = p.score;
  const winnersList = players.filter((p) => compareScores(p.score, top as number[]) === 0);
  const share = Math.floor(pot / winnersList.length);
  const remainder = pot - share * winnersList.length;
  const winners = winnersList.map((w, i) => ({ steamId: w.steamId, payout: share + (i === 0 ? remainder : 0) }));
  return { pot, board, players: players.map(({ steamId, name, cards, hand }) => ({ steamId, name, cards, hand })), winners };
}
