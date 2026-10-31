/**
 * Decode an mres / str2-encoded Arma array blob, as stored in the game DB
 * TEXT columns (gear, inventory, mailbox, keyholders, stats, talents, ...).
 *
 * Byte-identical to the validated Python routine in loonybot/enrique.py:
 *   1. backtick -> double-quote (all)
 *   2. strip the outer str() wrap if present
 *   3. un-double interior quotes
 *   4. JSON.parse  (an SQF array literal == JSON for this data set)
 *
 * Some columns are double-wrapped ("[...]"), some are bare ([...]); both handled.
 * Returns null on anything that doesn't parse, exactly like the game-side reader.
 */
export type ArmaValue = string | number | boolean | ArmaValue[] | null;

export function decodeArma<T = ArmaValue>(s: string | null | undefined): T | null {
  if (s === null || s === undefined) return null;
  let v = s.replace(/`/g, '"');
  if (v.startsWith('"') && v.endsWith('"')) v = v.slice(1, -1);
  v = v.replace(/""/g, '"');
  try {
    return JSON.parse(v) as T;
  } catch {
    return null;
  }
}

/** Decode an array column, always returning an array ([] on failure). */
export function decodeArray<T = ArmaValue>(s: string | null | undefined): T[] {
  const v = decodeArma<T[]>(s);
  return Array.isArray(v) ? v : [];
}

/** Read an int at index i from a decoded numeric-array column, default d. */
export function statAt(arr: ArmaValue[] | null, i: number, d = 0): number {
  if (!arr || i < 0 || i >= arr.length) return d;
  const n = Number(arr[i]);
  return Number.isFinite(n) ? n : d;
}
