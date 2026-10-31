// Armapunk Pixel v3 minigames: the route-choice checkpoints (pursuits and APD dispatch cases), the
// anti-automation checkpoint, the prison workshop pipe puzzle, and the pure id helpers. Everything
// draws from the caller's rng; nothing here reads a clock or a random source of its own.
import { CHECKPOINT_ICONS, INFERRED, ROUTE_LABELS, ROUTE_OBSTACLE_COST, ROUTE_PROMPT } from "./content";
import type { CheckpointState, PrisonJob, RouteAnswer, RouteRound } from "./types";

export type Rng = () => number;

/** floor(rng * n): a uniform integer in [0, n). */
export function rngInt(rng: Rng, n: number): number {
  return Math.min(n - 1, Math.floor(rng() * n));
}

const HEX = "0123456789abcdef";
const BASE36 = "0123456789abcdefghijklmnopqrstuvwxyz";
const CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

/** A UUID-shaped id (8-4-4-4-12 hex) from the rng, like the reference's duel / round / custody ids. */
export function uuidFrom(rng: Rng): string {
  let out = "";
  for (let i = 0; i < 32; i++) {
    if (i === 8 || i === 12 || i === 16 || i === 20) out += "-";
    out += HEX[rngInt(rng, 16)];
  }
  return out;
}

/** A cuid-shaped id ("c" + 12 base36 chars) like the reference's gang ids. */
export function cuidFrom(rng: Rng): string {
  let out = "c";
  for (let i = 0; i < 12; i++) out += BASE36[rngInt(rng, 36)];
  return out;
}

/** In-place Fisher-Yates with the rng. */
export function shuffle<T>(arr: T[], rng: Rng): T[] {
  for (let i = arr.length - 1; i > 0; i--) {
    const j = rngInt(rng, i + 1);
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}

// ---- route rounds ("Checkpoint N: choose the lowest total route cost.")

/** Three rounds of three streets; distance 5..18 and 0..4 obstacles per option, obstacleCost 5, as in the capture. */
export function routeRounds(rng: Rng): RouteRound[] {
  const rounds: RouteRound[] = [];
  for (let n = 1; n <= 3; n++) {
    rounds.push({
      id: uuidFrom(rng),
      prompt: ROUTE_PROMPT(n),
      obstacleCost: ROUTE_OBSTACLE_COST,
      options: ROUTE_LABELS.map((label) => ({ label, distance: 5 + rngInt(rng, 14), obstacles: rngInt(rng, 5) })),
    });
  }
  return rounds;
}

export function routeCost(round: RouteRound, choice: number): number {
  const o = round.options[choice];
  return o.distance + o.obstacles * round.obstacleCost;
}

/** Per-checkpoint score: 100 for the cheapest street, 0 for the dearest, linear between (a one-cost round scores 100). */
export function routeScore(round: RouteRound, choice: number): number {
  const costs = round.options.map((_, i) => routeCost(round, i));
  const best = Math.min(...costs);
  const worst = Math.max(...costs);
  if (worst === best) return 100;
  return Math.round((100 * (worst - routeCost(round, choice))) / (worst - best));
}

export function routeTotal(answers: RouteAnswer[]): number {
  return answers.reduce((t, a) => t + a.score, 0);
}

// ---- anti-automation checkpoint ("Tap the {target}")

/** A target icon and three options (the target among them), shuffled. */
export function newCheckpoint(rng: Rng): CheckpointState {
  const pool = [...CHECKPOINT_ICONS];
  const picks = shuffle(pool, rng).slice(0, 3);
  const target = picks[rngInt(rng, 3)];
  return { id: uuidFrom(rng), target, options: picks, lockedUntil: 0, misses: 0 };
}

// ---- prison workshop (3x3 pipes, inlet left of tile 0, outlet right of tile 8; bits N=1 E=2 S=4 W=8)

export const PIPE = { N: 1, E: 2, S: 4, W: 8 } as const;
const DIRS: { bit: number; opposite: number; dr: number; dc: number }[] = [
  { bit: PIPE.N, opposite: PIPE.S, dr: -1, dc: 0 },
  { bit: PIPE.E, opposite: PIPE.W, dr: 0, dc: 1 },
  { bit: PIPE.S, opposite: PIPE.N, dr: 1, dc: 0 },
  { bit: PIPE.W, opposite: PIPE.E, dr: 0, dc: -1 },
];

/** Rotate a tile a quarter turn clockwise: N -> E -> S -> W -> N. */
export function rotateTile(mask: number): number {
  return ((mask << 1) | (mask >> 3)) & 15;
}

/** Every simple path from tile 0 to tile 8 on the 3x3 grid, in a fixed order. */
function simplePaths(): number[][] {
  const out: number[][] = [];
  const walk = (path: number[], seen: Set<number>) => {
    const at = path[path.length - 1];
    if (at === 8) {
      out.push([...path]);
      return;
    }
    const r = Math.floor(at / 3);
    const c = at % 3;
    for (const d of DIRS) {
      const nr = r + d.dr;
      const nc = c + d.dc;
      if (nr < 0 || nr > 2 || nc < 0 || nc > 2) continue;
      const next = nr * 3 + nc;
      if (seen.has(next)) continue;
      seen.add(next);
      path.push(next);
      walk(path, seen);
      path.pop();
      seen.delete(next);
    }
  };
  walk([0], new Set([0]));
  return out;
}
const PATHS = simplePaths();

function dirBetween(a: number, b: number): { bit: number; opposite: number } {
  const dr = Math.floor(b / 3) - Math.floor(a / 3);
  const dc = (b % 3) - (a % 3);
  const d = DIRS.find((x) => x.dr === dr && x.dc === dc);
  if (!d) throw new Error(`tiles ${a} and ${b} are not neighbours`);
  return d;
}

/** True when the inlet (west of tile 0) connects through the pipes to the outlet (east of tile 8). */
export function pipesSolved(tiles: number[]): boolean {
  if (tiles.length !== 9) return false;
  if (!(tiles[0] & PIPE.W)) return false;
  const seen = new Set<number>([0]);
  const queue = [0];
  while (queue.length) {
    const at = queue.shift() as number;
    if (at === 8) return (tiles[8] & PIPE.E) !== 0;
    const r = Math.floor(at / 3);
    const c = at % 3;
    for (const d of DIRS) {
      if (!(tiles[at] & d.bit)) continue;
      const nr = r + d.dr;
      const nc = c + d.dc;
      if (nr < 0 || nr > 2 || nc < 0 || nc > 2) continue;
      const next = nr * 3 + nc;
      if (seen.has(next) || !(tiles[next] & d.opposite)) continue;
      seen.add(next);
      queue.push(next);
    }
  }
  return false;
}

/**
 * A solvable, scrambled puzzle: one random simple path from the inlet to the outlet carries the
 * pipe, the other tiles get random masks, then every tile is turned 0..3 quarter turns.
 */
export function newPrisonJob(rng: Rng, now: number, jobSeconds: number): PrisonJob {
  const path = PATHS[rngInt(rng, PATHS.length)];
  const tiles = new Array<number>(9).fill(0);
  tiles[0] |= PIPE.W;
  for (let i = 0; i + 1 < path.length; i++) {
    const d = dirBetween(path[i], path[i + 1]);
    tiles[path[i]] |= d.bit;
    tiles[path[i + 1]] |= d.opposite;
  }
  tiles[8] |= PIPE.E;
  for (let i = 0; i < 9; i++) {
    if (tiles[i] === 0) tiles[i] = 1 + rngInt(rng, 14);
    const turns = rngInt(rng, 4);
    for (let t = 0; t < turns; t++) tiles[i] = rotateTile(tiles[i]);
  }
  return { id: uuidFrom(rng), tiles, readyAt: now + jobSeconds * 1000, startedAt: now };
}

/** A six-char invite code from a seed, the window index and the use count (deterministic, so a code can be re-derived for its window). */
export function inviteCodeFrom(seed: string, epoch: number, bumps: number): string {
  let out = "";
  for (let i = 0; i < INFERRED.gangInviteCodeLen; i++) {
    let h = 0x811c9dc5;
    const src = `${seed}:${epoch}:${bumps}:${i}`;
    for (let k = 0; k < src.length; k++) {
      h ^= src.charCodeAt(k);
      h = Math.imul(h, 0x01000193) >>> 0;
    }
    out += CODE_ALPHABET[h % CODE_ALPHABET.length];
  }
  return out;
}
