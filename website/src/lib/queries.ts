import { q, one, num, DB_INSTANCE } from "./db";
import { decodeArray, statAt } from "./arma";
import { STAT } from "./ranks";
import { lbMetric, type LbMetric } from "./leaderboards";
import type {
  PlayerRow, PlayerGlobalRow, PlayerDetail, VehicleRow, HouseRow,
  GangRow, GangDetail, LeaderRow, ActivityRow,
} from "./types";

// ---------------------------------------------------------------- players

export async function getPlayerDetail(uid: string): Promise<PlayerDetail | null> {
  const p = await one<PlayerRow>("SELECT * FROM players WHERE playerid=? LIMIT 1", [uid]);
  if (!p) return null;
  const g = await one<PlayerGlobalRow>(
    "SELECT * FROM players_global WHERE playerid=? LIMIT 1", [uid]
  );

  const stats = decodeArray<number>(g?.stats ?? null);

  const [gang, names, discord, vehAgg, houseAgg, bounty, ban] = await Promise.all([
    p.gang0 != null
      ? one<{ name: string }>("SELECT name FROM gangs WHERE id=? LIMIT 1", [p.gang0])
      : Promise.resolve(null),
    q<{ name: string; seen: Date }>(
      "SELECT name, seen FROM player_names WHERE playerid=? ORDER BY seen DESC", [uid]
    ),
    one<{ discord_id: string }>(
      "SELECT discord_id FROM discord_links WHERE playerid=? LIMIT 1", [uid]
    ),
    q<{ side: string; n: number }>(
      "SELECT side, COUNT(*) n FROM vehicles WHERE pid=? GROUP BY side", [uid]
    ),
    one<{ n: number }>("SELECT COUNT(*) n FROM houses WHERE owners=?", [uid]),
    one<{ amount: number }>(
      "SELECT COALESCE(SUM(amount),0) amount FROM bounties WHERE target_uid=?", [uid]
    ),
    one<{ n: number }>(
      "SELECT COUNT(*) n FROM bans WHERE playerid=? AND (until IS NULL OR until > NOW())", [uid]
    ),
  ]);

  const bySide = { civ: 0, cop: 0, med: 0 };
  for (const r of vehAgg) {
    const s = r.side?.toLowerCase();
    if (s === "civ" || s === "cop" || s === "med") bySide[s] = num(r.n);
  }

  const aliasNames = Array.from(new Set(names.map((n) => n.name).filter(Boolean)));
  const joined = names.length ? names[names.length - 1].seen : null;
  const lastSeen = names.length ? names[0].seen : p.lastupdated;

  return {
    uid: p.playerid,
    name: names[0]?.name ?? p.name,
    cash: num(p.cash),
    bank: num(p.bankacc),
    newDrachma: num(p.new_drachma),
    wealth: num(g?.wealth),
    civExp: num(p.civ_exp),
    copExp: num(p.cop_exp),
    medExp: num(p.med_exp),
    infamyExp: num(p.infamy_exp),
    honorExp: num(g?.honor_exp),
    civTime: statAt(stats, STAT.CIV_TIME),
    copTime: statAt(stats, STAT.COP_TIME),
    medTime: statAt(stats, STAT.MED_TIME),
    copLevel: num(g?.coplevel),
    copRetired: num(g?.copretired),
    medicLevel: num(g?.mediclevel),
    adminLevel: num(g?.adminlevel),
    isMaxTac: !!p.ismaxtac,
    isSCD: !!p.isscd,
    isFirefighter: !!p.isfirefighter,
    betaTester: !!g?.betatester,
    gangId: p.gang0,
    gangName: gang?.name ?? null,
    gangRank: num(p.gangrank0, 5),
    aliases: aliasNames,
    joined,
    lastSeen,
    discordId: discord?.discord_id ? String(discord.discord_id) : null,
    vehicleCount: bySide.civ + bySide.cop + bySide.med,
    vehiclesBySide: bySide,
    houseCount: num(houseAgg?.n),
    bountyAmount: num(bounty?.amount),
    banned: num(ban?.n) > 0,
  };
}

export interface PlayerListItem {
  uid: string;
  name: string;
  civExp: number;
  copLevel: number;
  medicLevel: number;
  gangName: string | null;
  lastSeen: Date;
}

export async function searchPlayers(term: string, limit = 40): Promise<PlayerListItem[]> {
  const like = `%${term}%`;
  const rows = await q<{
    playerid: string; name: string; civ_exp: number; coplevel: number;
    mediclevel: number; gangName: string | null; lastupdated: Date;
  }>(
    `SELECT p.playerid, p.name, p.civ_exp, g.coplevel, g.mediclevel,
            gn.name AS "gangName", p.lastupdated
       FROM players p
       LEFT JOIN players_global g ON g.playerid = p.playerid
       LEFT JOIN gangs gn ON gn.id = p.gang0
      WHERE p.name LIKE ? OR p.playerid LIKE ?
            OR p.playerid IN (SELECT playerid FROM player_names WHERE name LIKE ?)
      ORDER BY p.lastupdated DESC
      LIMIT ?`,
    [like, like, like, limit]
  );
  return rows.map((r) => ({
    uid: r.playerid, name: r.name, civExp: num(r.civ_exp),
    copLevel: num(r.coplevel), medicLevel: num(r.mediclevel),
    gangName: r.gangName, lastSeen: r.lastupdated,
  }));
}

export async function listPlayers(
  page = 0, perPage = 50, sort: "recent" | "civ" | "cop" | "med" | "wealth" = "recent"
): Promise<{ items: PlayerListItem[]; total: number }> {
  const order = {
    recent: "p.lastupdated DESC",
    civ: "p.civ_exp DESC",
    cop: "p.cop_exp DESC",
    med: "p.med_exp DESC",
    wealth: "g.wealth DESC",
  }[sort];
  const [rows, total] = await Promise.all([
    q<{
      playerid: string; name: string; civ_exp: number; coplevel: number;
      mediclevel: number; gangName: string | null; lastupdated: Date;
    }>(
      `SELECT p.playerid, p.name, p.civ_exp, g.coplevel, g.mediclevel,
              gn.name AS "gangName", p.lastupdated
         FROM players p
         LEFT JOIN players_global g ON g.playerid = p.playerid
         LEFT JOIN gangs gn ON gn.id = p.gang0
        ORDER BY ${order}
        LIMIT ? OFFSET ?`,
      [perPage, page * perPage]
    ),
    one<{ n: number }>("SELECT COUNT(*) n FROM players"),
  ]);
  return {
    items: rows.map((r) => ({
      uid: r.playerid, name: r.name, civExp: num(r.civ_exp),
      copLevel: num(r.coplevel), medicLevel: num(r.mediclevel),
      gangName: r.gangName, lastSeen: r.lastupdated,
    })),
    total: num(total?.n),
  };
}

// Build the value expression + FROM + guard clauses for a leaderboard metric.
// column / lifetime_stats index come ONLY from the LB_METRICS whitelist — no user
// input reaches the SQL. lifetime_stats boards guard with a shape regex so the
// array cast never touches a malformed or NULL row.
function lbSql(m: LbMetric): { valueExpr: string; from: string; guards: string[] } {
  const gangJoin = "LEFT JOIN gangs gn ON gn.id = p.gang0";
  if (m.source.kind === "wanted") {
    return {
      valueExpr: "w.bounty",
      from: `FROM wanted w JOIN players p ON p.playerid = w.playerid ${gangJoin}`,
      guards: [],
    };
  }
  const from = `FROM players p LEFT JOIN players_global g ON g.playerid = p.playerid ${gangJoin}`;
  const guards: string[] = [];
  if (m.excludeStaff) guards.push("COALESCE(g.adminlevel,0) < 1");
  let valueExpr: string;
  if (m.source.kind === "wealth") valueExpr = "(p.cash + p.bankacc)";
  else if (m.source.kind === "col") valueExpr = m.source.col;
  else {
    // lifetime_stats is the game's mres blob now (text `"[0,0,...]"`, numbers only):
    // strip the wrapper+brackets, split, index (SQL arrays are 1-based).
    valueExpr = `(string_to_array(btrim(g.lifetime_stats, '"[]'), ','))[${m.source.index + 1}]::bigint`;
    // PostgreSQL has no JSON_VALID: accept only a bracketed numeric list (NULL fails the match).
    guards.push(`g.lifetime_stats ~ '^"?\\[[0-9,.\\s-]*\\]"?$'`);
  }
  return { valueExpr, from, guards };
}

export async function leaderboard(metricKey: string, limit = 100): Promise<LeaderRow[]> {
  const m = lbMetric(metricKey);
  const { valueExpr, from, guards } = lbSql(m);
  const whereSql = guards.length ? `WHERE ${guards.join(" AND ")}` : "";
  // Subquery, not HAVING: PostgreSQL will not reference a SELECT alias in HAVING (MySQL did),
  // and the quoted alias keeps gangName camel-cased (unquoted identifiers fold to lower case).
  const rows = await q<{ playerid: string; name: string; value: number; gangName: string | null }>(
    `SELECT * FROM (
       SELECT p.playerid, p.name, ${valueExpr} AS value, gn.name AS "gangName"
         ${from}
         ${whereSql}
     ) t
     WHERE t.value > 0
     ORDER BY t.value DESC
     LIMIT ?`,
    [limit]
  );
  return rows.map((r) => ({
    uid: r.playerid, name: r.name, value: num(r.value), gangName: r.gangName,
  }));
}

/** Viewer's own standing on a metric (1-based rank + their value). null if unranked. */
export async function leaderboardRank(
  metricKey: string, uid: string
): Promise<{ rank: number; value: number } | null> {
  const m = lbMetric(metricKey);
  const { valueExpr, from, guards } = lbSql(m);
  const mineWhere = [...guards, "p.playerid = ?"];
  const mine = await one<{ value: number }>(
    `SELECT * FROM (SELECT ${valueExpr} AS value ${from} WHERE ${mineWhere.join(" AND ")}) t WHERE t.value > 0`,
    [uid]
  );
  if (!mine) return null;
  const myVal = num(mine.value);
  const whereSql = guards.length ? `WHERE ${guards.join(" AND ")}` : "";
  // count board rows strictly above me — via a subquery so the stat-array cast only runs
  // on rows the guard admitted (inner WHERE), never in the outer compare.
  const ahead = await one<{ n: number }>(
    `SELECT COUNT(*) AS n FROM (
        SELECT ${valueExpr} AS value ${from} ${whereSql}
      ) t WHERE t.value > 0 AND t.value > ?`,
    [myVal]
  );
  return { rank: num(ahead?.n) + 1, value: myVal };
}

export async function serverTotals(): Promise<{ players: number; economy: number; gangs: number }> {
  const [p, e, g] = await Promise.all([
    one<{ n: number }>("SELECT COUNT(*) n FROM players"),
    one<{ n: number }>("SELECT SUM(cash + bankacc) n FROM players"),
    one<{ n: number }>("SELECT COUNT(*) n FROM gangs"),
  ]);
  return { players: num(p?.n), economy: num(e?.n), gangs: num(g?.n) };
}

export async function freshBlood(limit = 6): Promise<{ uid: string; name: string; firstSeen: Date }[]> {
  const rows = await q<{ playerid: string; name: string; fs: Date }>(
    `SELECT pn.playerid,
            (SELECT name FROM players p WHERE p.playerid = pn.playerid LIMIT 1) AS name,
            MIN(pn.seen) AS fs
       FROM player_names pn
      GROUP BY pn.playerid
      ORDER BY fs DESC
      LIMIT ?`,
    [limit]
  );
  return rows.filter((r) => r.name).map((r) => ({ uid: r.playerid, name: r.name, firstSeen: r.fs }));
}

export interface HouseSale {
  id: number; price: number; sellerUid: string; sellerName: string;
  classname: string; x: number; y: number;
}

/** All houses currently listed for sale (sale > 0), with seller + map position. */
export async function getHousesForSale(): Promise<HouseSale[]> {
  const rows = await q<{
    id: number; sale: number | string; owners: string; classname: string | null;
    worldspace: string | null; sellerName: string | null;
  }>(
    `SELECT h.id, h.sale, h.owners, h.classname, h.worldspace,
            (SELECT name FROM players p WHERE p.playerid = h.owners LIMIT 1) AS "sellerName"
       FROM houses h
      WHERE h.sale > 0
      ORDER BY h.sale DESC`
  );
  return rows
    .map((r) => {
      const pos = decodeArray<number>(r.worldspace);
      return {
        id: r.id,
        price: num(r.sale),
        sellerUid: r.owners,
        sellerName: r.sellerName ?? "",
        classname: r.classname ?? "House",
        x: num(pos[0]),
        y: num(pos[1]),
      };
    })
    .filter((h) => h.x > 0 && h.y > 0);
}

export async function isPlayerOnline(uid: string): Promise<boolean> {
  const r = await one<{ n: number }>(
    "SELECT COUNT(*) n FROM online WHERE playerid=? AND instance=?", [uid, DB_INSTANCE]
  );
  return num(r?.n) > 0;
}

export interface AdminLogRow {
  id: number; ts: Date | string; actor_id: string; actor_name: string;
  target_id: string | null; target_name: string | null; action: string; detail: string | null;
}
/** Recent admin economy edits — for a target player, or globally if null. */
export async function getAdminLog(targetId: string | null, limit = 20): Promise<AdminLogRow[]> {
  if (targetId) {
    return q<AdminLogRow>("SELECT * FROM web_admin_log WHERE target_id=? ORDER BY id DESC LIMIT ?", [targetId, limit]);
  }
  return q<AdminLogRow>("SELECT * FROM web_admin_log ORDER BY id DESC LIMIT ?", [limit]);
}

/** Recent server-control actions (lock / reboot / update) for the Server page audit. */
export async function getServerLog(limit = 20): Promise<AdminLogRow[]> {
  return q<AdminLogRow>(
    "SELECT * FROM web_admin_log WHERE action LIKE 'server\\_%' ORDER BY id DESC LIMIT ?", [limit]);
}

// Live server-control state. The website writes intents here; a game-box agent
// (server_control_agent.py) reads the same DB and actuates via BE RCON + the
// restart_watchdog. `svrlock` = desired lock; `web_cmd` = a queued reboot/update.
export interface ServerControlRow {
  svrlock: number; lock_by: string | null; lock_at: Date | string | null;
  web_cmd: string | null; web_cmd_secs: number; web_cmd_by: string | null;
  web_cmd_at: Date | string | null; web_cmd_eta: Date | string | null;
  web_cmd_status: string | null; restart_now: number; hard_pending: number;
}
export async function getServerControl(): Promise<ServerControlRow | null> {
  return one<ServerControlRow>(
    `SELECT svrlock, lock_by, lock_at, web_cmd, web_cmd_secs, web_cmd_by,
            web_cmd_at, web_cmd_eta, web_cmd_status, restart_now, hard_pending
       FROM server_control WHERE id=1 LIMIT 1`);
}

export async function getPlayerVehicles(uid: string): Promise<VehicleRow[]> {
  return q<VehicleRow>(
    `SELECT id, side, classname, type, plate, customplate, color, active, alive, listed
       FROM vehicles WHERE pid=? ORDER BY side, type, classname`, [uid]
  );
}

export async function getPlayerHouses(uid: string): Promise<HouseRow[]> {
  return q<HouseRow>(
    `SELECT id, oid, worldspace, locked, sale, vcap, phys_cap, greenhouse, barrel, classname
       FROM houses WHERE owners=? ORDER BY id`, [uid]
  );
}

// Houses incl. raw stored inventory — for the Admin+ "place item in house" tool.
export interface HouseAdminRow {
  id: number; oid: string; classname: string | null;
  vcap: number; phys_cap: number; vinv: string | null; pinv: string | null;
}
export async function getPlayerHousesAdmin(uid: string): Promise<HouseAdminRow[]> {
  return q<HouseAdminRow>(
    `SELECT id, oid, classname, vcap, phys_cap, vinv, pinv
       FROM houses WHERE owners=? ORDER BY id`, [uid]
  );
}

export async function getPlayerActivity(uid: string, limit = 40): Promise<ActivityRow[]> {
  return q<ActivityRow>(
    `SELECT id, ts, tag, playerid, name, message
       FROM log WHERE playerid=? ORDER BY id DESC LIMIT ?`, [uid, limit]
  );
}

export interface MailItem { raw: unknown }
export async function getMailbox(uid: string): Promise<unknown[]> {
  const g = await one<{ mailbox: string | null }>(
    "SELECT mailbox FROM players_global WHERE playerid=? LIMIT 1", [uid]
  );
  return decodeArray(g?.mailbox ?? null);
}

// ---------------------------------------------------------------- gangs

export async function listGangs(search?: string): Promise<(GangRow & { members: number })[]> {
  const where = search ? "WHERE g.name LIKE ?" : "";
  const params = search ? [`%${search}%`] : [];
  return q<GangRow & { members: number }>(
    `SELECT g.id, g.name, g.bank, g.experience, g.inviterank, g.kickrank, g.house_pos,
            (SELECT COUNT(*) FROM players p WHERE p.gang0 = g.id) AS members
       FROM gangs g ${where}
      ORDER BY g.experience DESC`, params
  );
}

export async function getGangDetail(id: number): Promise<GangDetail | null> {
  const g = await one<GangRow>("SELECT * FROM gangs WHERE id=? LIMIT 1", [id]);
  if (!g) return null;
  const [members, veh, wars, fort] = await Promise.all([
    q<{ playerid: string; name: string; gangrank0: number }>(
      "SELECT playerid, name, gangrank0 FROM players WHERE gang0=? ORDER BY gangrank0 ASC", [id]
    ),
    one<{ n: number }>("SELECT COUNT(*) n FROM gang_vehicles WHERE gang_id=?", [id]),
    q<{ gang1: number; gang2: number }>(
      "SELECT gang1, gang2 FROM wars WHERE gang1=? OR gang2=?", [id, id]
    ),
    one<{ leaderboard: string | null }>(
      "SELECT leaderboard FROM gangfort WHERE id=1 LIMIT 1"
    ),
  ]);
  const fortBoard = decodeArray<[number, string, number]>(fort?.leaderboard ?? null);
  const fortWins = fortBoard.find((e) => num(e?.[0]) === id)?.[2] ?? 0;
  return {
    ...g,
    members: members.map((m) => ({ uid: m.playerid, name: m.name, rank: num(m.gangrank0, 5) })),
    vehicleCount: num(veh?.n),
    warIds: wars.map((w) => (num(w.gang1) === id ? num(w.gang2) : num(w.gang1))),
    fortWins: num(fortWins),
  };
}

// ---------------------------------------------------------------- world / server

export async function getServerStatus(): Promise<{ online: number; players: { uid: string; name: string }[] }> {
  const rows = await q<{ playerid: string; name: string }>(
    "SELECT playerid, name FROM online WHERE instance=? ORDER BY name", [DB_INSTANCE]
  );
  return { online: rows.length, players: rows.map((r) => ({ uid: r.playerid, name: r.name })) };
}

export async function globalActivity(limit = 50, tags?: string[]): Promise<ActivityRow[]> {
  if (tags && tags.length) {
    const ph = tags.map(() => "?").join(",");
    return q<ActivityRow>(
      `SELECT id, ts, tag, playerid, name, message FROM log
        WHERE tag IN (${ph}) ORDER BY id DESC LIMIT ?`, [...tags, limit]
    );
  }
  return q<ActivityRow>(
    `SELECT id, ts, tag, playerid, name, message FROM log ORDER BY id DESC LIMIT ?`, [limit]
  );
}

export interface Territories {
  turf: { id: number; gang: number | null }[];
  cartels: { cartel: string; gangId: string | null; progress: number }[];
  captures: { id: number; gang: number | null; percent: number; level: number }[];
  fort: { active: number; winnerName: string | null; ends: number } | null;
}

export async function getTerritories(): Promise<Territories> {
  const [turf, cartels, captures, fort] = await Promise.all([
    q<{ id: number; gang: number | null }>("SELECT id, gang FROM turf ORDER BY id"),
    q<{ cartel: string; gang_id: string | null; progress: number }>(
      "SELECT cartel, gang_id, progress FROM cartel_state"
    ),
    q<{ id: number; gang: number | null; percent: number; level: number }>(
      "SELECT id, gang, percent, level FROM captures ORDER BY id"
    ),
    one<{ active: number; winner_name: string | null; ends: number }>(
      "SELECT active, winner_name, ends FROM gangfort WHERE id=1 LIMIT 1"
    ),
  ]);
  return {
    turf: turf.map((t) => ({ id: num(t.id), gang: t.gang })),
    cartels: cartels.map((c) => ({ cartel: c.cartel, gangId: c.gang_id, progress: num(c.progress) })),
    captures: captures.map((c) => ({ id: num(c.id), gang: c.gang, percent: num(c.percent), level: num(c.level) })),
    fort: fort ? { active: num(fort.active), winnerName: fort.winner_name, ends: num(fort.ends) } : null,
  };
}

// governor election
export async function getGovernor(): Promise<{ candidate: string; name: string; votes: number }[]> {
  const rows = await q<{ candidate: string; votes: number; name: string | null }>(
    `SELECT v.candidate, COUNT(*) votes,
            (SELECT name FROM players p WHERE p.playerid = v.candidate LIMIT 1) AS name
       FROM votes v GROUP BY v.candidate ORDER BY votes DESC`
  );
  return rows.map((r) => ({ candidate: r.candidate, name: r.name ?? "Unknown", votes: num(r.votes) }));
}

// MaxSec applications
export interface MaxSecApplication {
  id: number; discord_name: string; ig_name: string; pid: string;
  time_on_server: string; cop_experience: string; why: string; disciplinary: string;
  status: "pending" | "accepted" | "denied"; reviewer_name: string | null;
  created_at: Date; decided_at: Date | null;
}
async function getFactionApplications(faction: "apd" | "ng", status?: string): Promise<MaxSecApplication[]> {
  const params: string[] = [faction];
  let where = "WHERE faction=?";
  if (status) { where += " AND status=?"; params.push(status); }
  return q<MaxSecApplication>(
    `SELECT id, discord_name, ig_name, pid, time_on_server, cop_experience, why,
            disciplinary, status, reviewer_name, created_at, decided_at
       FROM maxsec_applications ${where} ORDER BY created_at DESC`, params
  );
}
export function getMaxSecApplications(status?: string) { return getFactionApplications("apd", status); }
export function getTTApplications(status?: string) { return getFactionApplications("ng", status); }

export async function getMaxSecRoster(): Promise<{ uid: string; name: string; coplevel: number; retired: number }[]> {
  const rows = await q<{ playerid: string; name: string; coplevel: number; copretired: number }>(
    `SELECT g.playerid, p.name, g.coplevel, g.copretired
       FROM players_global g JOIN players p ON p.playerid = g.playerid
      WHERE g.coplevel > 0 ORDER BY g.coplevel DESC, p.name ASC`
  );
  return rows.map((r) => ({ uid: r.playerid, name: r.name, coplevel: num(r.coplevel), retired: num(r.copretired) }));
}

export async function getWantedList(): Promise<{ uid: string; name: string; bounty: number }[]> {
  const rows = await q<{ playerid: string; name: string; bounty: number }>(
    "SELECT playerid, name, bounty FROM wanted WHERE bounty > 0 ORDER BY bounty DESC"
  );
  return rows.map((r) => ({ uid: r.playerid, name: r.name, bounty: num(r.bounty) }));
}
