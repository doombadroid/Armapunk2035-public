// House storage (vinv/pinv) codec + weight math. The DB stores an mres-encoded
// [[[classname,qty],...], total] where the value literally begins/ends with a double
// quote and each classname is wrapped in double-backticks (DB_fnc_mresArray). The game
// re-reads the row on every storage-open and recomputes total = Σ(qty × weight), so we
// mirror that exactly. See fn_updateHouseTrunk.sqf / fn_physicalInventoryWeight.sqf.
import { HOUSE_VIRT_ITEMS, PHYS_WEIGHT } from "./houseItems";

export type InvPair = [string, number];
export type HouseInv = [InvPair[], number]; // [items, total]

const VIRT_W = new Map(HOUSE_VIRT_ITEMS.map((i) => [i.classname, i.weight]));

export function virtWeight(cls: string): number { return VIRT_W.get(cls) ?? 0; }
export function physWeight(cls: string): number { return PHYS_WEIGHT[cls] ?? 0; }

export const STACK_CAP = 100000; // per-stack qty ceiling the game's sanitizer enforces

/** Decode the mres TEXT value into [items, total]. Returns [[],0] for a genuinely-empty
 *  value, but `null` when a NON-empty value fails to parse — so a writer can ABORT rather
 *  than overwrite (and wipe) storage it couldn't read. Read-only callers use `?? [[],0]`. */
export function decodeHouseInv(raw: string | null | undefined): HouseInv | null {
  if (raw == null) return [[], 0];
  const s = raw.trim();
  if (s === "" || s === "[]") return [[], 0];
  try {
    const inner = s.startsWith('"') && s.endsWith('"') ? s.slice(1, -1) : s;
    const arr = JSON.parse(inner.replace(/``/g, '"'));
    if (!Array.isArray(arr) || arr.length < 2 || !Array.isArray(arr[0])) return null;
    const items: InvPair[] = arr[0]
      .filter((p: unknown) => Array.isArray(p) && p.length === 2 && typeof p[0] === "string")
      .map((p: [string, number]) => [String(p[0]), Math.max(0, Math.floor(Number(p[1]) || 0))] as InvPair)
      .filter((p) => p[1] > 0);
    return [items, Math.max(0, Math.floor(Number(arr[1]) || 0))];
  } catch {
    return null; // non-empty but unparseable — caller MUST NOT overwrite
  }
}

/** Encode [items, total] back to the exact mres TEXT the game reads. */
export function encodeHouseInv(inv: HouseInv): string {
  return '"' + JSON.stringify(inv).replace(/"/g, "``") + '"';
}

/** Add classnames to an item list, combining stacks. The STACK_CAP clamp bounds only NEW
 *  growth — a pre-existing stack already above STACK_CAP is never truncated (that would
 *  silently destroy stored property when an admin places an unrelated item). */
export function mergeItems(existing: InvPair[], additions: InvPair[]): InvPair[] {
  const base = new Map<string, number>();
  for (const [c, qraw] of existing) {
    const q = Math.floor(Number(qraw) || 0);
    if (!c || q <= 0) continue;
    base.set(c, (base.get(c) ?? 0) + q);
  }
  const map = new Map(base);
  for (const [c, qraw] of additions) {
    const q = Math.floor(Number(qraw) || 0);
    if (!c || q <= 0) continue;
    map.set(c, (map.get(c) ?? 0) + q);
  }
  return [...map.entries()].map(([c, q]) => {
    const floorCap = Math.max(STACK_CAP, base.get(c) ?? 0); // never below the pre-existing qty
    return [c, Math.min(q, floorCap)] as InvPair;
  });
}

/** Recompute the weight total the same way the game does (0 for unknown physical gear). */
export function invTotal(items: InvPair[], type: "virtual" | "physical"): number {
  const w = type === "physical" ? physWeight : virtWeight;
  return items.reduce((t, [cls, qty]) => t + w(cls) * qty, 0);
}

/** Strict classname sanitizer — Arma classnames are [A-Za-z0-9_] only. Prevents breaking
 *  the mres array (no quotes/backticks/commas/brackets can slip into the encoded value). */
export function sanitizeClass(c: string): string {
  return (c || "").replace(/[^A-Za-z0-9_]/g, "").slice(0, 64);
}
