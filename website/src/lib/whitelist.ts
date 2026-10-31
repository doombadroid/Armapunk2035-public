import { q, one, num } from "./db";
import { FACTIONS, type ActorPowers, type Faction } from "./factions";

/** Authoritative actor powers — ALWAYS from the live DB, never the cookie. */
export async function getActorPowers(uid: string): Promise<ActorPowers> {
  const g = await one<{ adminlevel: number; coplevel: number; mediclevel: number }>(
    "SELECT adminlevel, coplevel, mediclevel FROM players_global WHERE playerid=? LIMIT 1",
    [uid]
  );
  return {
    uid,
    adminlevel: num(g?.adminlevel),
    isOwner: uid === (process.env.OWNER_STEAMID ?? ""),
    ranks: { police: num(g?.coplevel), medic: num(g?.mediclevel), staff: num(g?.adminlevel) },
  };
}

export interface RosterMember { uid: string; name: string; rank: number; subs: Record<string, number> }

function subSelect(f: Faction): string {
  // f.subs columns are from the fixed registry (ismaxtac/isscd) — safe to interpolate.
  return f.subs.map((s) => `, p.${s.column} AS sub_${s.key}`).join("");
}
function pickSubs(f: Faction, row: Record<string, unknown>): Record<string, number> {
  const out: Record<string, number> = {};
  for (const s of f.subs) out[s.key] = num(row[`sub_${s.key}`]);
  return out;
}

export async function getFactionRoster(f: Faction): Promise<RosterMember[]> {
  const rows = await q<Record<string, unknown>>(
    `SELECT g.playerid, p.name, g.${f.column} AS rank${subSelect(f)}
       FROM players_global g JOIN players p ON p.playerid = g.playerid
      WHERE g.${f.column} > 0
      ORDER BY g.${f.column} DESC, p.name ASC`
  );
  return rows.map((r) => ({ uid: String(r.playerid), name: String(r.name), rank: num(r.rank), subs: pickSubs(f, r) }));
}

export interface RosterTableRow {
  uid: string; name: string; rank: number; exp: number;
  lastSeen: Date | string | null; retired: number; subs: Record<string, number>;
}

/** Rich roster for the classic table view: rank + XP + last-seen + retired + subs. */
export async function getFactionRosterTable(f: Faction): Promise<RosterTableRow[]> {
  // exp/retired source columns are chosen by faction key from a fixed map (no user input).
  const expCol = f.key === "police" ? "p.cop_exp" : f.key === "medic" ? "p.med_exp" : "0";
  const retiredCol = f.key === "police" ? "g.copretired" : "0";
  const rows = await q<Record<string, unknown>>(
    `SELECT g.playerid, p.name, g.${f.column} AS rank, ${expCol} AS exp,
            p.lastupdated AS "lastSeen", ${retiredCol} AS retired${subSelect(f)}
       FROM players_global g JOIN players p ON p.playerid = g.playerid
      WHERE g.${f.column} > 0
      ORDER BY g.${f.column} DESC, p.name ASC`
  );
  return rows.map((r) => ({
    uid: String(r.playerid), name: String(r.name), rank: num(r.rank),
    exp: num(r.exp), lastSeen: (r.lastSeen as Date | string | null) ?? null,
    retired: num(r.retired), subs: pickSubs(f, r),
  }));
}

export interface FactionSearchHit { uid: string; name: string; rank: number; subs: Record<string, number> }

/** Search players + include their current rank + sub-flags in the given faction. */
export async function searchForFaction(f: Faction, term: string, limit = 25): Promise<FactionSearchHit[]> {
  const like = `%${term}%`;
  const rows = await q<Record<string, unknown>>(
    `SELECT p.playerid, p.name, COALESCE(g.${f.column},0) AS rank${subSelect(f)}
       FROM players p
       LEFT JOIN players_global g ON g.playerid = p.playerid
      WHERE p.name LIKE ? OR p.playerid LIKE ?
            OR p.playerid IN (SELECT playerid FROM player_names WHERE name LIKE ?)
      ORDER BY p.lastupdated DESC
      LIMIT ?`,
    [like, like, like, limit]
  );
  return rows.map((r) => ({ uid: String(r.playerid), name: String(r.name), rank: num(r.rank), subs: pickSubs(f, r) }));
}

/** Read one sub-flag's current value (0/1) for a player. */
export async function getSubValue(column: string, uid: string): Promise<number> {
  const r = await one<{ v: number }>(`SELECT ${column} AS v FROM players WHERE playerid=? LIMIT 1`, [uid]);
  return num(r?.v);
}

/** Read a single player's current rank in a faction. */
export async function getTargetRank(f: Faction, uid: string): Promise<number> {
  const g = await one<{ rank: number }>(
    `SELECT ${f.column} AS rank FROM players_global WHERE playerid=? LIMIT 1`, [uid]
  );
  return num(g?.rank);
}

export interface AuditRow {
  id: number; ts: Date; faction: string; actor_id: string; actor_name: string;
  actor_role: string; target_id: string; target_name: string;
  old_rank: number; new_rank: number; action: string;
}

/** Audit log. `factions` undefined = all (admin/owner); else restrict to those keys. */
export async function getAuditLog(factions: string[] | null, limit = 100): Promise<AuditRow[]> {
  if (factions && factions.length === 0) return [];
  if (factions) {
    const ph = factions.map(() => "?").join(",");
    return q<AuditRow>(
      `SELECT * FROM web_whitelist_log WHERE faction IN (${ph}) ORDER BY id DESC LIMIT ?`,
      [...factions, limit]
    );
  }
  return q<AuditRow>("SELECT * FROM web_whitelist_log ORDER BY id DESC LIMIT ?", [limit]);
}

export function rankName(f: Faction, rank: number): string {
  return rank <= 0 ? "Civilian" : f.ranks[rank] ?? `Rank ${rank}`;
}

export interface BlacklistRow {
  id: number; faction: string; playerid: string; name: string | null;
  reason: string | null; added_by: string; added_by_name: string; created_at: Date | string;
}

/** Active (not-removed) blacklist entries for a faction. */
export async function getFactionBlacklist(faction: string): Promise<BlacklistRow[]> {
  return q<BlacklistRow>(
    "SELECT * FROM web_faction_blacklist WHERE faction=? AND removed_at IS NULL ORDER BY id DESC", [faction]
  );
}

export { FACTIONS };
