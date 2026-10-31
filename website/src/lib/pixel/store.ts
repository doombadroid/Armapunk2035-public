// Armapunk Pixel v3 persistence. One jsonb row per player plus denormalised columns for the roster,
// leaderboard and dispatch; shared rows for the market, NPC crime, gangs and the poker table; an
// append-only event log that is the world feed; the chat table with its revision / generation
// cursor. Every read and action runs inside a transaction that locks the player's row (and the
// shared rows it may write), so two tabs cannot double-spend.
import type { PoolClient } from "pg";
import { pool } from "@/lib/db";
import { chatWindow } from "./chat";
import { CITIES, INFERRED, TRAVEL } from "./content";
import { cheatsFor } from "./cheats";
import { apply, career, factionOf, gangCap, levelFromXp, netWorth, newPokerTable, newState, seizable, tick, visibleAt } from "./engine";
import { gangLevelFromXp } from "./level";
import { ONLINE_MS } from "./rules";
import { gangProfile, snapshot } from "./view";
import type {
  Action, ActionResult, ChatCursor, ChatRow, CityId, DispatchRow, Faction, FeedEvent, FeedRow, GangDirectoryRow, GangRecord, LeaderboardRow,
  PlayerState, PokerTable, RosterRow, Shared, Snapshot, SuspectRow, WireGangProfile, World,
} from "./types";

/** Page prop `canAccessCasino` (the plan: true). */
export const CASINO_ENABLED = true;

export interface Viewer { uid: string; name: string; avatar?: string | null }

interface PlayerRow {
  steamid: string; name: string; avatar_url: string; faction: Faction | null; city: CityId; level: number | string; prestige: number | string;
  net_worth: number | string; gang_id: string | null; gang_tag: string | null; heat: number | string; wanted: boolean;
  jailed: boolean; travelling: boolean; last_seen: number | string; state?: PlayerState;
}

const PLAYER_COLS = `p.steamid, p.name, p.avatar_url, p.faction, p.city, p.level, p.prestige, p.net_worth, p.gang_id, g.tag AS gang_tag, p.heat, p.wanted,
  (p.jailed_until IS NOT NULL AND p.jailed_until > now()) AS jailed, p.travelling, EXTRACT(EPOCH FROM p.last_seen) * 1000 AS last_seen`;
const PLAYER_FROM = `FROM web_pixel_players p LEFT JOIN web_pixel_gangs g ON g.id = p.gang_id`;

// ---- shared rows

async function loadShared(c: PoolClient): Promise<Shared> {
  const market = await c.query<{ city: string; item: string; mult: string | number; at: string | number }>(
    "SELECT city, item, mult, EXTRACT(EPOCH FROM updated_at) * 1000 AS at FROM web_pixel_market"
  );
  const npc = await c.query<{ city: CityId; value: string | number; at: string | number }>(
    "SELECT city, value, EXTRACT(EPOCH FROM updated_at) * 1000 AS at FROM web_pixel_npc_crime"
  );
  const gangs = await c.query<{ id: string; record: GangRecord }>("SELECT id, record FROM web_pixel_gangs ORDER BY id FOR UPDATE");
  const poker = await c.query<{ state: PokerTable }>("SELECT state FROM web_pixel_casino WHERE id = 'poker' FOR UPDATE");
  const sh: Shared = { market: {}, npcCrime: {} as Shared["npcCrime"], gangs: {}, poker: poker.rows[0]?.state ?? newPokerTable() };
  for (const r of market.rows) sh.market[`${r.city}:${r.item}`] = { mult: Number(r.mult), at: Number(r.at) };
  for (const r of npc.rows) sh.npcCrime[r.city] = { value: Number(r.value), at: Number(r.at) };
  for (const r of gangs.rows) sh.gangs[r.id] = r.record;
  return sh;
}

async function saveShared(c: PoolClient, before: Shared, after: Shared): Promise<void> {
  for (const [k, row] of Object.entries(after.market)) {
    const b = before.market[k];
    if (b && b.mult === row.mult && b.at === row.at) continue;
    const i = k.indexOf(":");
    await c.query(
      `INSERT INTO web_pixel_market (city, item, mult, updated_at) VALUES ($1, $2, $3, to_timestamp($4 / 1000.0))
       ON CONFLICT (city, item) DO UPDATE SET mult = EXCLUDED.mult, updated_at = EXCLUDED.updated_at`,
      [k.slice(0, i), k.slice(i + 1), row.mult, row.at]
    );
  }
  for (const [city, row] of Object.entries(after.npcCrime)) {
    const b = before.npcCrime[city as CityId];
    if (b && b.value === row.value && b.at === row.at) continue;
    await c.query(
      `INSERT INTO web_pixel_npc_crime (city, value, updated_at) VALUES ($1, $2, to_timestamp($3 / 1000.0))
       ON CONFLICT (city) DO UPDATE SET value = EXCLUDED.value, updated_at = EXCLUDED.updated_at`,
      [city, row.value, row.at]
    );
  }
  for (const id of Object.keys(before.gangs)) if (!after.gangs[id]) await c.query("DELETE FROM web_pixel_gangs WHERE id = $1", [id]);
  for (const [id, g] of Object.entries(after.gangs)) {
    if (JSON.stringify(before.gangs[id]) === JSON.stringify(g)) continue;
    await c.query(
      `INSERT INTO web_pixel_gangs (id, name, tag, leader_steamid, record, created_at) VALUES ($1, $2, $3, $4, $5::jsonb, to_timestamp($6 / 1000.0))
       ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, tag = EXCLUDED.tag, leader_steamid = EXCLUDED.leader_steamid, record = EXCLUDED.record`,
      [id, g.name, g.tag, g.leaderId, JSON.stringify(g), g.createdAt]
    );
  }
  if (JSON.stringify(before.poker) !== JSON.stringify(after.poker)) {
    await c.query(
      `INSERT INTO web_pixel_casino (id, state, updated_at) VALUES ('poker', $1::jsonb, now())
       ON CONFLICT (id) DO UPDATE SET state = EXCLUDED.state, updated_at = now()`,
      [JSON.stringify(after.poker)]
    );
  }
}

async function insertEvents(c: PoolClient, steamId: string, events: FeedEvent[]): Promise<void> {
  for (const e of events) await c.query("INSERT INTO web_pixel_events (steamid, kind, text) VALUES ($1, $2, $3)", [steamId, e.kind, e.text]);
}

// ---- chat

async function chatMeta(c: PoolClient): Promise<{ revision: number; generation: string }> {
  await c.query("INSERT INTO web_pixel_meta (key, value) VALUES ('chat_generation', gen_random_uuid()::text), ('chat_revision', '1') ON CONFLICT (key) DO NOTHING");
  const r = await c.query<{ key: string; value: string }>("SELECT key, value FROM web_pixel_meta WHERE key IN ('chat_generation', 'chat_revision')");
  const m = Object.fromEntries(r.rows.map((x) => [x.key, x.value]));
  return { revision: Number(m.chat_revision ?? 1), generation: String(m.chat_generation ?? "") };
}

async function loadChat(c: PoolClient, cursor: ChatCursor | null) {
  const meta = await chatMeta(c);
  const r = await c.query<{ id: string | number; at: string | number; steamid: string; name: string; faction: Faction | null; text: string }>(
    "SELECT id, EXTRACT(EPOCH FROM at) * 1000 AS at, steamid, name, faction, text FROM web_pixel_chat ORDER BY id DESC LIMIT $1",
    [INFERRED.chatRetain]
  );
  const retained: ChatRow[] = r.rows.map((x) => ({ id: Number(x.id), at: Number(x.at), steamId: x.steamid, name: x.name, faction: x.faction, text: x.text }));
  return chatWindow(retained, meta.revision, meta.generation, cursor);
}

/** Insert one message and keep the newest chatRetain rows; a prune bumps the revision so clients refetch the window. */
async function insertChat(c: PoolClient, s: PlayerState, text: string): Promise<void> {
  await c.query("INSERT INTO web_pixel_chat (steamid, name, faction, text) VALUES ($1, $2, $3, $4)", [s.steamId, s.name, s.faction, text.trim()]);
  const pruned = await c.query(
    "DELETE FROM web_pixel_chat WHERE id <= COALESCE((SELECT id FROM web_pixel_chat ORDER BY id DESC OFFSET $1 LIMIT 1), 0)",
    [INFERRED.chatRetain]
  );
  if ((pruned.rowCount ?? 0) > 0) {
    await c.query("UPDATE web_pixel_meta SET value = (value::bigint + 1)::text WHERE key = 'chat_revision'");
  }
}

// ---- world

function rosterRow(r: PlayerRow, viewerIsCop: boolean, now: number): RosterRow {
  const row: RosterRow = {
    steamId: r.steamid, name: r.name, avatarUrl: r.avatar_url, faction: r.faction, cityId: r.city, level: Number(r.level), prestige: Number(r.prestige),
    netWorth: Number(r.net_worth), jailed: Boolean(r.jailed), travelling: Boolean(r.travelling),
  };
  if (r.gang_tag) row.gangTag = r.gang_tag;
  if (viewerIsCop && r.faction === "civ") {
    row.wanted = Boolean(r.wanted);
    row.heat = Math.round(Number(r.heat));
  }
  void now;
  return row;
}

async function loadWorld(c: PoolClient, s: PlayerState, sh: Shared, now: number, cursor: ChatCursor | null, avatarUrl: string): Promise<World> {
  const viewerIsCop = s.faction === "cop";
  const onlineRows = (
    await c.query<PlayerRow>(
      `SELECT ${PLAYER_COLS} ${PLAYER_FROM} WHERE p.faction IS NOT NULL AND p.last_seen >= to_timestamp($1 / 1000.0) ORDER BY p.last_seen DESC LIMIT 200`,
      [now - ONLINE_MS]
    )
  ).rows;
  const roster = onlineRows.map((r) => rosterRow(r, viewerIsCop, now));
  const headsByCity: Partial<Record<CityId, number>> = {};
  for (const r of roster) headsByCity[r.cityId] = (headsByCity[r.cityId] ?? 0) + 1;

  const lb = await c.query<PlayerRow>(`SELECT ${PLAYER_COLS} ${PLAYER_FROM} WHERE p.faction IS NOT NULL ORDER BY p.net_worth DESC, p.level DESC LIMIT 10`);
  const leaderboard: LeaderboardRow[] = lb.rows.map((r) => ({ name: r.name, avatarUrl: r.avatar_url, netWorth: Number(r.net_worth), level: Number(r.level), faction: r.faction }));

  const feedRows = await c.query<{ id: string | number; at: string | number; steamid: string; name: string; kind: FeedRow["kind"]; text: string }>(
    `SELECT e.id, EXTRACT(EPOCH FROM e.at) * 1000 AS at, e.steamid, p.name, e.kind, e.text
       FROM web_pixel_events e JOIN web_pixel_players p ON p.steamid = e.steamid ORDER BY e.id DESC LIMIT $1`,
    [INFERRED.feedLimit]
  );
  const feed: FeedRow[] = feedRows.rows.map((r) => ({ id: Number(r.id), at: Number(r.at), kind: r.kind, steamId: r.steamid, name: r.name, text: r.text }));

  const leaderNames = await c.query<{ steamid: string; name: string }>("SELECT steamid, name FROM web_pixel_players WHERE steamid = ANY($1)", [
    Object.values(sh.gangs).map((g) => g.leaderId),
  ]);
  const nameOf = Object.fromEntries(leaderNames.rows.map((r) => [r.steamid, r.name]));
  const gangs: GangDirectoryRow[] = Object.values(sh.gangs)
    .sort((a, b) => b.xp - a.xp || a.createdAt - b.createdAt)
    .map((g) => {
      const lv = gangLevelFromXp(g.xp).level;
      return { id: g.id, name: g.name, tag: g.tag, level: lv, members: g.members.length, cap: gangCap(lv), leaderName: nameOf[g.leaderId] ?? "Unknown", private: g.private };
    });

  const myGang = s.gangId ? sh.gangs[s.gangId] : undefined;
  const gangMembers: World["gangMembers"] = {};
  if (myGang) {
    const rows = await c.query<{ steamid: string; name: string; level: number | string; prestige: number | string; last_seen: number | string }>(
      "SELECT steamid, name, level, prestige, EXTRACT(EPOCH FROM last_seen) * 1000 AS last_seen FROM web_pixel_players WHERE steamid = ANY($1)",
      [myGang.members.map((m) => m.steamId)]
    );
    for (const r of rows.rows) gangMembers[r.steamid] = { name: r.name, level: Number(r.level), prestige: Number(r.prestige), online: now - Number(r.last_seen) <= ONLINE_MS };
  }

  let dispatch: DispatchRow[] = [];
  let suspects: SuspectRow[] = [];
  const others = onlineRows.filter((r) => r.steamid !== s.steamId);
  const manpowerMult = await manpowerFor(c, s, now);
  if (viewerIsCop) {
    dispatch = CITIES.map((city) => {
      const wanted = others.filter((r) => r.faction === "civ" && r.city === city.id && r.wanted);
      return {
        cityId: city.id,
        wantedCount: wanted.length,
        officerCount: onlineRows.filter((r) => r.faction === "cop" && r.city === city.id).length,
        travelSeconds: TRAVEL[s.cityId][city.id],
        latestSeen: wanted.length ? Math.max(...wanted.map((r) => Number(r.last_seen))) : null,
      };
    });
    const ids = others.filter((r) => r.faction === "civ" && r.city === s.cityId && r.wanted && !r.jailed).map((r) => r.steamid);
    if (ids.length) {
      const rows = await c.query<{ steamid: string; name: string; avatar_url: string; heat: string | number; state: PlayerState }>(
        "SELECT steamid, name, avatar_url, heat, state FROM web_pixel_players WHERE steamid = ANY($1)",
        [ids]
      );
      suspects = rows.rows.map((r) => ({
        steamId: r.steamid, name: r.name, avatarUrl: r.avatar_url, heat: Math.round(Number(r.heat)), estValue: seizable(r.state.careers.civ),
        pursued: !!r.state.duel && r.state.duel.status !== "resolved",
      }));
    }
  }

  const chat = await loadChat(c, cursor);
  return { roster, gangs, online: roster.length, headsByCity, feed, dispatch, suspects, leaderboard, gangMembers, manpowerMult, avatarUrl, ...chat };
}

// ---- the transaction

interface Step { state: PlayerState; shared: Shared; events: FeedEvent[]; result: ActionResult | null; chatText?: string; pokerBefore?: PokerTable }

/** Officers' payouts scale with the civilian / officer ratio of the other players online in the city: clamp((civs + 1) / (cops + 1), 0.5, 1.5). */
async function manpowerFor(c: PoolClient, s: PlayerState, now: number): Promise<number> {
  if (s.faction !== "cop") return 1;
  const r = await c.query<{ faction: Faction; n: string | number }>(
    "SELECT faction, count(*) AS n FROM web_pixel_players WHERE steamid <> $1 AND city = $2 AND faction IS NOT NULL AND last_seen >= to_timestamp($3 / 1000.0) GROUP BY faction",
    [s.steamId, s.cityId, now - ONLINE_MS]
  );
  const civs = Number(r.rows.find((x) => x.faction === "civ")?.n ?? 0);
  const cops = Number(r.rows.find((x) => x.faction === "cop")?.n ?? 0);
  return Math.min(INFERRED.manpowerMax, Math.max(INFERRED.manpowerMin, (civs + 1) / (cops + 1)));
}

async function withPlayer(viewer: Viewer, now: number, cursor: ChatCursor | null, fn: (state: PlayerState, shared: Shared, manpower: number) => Step): Promise<{ snapshot: Snapshot; result: ActionResult | null }> {
  const c = await pool().connect();
  try {
    await c.query("BEGIN");
    const r = await c.query<{ state: PlayerState | { v?: number } }>("SELECT state FROM web_pixel_players WHERE steamid = $1 FOR UPDATE", [viewer.uid]);
    let state: PlayerState;
    if (r.rows[0] && (r.rows[0].state as PlayerState).v === 3) {
      state = r.rows[0].state as PlayerState;
    } else {
      state = newState(viewer.uid, viewer.name, now);
      if (r.rows[0]) {
        await c.query("DELETE FROM web_pixel_events WHERE steamid = $1", [viewer.uid]);
      } else {
        await c.query("INSERT INTO web_pixel_players (steamid, name, avatar_url, state) VALUES ($1, $2, $3, $4::jsonb)", [viewer.uid, viewer.name, viewer.avatar ?? "", JSON.stringify(state)]);
      }
    }
    state.name = viewer.name;
    // Owner advantages ride on the save but are resolved here, from the environment, on every load:
    // the engine never reads process.env, and a change to OWNER_STEAMID takes effect on the next poll.
    state.cheats = cheatsFor(viewer.uid, process.env.OWNER_STEAMID);
    const shared = await loadShared(c);
    const out = fn(state, shared, await manpowerFor(c, state, now));
    const s = out.state;
    const cr = career(s);
    const civ = s.careers.civ;
    await c.query(
      `UPDATE web_pixel_players SET state = $2::jsonb, name = $3, avatar_url = $4, faction = $5, city = $6, level = $7, prestige = $8, net_worth = $9,
              gang_id = $10, heat = $11, wanted = $12, jailed_until = $13, travelling = $14, last_seen = now(), updated_at = now()
        WHERE steamid = $1`,
      [
        viewer.uid, JSON.stringify(s), viewer.name, viewer.avatar ?? "", s.faction, s.cityId, levelFromXp(cr.xp).level, cr.prestige, Math.round(netWorth(cr)),
        s.gangId, s.heat, s.faction === "civ" && s.heat >= visibleAt(civ), s.custody ? new Date(s.custody.jailedUntil) : null, s.travelTo !== null,
      ]
    );
    await saveShared(c, shared, out.shared);
    if (out.events.length) await insertEvents(c, viewer.uid, out.events);
    if (out.chatText !== undefined) await insertChat(c, s, out.chatText);
    if (out.pokerBefore && out.shared.poker.lastResult && out.shared.poker.lastResult !== shared.poker.lastResult) {
      for (const w of out.shared.poker.lastResult.winners) {
        if (w.steamId === viewer.uid) continue;
        const seat = out.pokerBefore.seats.find((x) => x.steamId === w.steamId);
        if (!seat) continue;
        await c.query(
          `UPDATE web_pixel_players SET state = jsonb_set(state, ARRAY['careers', $2, 'cash'], to_jsonb((state->'careers'->$2->>'cash')::numeric + $3)) WHERE steamid = $1`,
          [w.steamId, seat.faction, w.payout]
        );
      }
    }
    const world = await loadWorld(c, s, out.shared, now, cursor, viewer.avatar ?? "");
    await c.query("COMMIT");
    return { snapshot: snapshot(s, out.shared, world, now, CASINO_ENABLED), result: out.result };
  } catch (e) {
    await c.query("ROLLBACK").catch(() => undefined);
    throw e;
  } finally {
    c.release();
  }
}

/** GET /api/pixel/state: tick, persist, snapshot. */
export async function getState(viewer: Viewer, cursor: ChatCursor | null): Promise<Snapshot> {
  const now = Date.now();
  const r = await withPlayer(viewer, now, cursor, (state, shared) => {
    const t = tick(state, shared, now);
    return { state: t.state, shared: t.shared, events: t.events, result: null };
  });
  return r.snapshot;
}

/** POST /api/pixel/action: apply atomically; on rejection the ticked state is still persisted. */
export async function doAction(viewer: Viewer, action: Action, cursor: ChatCursor | null): Promise<{ snapshot: Snapshot; result: ActionResult }> {
  const now = Date.now();
  const r = await withPlayer(viewer, now, cursor, (state, shared, manpower) => {
    const out = apply(state, shared, action, now, Math.random, manpower);
    const step: Step = { ...out, result: out.result, pokerBefore: shared.poker };
    if (action.type === "chat" && out.result.ok) step.chatText = action.text;
    return step;
  });
  return { snapshot: r.snapshot, result: r.result as ActionResult };
}

/** GET /api/pixel/gang?id= */
export async function getGang(viewer: Viewer, gangId: string): Promise<WireGangProfile | null> {
  const c = await pool().connect();
  try {
    const g = await c.query<{ record: GangRecord }>("SELECT record FROM web_pixel_gangs WHERE id = $1", [gangId]);
    if (!g.rows[0]) return null;
    const record = g.rows[0].record;
    const rows = await c.query<{ steamid: string; name: string; level: number | string; prestige: number | string; last_seen: number | string }>(
      "SELECT steamid, name, level, prestige, EXTRACT(EPOCH FROM last_seen) * 1000 AS last_seen FROM web_pixel_players WHERE steamid = ANY($1)",
      [[...record.members.map((m) => m.steamId), record.leaderId]]
    );
    const now = Date.now();
    const members: World["gangMembers"] = {};
    for (const r of rows.rows) members[r.steamid] = { name: r.name, level: Number(r.level), prestige: Number(r.prestige), online: now - Number(r.last_seen) <= ONLINE_MS };
    return gangProfile({ market: {}, npcCrime: {} as Shared["npcCrime"], gangs: { [record.id]: record }, poker: newPokerTable() }, gangId, viewer.uid, members);
  } finally {
    c.release();
  }
}

/** The page's initial snapshot (no chat cursor yet). */
export async function getView(steamId: string, name: string, avatar?: string | null): Promise<Snapshot> {
  return getState({ uid: steamId, name, avatar }, null);
}

void factionOf;
