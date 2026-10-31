import { Pool, types } from "pg";

// Single shared read pool. The website is read-only against the live game DB;
// point PGUSER at a SELECT-only role in production (see README).
//
// Phase W (2026-08-20): mysql2 -> pg. The q()/one()/num() contract is
// unchanged; `?` placeholders are rewritten to $1..$n here so the ~150 call
// sites keep their positional-params shape. Numeric semantics mirror the old
// `supportBigNumbers`: int8/numeric arrive as STRINGS (never a rounded JS
// number) and num() coerces where a number is wanted.
declare global {
  // eslint-disable-next-line no-var
  var _looneyPool: Pool | undefined;
}

export const DB_INSTANCE = Number(process.env.DB_INSTANCE ?? 1);

// int8 (20) and numeric (1700) as strings -- money must not round on read.
types.setTypeParser(20, (v) => v);
types.setTypeParser(1700, (v) => v);

export function pool(): Pool {
  if (!global._looneyPool) {
    global._looneyPool = new Pool({
      host: process.env.DB_HOST ?? "127.0.0.1",
      port: Number(process.env.DB_PORT ?? 5432),
      user: process.env.DB_USER ?? "armapunk",
      password: process.env.DB_PASSWORD ?? "",
      database: process.env.DB_NAME ?? "pgm_full_scratch",
      max: 8,
    });
  }
  return global._looneyPool;
}

/** `?` -> $1..$n, string-literal aware (a ? inside quotes is data). */
function placeholders(sql: string): string {
  let n = 0;
  let out = "";
  let inS: string | null = null;
  for (let i = 0; i < sql.length; i++) {
    const c = sql[i];
    if (inS) {
      out += c;
      if (c === inS) inS = null;
      continue;
    }
    if (c === "'" || c === '"') {
      inS = c;
      out += c;
    } else if (c === "?") {
      out += `$${++n}`;
    } else {
      out += c;
    }
  }
  return out;
}

export async function q<T = Record<string, unknown>>(
  sql: string,
  params: unknown[] = []
): Promise<T[]> {
  const res = await pool().query(placeholders(sql), params as unknown[]);
  return res.rows as T[];
}

export async function one<T = Record<string, unknown>>(
  sql: string,
  params: unknown[] = []
): Promise<T | null> {
  const rows = await q<T>(sql, params);
  return rows[0] ?? null;
}

/** Coerce a possibly-bigint/string numeric column to a JS number. */
export function num(v: unknown, d = 0): number {
  if (v === null || v === undefined) return d;
  const n = typeof v === "number" ? v : Number(v);
  return Number.isFinite(n) ? n : d;
}
