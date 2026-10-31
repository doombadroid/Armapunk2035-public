// Round-trip of the store against a real Postgres with the v3 DDL applied. Opt-in: set
// PIXEL_TEST_DB=postgres://user@host:port/db (the deploy smoke runs it against a scratch cluster);
// without it the suite is skipped so `npm test` needs no database.
import { afterAll, beforeAll, describe, expect, it } from "vitest";

const url = process.env.PIXEL_TEST_DB;
const run = url ? describe : describe.skip;

run("store round-trip (PIXEL_TEST_DB)", () => {
  const viewer = { uid: "76561190000000001", name: "Doomba", avatar: "https://avatars.fastly.steamstatic.com/x_full.jpg" };
  let store: typeof import("../store");

  beforeAll(async () => {
    const u = new URL(url as string);
    process.env.DB_HOST = u.hostname;
    process.env.DB_PORT = u.port || "5432";
    process.env.DB_USER = decodeURIComponent(u.username || "armapunk");
    process.env.DB_PASSWORD = decodeURIComponent(u.password || "");
    process.env.DB_NAME = u.pathname.replace(/^\//, "");
    store = await import("../store");
    const { pool } = await import("@/lib/db");
    await pool().query("DELETE FROM web_pixel_players; DELETE FROM web_pixel_events; DELETE FROM web_pixel_chat; DELETE FROM web_pixel_gangs; DELETE FROM web_pixel_market; DELETE FROM web_pixel_casino; DELETE FROM web_pixel_npc_crime;");
  });

  afterAll(async () => {
    const { pool } = await import("@/lib/db");
    await pool().end();
  });

  it("creates a fresh save on first read with faction null and the reference snapshot shape", async () => {
    const snap = await store.getState(viewer, null);
    expect(snap.me.faction).toBeNull();
    expect(snap.me.avatarUrl).toBe(viewer.avatar);
    expect(Object.keys(snap.me)).toHaveLength(63);
    expect(snap.chatGeneration).toMatch(/^[0-9a-f-]{36}$/);
    expect(snap.chatRevision).toBe(1);
    expect(snap.roster).toEqual([]);
    expect(snap.npcCrime.kavala).toBe(100);
    expect(snap.casino).toEqual({ blackjack: null, poker: { seats: [], pot: 0, buyIn: null, minPlayers: 2, lastResult: null } });
  });

  it("picks a career, works, sells, feeds and chats; the columns follow the save", async () => {
    const picked = await store.doAction(viewer, { type: "faction", faction: "civ" }, null);
    expect(picked.result).toEqual({ ok: true });
    expect(picked.snapshot.me.faction).toBe("civ");
    expect(picked.snapshot.roster).toHaveLength(1);
    expect(picked.snapshot.roster[0]).toMatchObject({ steamId: viewer.uid, name: "Doomba", faction: "civ", cityId: "kavala", level: 1, jailed: false, travelling: false });
    expect(picked.snapshot.online).toBe(1);
    expect(picked.snapshot.headsByCity).toEqual({ kavala: 1 });
    expect(picked.snapshot.feed[0]).toMatchObject({ kind: "join", name: "Doomba", text: "landed on the island as a civilian" });
    await new Promise((r) => setTimeout(r, 250));
    const worked = await store.doAction(viewer, { type: "work", siteId: "kav_apple" }, null);
    expect(worked.result.ok).toBe(true);
    expect((worked.result as { gained?: Record<string, number> }).gained?.apple).toBe(12);
    expect(worked.snapshot.me.inventory).toEqual({ apple: 12 });
    await new Promise((r) => setTimeout(r, 250));
    const sold = await store.doAction(viewer, { type: "sell", itemId: "apple", amount: "all" }, null);
    expect(sold.result).toMatchObject({ ok: true, cash: 96 });
    expect(sold.snapshot.mults.apple).toBeLessThan(1.18);
    expect(sold.snapshot.leaderboard[0]).toMatchObject({ name: "Doomba", netWorth: 96, level: 1, faction: "civ" });
    await new Promise((r) => setTimeout(r, 250));
    const cursor = { sinceChat: 0, chatRevision: sold.snapshot.chatRevision, chatGeneration: sold.snapshot.chatGeneration };
    const chatted = await store.doAction(viewer, { type: "chat", text: "hello" }, cursor);
    expect(chatted.result).toEqual({ ok: true });
    expect(chatted.snapshot.chat[0]).toMatchObject({ steamId: viewer.uid, name: "Doomba", faction: "civ", text: "hello" });
    const delta = await store.getState(viewer, { ...cursor, sinceChat: chatted.snapshot.chat[0].id });
    expect(delta.chat).toEqual([]);
    expect(delta.chatOldestId).toBe(chatted.snapshot.chat[0].id);
    const full = await store.getState(viewer, { ...cursor, chatGeneration: "stale" });
    expect(full.chat).toHaveLength(1);
  });

  it("rate limits back to back actions with the TOO_FAST error the route maps to 429", async () => {
    const { TOO_FAST } = await import("../engine");
    await new Promise((r) => setTimeout(r, 250));
    await store.doAction(viewer, { type: "travel", cityId: "neochori" }, null);
    const fast = await store.doAction(viewer, { type: "travel", cityId: "athira" }, null);
    expect(fast.result).toEqual({ ok: false, error: TOO_FAST });
  });

  it("founds a gang, lists it in the directory, serves its profile and dissolves it on reset", async () => {
    await new Promise((r) => setTimeout(r, 8000));
    const { pool } = await import("@/lib/db");
    const { XP_CURVE } = await import("../content");
    await pool().query(`UPDATE web_pixel_players SET state = jsonb_set(jsonb_set(state, '{careers,civ,cash}', '250000'), '{careers,civ,xp}', $2::text::jsonb) WHERE steamid = $1`, [viewer.uid, String(XP_CURVE[4])]);
    const made = await store.doAction(viewer, { type: "gangcreate", name: "Night Crew", tag: "nc" }, null);
    expect(made.result).toEqual({ ok: true, cash: -250_000 });
    expect(made.snapshot.me.gang).toMatchObject({ name: "Night Crew", tag: "NC", level: 1, cap: 5, isLeader: true, isPrivate: false, inviteCode: null });
    expect(made.snapshot.me.gang!.members).toEqual([{ steamId: viewer.uid, name: "Doomba", level: 5, prestige: 0, leader: true, online: true }]);
    expect(made.snapshot.gangs).toEqual([{ id: made.snapshot.me.gang!.id, name: "Night Crew", tag: "NC", level: 1, members: 1, cap: 5, leaderName: "Doomba", private: false }]);
    expect(made.snapshot.roster[0].gangTag).toBe("NC");
    const profile = await store.getGang(viewer, made.snapshot.me.gang!.id);
    expect(profile).toMatchObject({ name: "Night Crew", leaderName: "Doomba", isMine: true, private: false });
    expect(await store.getGang(viewer, "cnope")).toBeNull();
    await new Promise((r) => setTimeout(r, 250));
    const reset = await store.doAction(viewer, { type: "reset" }, null);
    expect(reset.snapshot.me.faction).toBeNull();
    expect(reset.snapshot.gangs).toEqual([]);
  }, 20_000);
});
