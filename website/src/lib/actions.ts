"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { q, one } from "./db";
import { getSession } from "./session";
import { getFaction, canManage, canManageSub, actionFor, maxGrant, ADMIN_WL_LEVEL, ECON_EDIT_LEVEL, SERVER_CTRL_LEVEL } from "./factions";
import { getActorPowers, getTargetRank, getSubValue, rankName } from "./whitelist";
import { BAN_DURATIONS, MOD_MAX_SECONDS } from "./bans";
import { bmEnabled, findPlayerBySteam, resolveFlagId, addFlag, removeFlag } from "./bm";
import { ticketCat, isValidCategory } from "./ticketCategories";
import { COMP_ITEMS } from "./compItems";
import { decodeHouseInv, encodeHouseInv, mergeItems, invTotal, sanitizeClass, type InvPair } from "./houseInv";
import { money } from "./format";
import { randomUUID } from "crypto";
import { writeFile, mkdir } from "fs/promises";
import path from "path";

async function requireAdmin(): Promise<{ uid: string; name: string }> {
  const s = await getSession();
  if (!s) throw new Error("Not authenticated");
  const p = await getActorPowers(s.uid);
  if (!(p.isOwner || p.adminlevel >= ADMIN_WL_LEVEL)) throw new Error("Forbidden");
  return { uid: s.uid, name: s.name };
}

function cleanReason(s: string): string {
  // mirror loonybot admin.py _clean: strip chars that break the server QUOTE() read
  return s.replace(/[\\'"`\r\n]/g, "").slice(0, 240);
}

function isStaff(s: { adminLevel: number; isOwner: boolean } | null): boolean {
  return !!s && (s.adminLevel > 0 || s.isOwner);
}

// May this session view/work a ticket: opener, staff, or the report's faction
// command (MaxSec Lt+ / TT Warrant Officer+ for apd/ng misconduct reports).
async function canWorkTicket(
  s: { uid: string; adminLevel: number; isOwner: boolean },
  ticket: { playerid: string; category: string }
): Promise<boolean> {
  if (ticket.playerid === s.uid || isStaff(s)) return true;
  const cat = ticketCat(ticket.category);
  if (cat.report === "apd" || cat.report === "ng") {
    const p = await getActorPowers(s.uid);
    if (cat.report === "apd" && p.ranks.police >= 5) return true;
    if (cat.report === "ng" && p.ranks.medic >= 4) return true;
  }
  return false;
}
function isEditor(s: { adminLevel: number; isOwner: boolean } | null): boolean {
  return !!s && (s.adminLevel >= 3 || s.isOwner);
}
function str(fd: FormData, k: string, max: number): string {
  return String(fd.get(k) ?? "").trim().slice(0, max);
}

// ---------------------------------------------------------------- tickets
export async function createTicket(fd: FormData) {
  const s = await getSession();
  if (!s) throw new Error("Not authenticated");
  const subject = str(fd, "subject", 160);
  const rawCat = str(fd, "category", 32);
  const category = isValidCategory(rawCat) ? rawCat : "general";
  const body = str(fd, "body", 4000);
  if (!subject || !body) return;

  const res = await q<never>(
    "INSERT INTO web_tickets (playerid, player_name, subject, category) VALUES (?,?,?,?)",
    [s.uid, s.name, subject, category]
  );
  // mysql2 returns ResultSetHeader on insert
  const insertId = (res as unknown as { insertId: number }).insertId;
  await q("INSERT INTO web_ticket_messages (ticket_id, author_id, author_name, is_staff, body) VALUES (?,?,?,?,?)",
    [insertId, s.uid, s.name, isStaff(s) ? 1 : 0, body]);

  revalidatePath("/support-tickets");
  redirect(`/support-tickets/${insertId}`);
}

export async function replyTicket(fd: FormData) {
  const s = await getSession();
  if (!s) throw new Error("Not authenticated");
  const ticketId = Number(fd.get("ticket_id"));
  const body = str(fd, "body", 4000);
  if (!ticketId || !body) return;

  const ticket = await one<{ playerid: string; status: string; category: string }>(
    "SELECT playerid, status, category FROM web_tickets WHERE id=? LIMIT 1", [ticketId]
  );
  if (!ticket) throw new Error("Ticket not found");
  if (!(await canWorkTicket(s, ticket))) throw new Error("Forbidden");

  // anyone who isn't the opener is an official responder (staff or faction command)
  const responder = ticket.playerid !== s.uid;
  await q("INSERT INTO web_ticket_messages (ticket_id, author_id, author_name, is_staff, body) VALUES (?,?,?,?,?)",
    [ticketId, s.uid, s.name, responder ? 1 : 0, body]);
  await q("UPDATE web_tickets SET status=?, updated_at=NOW() WHERE id=?",
    [responder ? "answered" : "open", ticketId]);

  revalidatePath(`/support-tickets/${ticketId}`);
}

export async function closeTicket(fd: FormData) {
  const s = await getSession();
  if (!s) throw new Error("Not authenticated");
  const ticketId = Number(fd.get("ticket_id"));
  const ticket = await one<{ playerid: string; category: string }>("SELECT playerid, category FROM web_tickets WHERE id=? LIMIT 1", [ticketId]);
  if (!ticket) return;
  if (!(await canWorkTicket(s, ticket))) throw new Error("Forbidden");
  await q("UPDATE web_tickets SET status='closed' WHERE id=?", [ticketId]);
  revalidatePath(`/support-tickets/${ticketId}`);
}

export async function reopenTicket(fd: FormData) {
  const s = await getSession();
  if (!s) throw new Error("Not authenticated");
  const ticketId = Number(fd.get("ticket_id"));
  const ticket = await one<{ playerid: string; category: string }>("SELECT playerid, category FROM web_tickets WHERE id=? LIMIT 1", [ticketId]);
  if (!ticket) return;
  if (!(await canWorkTicket(s, ticket))) throw new Error("Forbidden");
  await q("UPDATE web_tickets SET status='open', updated_at=NOW() WHERE id=?", [ticketId]);
  revalidatePath(`/support-tickets/${ticketId}`);
}

// ---------------------------------------------------------------- feature voting
export async function submitFeature(fd: FormData) {
  const s = await getSession();
  if (!s) throw new Error("Not authenticated");
  const title = str(fd, "title", 160);
  const body = str(fd, "body", 4000);
  if (!title) return;
  const res = await q<never>(
    "INSERT INTO web_feature_requests (playerid, author_name, title, body) VALUES (?,?,?,?)",
    [s.uid, s.name, title, body]
  );
  const id = (res as unknown as { insertId: number }).insertId;
  // author auto-votes
  await q("INSERT INTO web_feature_votes (feature_id, playerid) VALUES (?,?) ON CONFLICT DO NOTHING", [id, s.uid]);
  revalidatePath("/voting");
}

// up (dir=1) / down (dir=-1) vote. Re-casting the same direction removes the vote.
export async function castVote(fd: FormData) {
  const s = await getSession();
  if (!s) throw new Error("Not authenticated");
  const featureId = Number(fd.get("feature_id"));
  const dir = Number(fd.get("dir")) === -1 ? -1 : 1;
  if (!featureId) return;
  const existing = await one<{ vote: number }>(
    "SELECT vote FROM web_feature_votes WHERE feature_id=? AND playerid=? LIMIT 1", [featureId, s.uid]
  );
  if (existing && Number(existing.vote) === dir) {
    await q("DELETE FROM web_feature_votes WHERE feature_id=? AND playerid=?", [featureId, s.uid]);
  } else {
    await q(
      "INSERT INTO web_feature_votes (feature_id, playerid, vote) VALUES (?,?,?) ON CONFLICT (feature_id, playerid) DO UPDATE SET vote=EXCLUDED.vote",
      [featureId, s.uid, dir]
    );
  }
  revalidatePath("/voting");
  revalidatePath(`/voting/${featureId}`);
}

export async function addFeatureComment(fd: FormData) {
  const s = await getSession();
  if (!s) throw new Error("Not authenticated");
  const featureId = Number(fd.get("feature_id"));
  const body = str(fd, "body", 4000);
  if (!featureId || !body) return;
  await q(
    "INSERT INTO web_feature_comments (feature_id, author_id, author_name, body) VALUES (?,?,?,?)",
    [featureId, s.uid, s.name, body]
  );
  revalidatePath(`/voting/${featureId}`);
  revalidatePath("/voting");
}

// Save an uploaded voting image to the (persistent) uploads dir, served via
// /api/images/voting/<name>. Throws on bad type/size.
async function saveVotingImage(file: File): Promise<string> {
  if (!/^image\/(png|jpe?g|webp|gif)$/.test(file.type)) throw new Error("Unsupported image type");
  if (file.size > 5 * 1024 * 1024) throw new Error("Image too large (max 5MB)");
  const ext = file.type === "image/png" ? "png" : file.type === "image/webp" ? "webp" : file.type === "image/gif" ? "gif" : "jpg";
  const name = `${randomUUID()}.${ext}`;
  const dir = path.join(process.cwd(), "uploads", "voting");
  await mkdir(dir, { recursive: true });
  await writeFile(path.join(dir, name), Buffer.from(await file.arrayBuffer()));
  return `/api/images/voting/${name}`;
}

// Staff/editor: create a curated poll (title, markdown body, optional image, close date).
export async function createPoll(fd: FormData) {
  const s = await getSession();
  if (!isEditor(s)) throw new Error("Forbidden");
  const title = str(fd, "title", 160);
  const body = str(fd, "body", 4000);
  const days = Number(fd.get("closes_days"));
  if (!title) return;
  const image = fd.get("image");
  let imageUrl: string | null = null;
  if (image instanceof File && image.size > 0) imageUrl = await saveVotingImage(image);
  const closesAt = days > 0 ? new Date(Date.now() + days * 86_400_000) : null;
  const res = await q<never>(
    "INSERT INTO web_feature_requests (playerid, author_name, title, body, image_url, status, closes_at) VALUES (?,?,?,?,?, 'open', ?)",
    [s!.uid, s!.name, title, body || null, imageUrl, closesAt]
  );
  const id = (res as unknown as { insertId: number }).insertId;
  await q("INSERT INTO web_feature_votes (feature_id, playerid, vote) VALUES (?,?,1) ON CONFLICT DO NOTHING", [id, s!.uid]);
  revalidatePath("/voting");
  redirect(`/voting/${id}`);
}

export async function deleteFeature(fd: FormData) {
  const s = await getSession();
  if (!isEditor(s)) throw new Error("Forbidden");
  const id = Number(fd.get("feature_id"));
  if (!id) return;
  await q("DELETE FROM web_feature_votes WHERE feature_id=?", [id]);
  await q("DELETE FROM web_feature_comments WHERE feature_id=?", [id]);
  await q("DELETE FROM web_feature_requests WHERE id=?", [id]);
  revalidatePath("/voting");
  redirect("/voting");
}

// ---------------------------------------------------------------- admin economy edits
type Actor = { uid: string; name: string };

// gate: Admin (adminlevel>=3) or Owner may edit money / cars / gang funds.
async function requireEconomy(): Promise<{ s: Actor }> {
  const s = await getSession();
  if (!s) throw new Error("Not authenticated");
  const p = await getActorPowers(s.uid);
  if (!(p.isOwner || p.adminlevel >= ECON_EDIT_LEVEL)) throw new Error("Forbidden");
  return { s: { uid: s.uid, name: s.name } };
}

async function adminLog(s: Actor, targetId: string | null, targetName: string | null, action: string, detail: string) {
  await q(
    "INSERT INTO web_admin_log (actor_id, actor_name, target_id, target_name, action, detail) VALUES (?,?,?,?,?,?)",
    [s.uid, s.name, targetId, targetName, action, detail.slice(0, 255)]
  );
}

// ---------------------------------------------------------------------------
// Server control — lock / reboot (Senior Admin+) and update-PBO (Owner only).
// The website only WRITES intents into server_control; the game-box agent
// (deploy/server_control_agent.py) reads the same DB and actuates via BE RCON
// + the restart_watchdog. Nothing here touches the game process directly.
// ---------------------------------------------------------------------------
const RESTART_MODES = new Set(["soft", "hard", "update"]);
const RESTART_SECS = new Set([0, 60, 300]);

// needOwner=true => Owner only (PBO update). Otherwise Senior Admin (>=4) or Owner.
async function requireServerAdmin(needOwner: boolean): Promise<Actor> {
  const s = await getSession();
  if (!s) throw new Error("Not authenticated");
  const p = await getActorPowers(s.uid);
  const ok = needOwner ? p.isOwner : (p.isOwner || p.adminlevel >= SERVER_CTRL_LEVEL);
  if (!ok) throw new Error("Forbidden");
  return { uid: s.uid, name: s.name };
}

export async function setServerLock(fd: FormData) {
  const on = String(fd.get("lock")) === "1";
  const s = await requireServerAdmin(false);
  await q("UPDATE server_control SET svrlock=?, lock_by=?, lock_at=NOW() WHERE id=1", [on ? 1 : 0, s.name]);
  await adminLog(s, null, null, on ? "server_lock" : "server_unlock",
    `${on ? "Locked" : "Unlocked"} the server — new joins ${on ? "blocked" : "allowed"}.`);
  revalidatePath("/server");
}

export async function queueServerRestart(fd: FormData) {
  const mode = String(fd.get("mode"));
  const secs = Number(fd.get("secs")) || 0;
  if (!RESTART_MODES.has(mode)) throw new Error("Bad mode");
  if (!RESTART_SECS.has(secs)) throw new Error("Bad countdown");
  // update-PBO (repack + deploy) is OWNER only; soft/hard reboot is Senior Admin+.
  const s = await requireServerAdmin(mode === "update");
  if (String(fd.get("confirm")).trim().toUpperCase() !== "RESTART") throw new Error("Not confirmed");
  await q(
    `UPDATE server_control
        SET web_cmd=?, web_cmd_secs=?, web_cmd_by=?, web_cmd_at=NOW(),
            web_cmd_eta=now() + make_interval(secs => ?), web_cmd_status='queued'
      WHERE id=1 AND (web_cmd IS NULL OR web_cmd_status IN ('done','cancelled',''))`,
    [mode, secs, s.name, secs]
  );
  const label = mode === "update" ? "Update PBO + restart" : mode === "soft" ? "Soft restart" : "Hard restart";
  await adminLog(s, null, null, `server_${mode}`, `${label} queued (${secs}s warning).`);
  revalidatePath("/server");
}

export async function cancelServerRestart() {
  const s = await requireServerAdmin(false);
  // Include 'saving' — the agent's pre-restart graceful-save window checks for a cancel
  // before it sets restart_now, so a cancel there still aborts the reboot.
  await q(
    "UPDATE server_control SET web_cmd=NULL, web_cmd_status='cancelled' WHERE id=1 AND web_cmd_status IN ('queued','warning','saving')");
  await adminLog(s, null, null, "server_cancel", "Cancelled a queued restart.");
  revalidatePath("/server");
}

// Admin+ (economy): place any in-game item into a user's house VIRTUAL or PHYSICAL
// storage. Writes the mres-encoded houses.vinv/pinv directly; the game re-reads the row
// on the next storage-open (no restart). Overfill past vcap/phys_cap is safe (the game
// has no server-side cap check on save). Recomputes the weight total the game's way.
export async function placeHouseItems(fd: FormData) {
  const { s } = await requireEconomy();
  const oid = str(fd, "oid", 32);
  const type = String(fd.get("invtype")) === "physical" ? "physical" : "virtual";
  const col = type === "physical" ? "pinv" : "vinv";

  let additions: InvPair[] = [];
  try {
    const parsed = JSON.parse(String(fd.get("items") || "[]"));
    additions = (Array.isArray(parsed) ? parsed : [])
      .map((x: { classname?: unknown; qty?: unknown }) =>
        [sanitizeClass(String(x?.classname ?? "")), Math.floor(Number(x?.qty) || 0)] as InvPair)
      .filter(([c, q]) => c.length > 0 && q > 0)
      .slice(0, 100);
  } catch { return; }
  if (!oid || additions.length === 0) return;

  const summary = additions.map(([c, q]) => `${q}x ${c}`).join(", ");
  // Optimistic concurrency: read the column, merge, then UPDATE only if it's still unchanged
  // (NULL-safe compare). Another admin write — or a game storage-save — landing in between
  // fails the compare, so we re-read and retry instead of blind-overwriting their change.
  for (let attempt = 0; attempt < 4; attempt++) {
    const house = await one<{ owners: string; vinv: string | null; pinv: string | null }>(
      "SELECT owners, vinv, pinv FROM houses WHERE oid=? LIMIT 1", [oid]);
    if (!house) return;
    const rawBefore = type === "physical" ? house.pinv : house.vinv;
    const current = decodeHouseInv(rawBefore);
    if (current === null) return; // unparseable existing storage — refuse to overwrite it
    const merged = mergeItems(current[0], additions);
    const encoded = encodeHouseInv([merged, invTotal(merged, type)]);
    const res = await q<never>(
      `UPDATE houses SET ${col}=? WHERE oid=? AND ${col} <=> ?`, [encoded, oid, rawBefore]);
    if (((res as unknown as { affectedRows?: number }).affectedRows ?? 0) > 0) {
      await adminLog(s, house.owners, null, "house_place",
        `Placed in house ${oid} ${type} storage: ${summary}`);
      revalidatePath("/player-detail");
      return;
    }
    // column changed under us — loop to re-read and retry
  }
}

const MONEY_CAP = 100_000_000_000;
function clampMoney(v: unknown, decimals = 0): number {
  const f = 10 ** decimals;
  return Math.max(0, Math.min(Math.round((Number(v) || 0) * f) / f, MONEY_CAP));
}

const MONEY_COL: Record<string, string> = { cash: "cash", bank: "bankacc", nd: "new_drachma" };

export async function setPlayerMoney(fd: FormData) {
  const { s } = await requireEconomy();
  const target = str(fd, "target", 17);
  const col = MONEY_COL[String(fd.get("field"))];
  if (!col || !/^\d{17}$/.test(target)) return;
  const amount = clampMoney(fd.get("amount"), col === "new_drachma" ? 4 : 0);
  const tp = await one<{ name: string }>("SELECT name FROM players WHERE playerid=? LIMIT 1", [target]);
  if (!tp) throw new Error("Player not found");
  await q(`UPDATE players SET ${col}=? WHERE playerid=?`, [amount, target]); // col from fixed whitelist
  await adminLog(s, target, tp.name, `money.${String(fd.get("field"))}`, `set to ${amount}`);
  revalidatePath("/player-detail");
}

export async function addPlayerVehicle(fd: FormData) {
  const { s } = await requireEconomy();
  const target = str(fd, "target", 17);
  const side = ["civ", "cop", "med"].includes(String(fd.get("side"))) ? String(fd.get("side")) : "civ";
  const vtype = ["Car", "Air", "Ship", "Sea"].includes(String(fd.get("vtype"))) ? String(fd.get("vtype")) : "Car";
  const classname = str(fd, "classname", 64);
  if (!/^\d{17}$/.test(target) || !/^[A-Za-z0-9_]+$/.test(classname)) return;
  const plate = Math.floor(Math.random() * 900000 + 100000);
  await q(
    "INSERT INTO vehicles (side, classname, type, pid, alive, active, listed, inventory, color, plate, fuel, damage, ammo, mods) VALUES (?,?,?,?,1,0,0,'[]',0,?,100,0,0,'[]')",
    [side, classname, vtype, target, plate]
  );
  await adminLog(s, target, null, "vehicle.add", `${side} ${classname} plate ${plate}`);
  revalidatePath("/player-detail");
}

export async function removePlayerVehicle(fd: FormData) {
  const { s } = await requireEconomy();
  const id = Number(fd.get("vehicle_id"));
  const target = str(fd, "target", 17);
  if (!id || !/^\d{17}$/.test(target)) return;
  const v = await one<{ classname: string }>("SELECT classname FROM vehicles WHERE id=? AND pid=? LIMIT 1", [id, target]);
  if (!v) return; // only delete a vehicle actually owned by this player
  await q("DELETE FROM vehicles WHERE id=? AND pid=?", [id, target]);
  await adminLog(s, target, null, "vehicle.remove", `#${id} ${v.classname}`);
  revalidatePath("/player-detail");
}

const GANG_COL: Record<string, string> = { bank: "bank", xp: "experience" };

export async function setGangFunds(fd: FormData) {
  const { s } = await requireEconomy();
  const gangId = Number(fd.get("gang_id"));
  const col = GANG_COL[String(fd.get("field"))];
  if (!gangId || !col) return;
  const amount = clampMoney(fd.get("amount"));
  const g = await one<{ name: string }>("SELECT name FROM gangs WHERE id=? LIMIT 1", [gangId]);
  if (!g) return;
  await q(`UPDATE gangs SET ${col}=? WHERE id=?`, [amount, gangId]); // col from fixed whitelist
  await adminLog(s, null, g.name, `gang.${String(fd.get("field"))}`, `set to ${amount}`);
  revalidatePath("/gameserver/gang-detail");
}

// ---------------------------------------------------------------- faction blacklist
// manageable by that faction's command (whitelist power) or admins.
export async function addBlacklist(fd: FormData) {
  const s = await getSession();
  if (!s) throw new Error("Not authenticated");
  const f = getFaction(str(fd, "faction", 24));
  if (!f) throw new Error("Unknown faction");
  const powers = await getActorPowers(s.uid);
  if (maxGrant(f, powers) < 0) throw new Error("Forbidden");
  const target = str(fd, "target", 17);
  if (!/^\d{17}$/.test(target)) return;
  const reason = cleanReason(String(fd.get("reason") ?? ""));
  const tp = await one<{ name: string }>("SELECT name FROM players WHERE playerid=? LIMIT 1", [target]);
  const existing = await one<{ id: number }>(
    "SELECT id FROM web_faction_blacklist WHERE faction=? AND playerid=? AND removed_at IS NULL LIMIT 1", [f.key, target]
  );
  if (!existing) {
    await q(
      "INSERT INTO web_faction_blacklist (faction, playerid, name, reason, added_by, added_by_name) VALUES (?,?,?,?,?,?)",
      [f.key, target, tp?.name ?? target, reason, s.uid, s.name]
    );
  }
  revalidatePath("/maxsec");
  revalidatePath("/trauma-team");
}

export async function removeBlacklist(fd: FormData) {
  const s = await getSession();
  if (!s) throw new Error("Not authenticated");
  const id = Number(fd.get("id"));
  if (!id) return;
  const row = await one<{ faction: string }>("SELECT faction FROM web_faction_blacklist WHERE id=? LIMIT 1", [id]);
  if (!row) return;
  const f = getFaction(row.faction);
  const powers = await getActorPowers(s.uid);
  if (!f || maxGrant(f, powers) < 0) throw new Error("Forbidden");
  await q("UPDATE web_faction_blacklist SET removed_at=NOW() WHERE id=?", [id]);
  revalidatePath("/maxsec");
  revalidatePath("/trauma-team");
}

// ---------------------------------------------------------------- player report
async function saveTicketImage(file: File): Promise<string | null> {
  if (!/^image\/(png|jpe?g)$/.test(file.type)) return null;
  if (file.size > 5 * 1024 * 1024) return null;
  const ext = file.type === "image/png" ? "png" : "jpg";
  const name = `${randomUUID()}.${ext}`;
  const dir = path.join(process.cwd(), "uploads", "tickets");
  await mkdir(dir, { recursive: true });
  await writeFile(path.join(dir, name), Buffer.from(await file.arrayBuffer()));
  return `/api/images/tickets/${name}`;
}

function youtubeOk(u: string): boolean {
  return /^https?:\/\/(www\.)?(youtube\.com|youtu\.be)\//i.test(u);
}

// Guided player-report ticket: evidence-gated structured form -> a player-report ticket.
export async function createPlayerReport(fd: FormData) {
  const s = await getSession();
  if (!s) throw new Error("Not authenticated");
  if (!fd.get("confirm")) throw new Error("Evidence requirements not confirmed");

  const yourName = str(fd, "your_name", 64);
  const reported = str(fd, "reported_name", 64);
  const when = str(fd, "when", 32);
  const description = str(fd, "description", 4000);
  const videoRaw = str(fd, "video_url", 300);
  if (!reported || !description) return;
  const video = videoRaw && youtubeOk(videoRaw) ? videoRaw : "";

  // up to 5 image attachments (jpg/png, 5MB)
  const files = fd.getAll("images").filter((x): x is File => x instanceof File && x.size > 0).slice(0, 5);
  const urls: string[] = [];
  for (const f of files) {
    const u = await saveTicketImage(f);
    if (u) urls.push(u);
  }

  const body = [
    `Reported Player: ${reported}`,
    `Reporter In-Game Name: ${yourName || "—"}`,
    `Date/Time of Incident: ${when || "—"}`,
    `Video Evidence: ${video || "—"}`,
    "",
    description,
    ...(urls.length ? ["", "[attachments]", ...urls] : []),
  ].join("\n");

  const res = await q<never>(
    "INSERT INTO web_tickets (playerid, player_name, subject, category) VALUES (?,?,?,?)",
    [s.uid, s.name, `Player Report: ${reported}`.slice(0, 160), "player-report"]
  );
  const id = (res as unknown as { insertId: number }).insertId;
  await q(
    "INSERT INTO web_ticket_messages (ticket_id, author_id, author_name, is_staff, body) VALUES (?,?,?,?,?)",
    [id, s.uid, s.name, isStaff(s) ? 1 : 0, body]
  );
  revalidatePath("/support-tickets");
  redirect(`/support-tickets/${id}`);
}

// Compensation request: description + itemized loss (prices re-derived server-side
// from the in-server catalog — never trust client prices).
export async function createCompRequest(fd: FormData) {
  const s = await getSession();
  if (!s) throw new Error("Not authenticated");
  const description = str(fd, "description", 4000);
  if (!description) return;

  let picks: { c: string; q: number }[] = [];
  try { picks = JSON.parse(String(fd.get("items") ?? "[]")); } catch { picks = []; }
  const byCls = new Map(COMP_ITEMS.map((i) => [i.classname, i]));
  const itemLines: string[] = [];
  let total = 0;
  for (const p of Array.isArray(picks) ? picks.slice(0, 100) : []) {
    const meta = byCls.get(String(p?.c));
    const qty = Math.max(0, Math.min(Math.floor(Number(p?.q) || 0), 9999));
    if (!meta || qty <= 0) continue;
    const line = meta.price * qty;
    total += line;
    itemLines.push(`${qty}x ${meta.name} (${meta.classname}) — ${money(line)}`);
  }

  const files = fd.getAll("images").filter((x): x is File => x instanceof File && x.size > 0).slice(0, 5);
  const urls: string[] = [];
  for (const f of files) { const u = await saveTicketImage(f); if (u) urls.push(u); }

  const lines = ["Description:", description];
  if (itemLines.length) lines.push("", "Items Requested:", ...itemLines, `Total: ${money(total)}`);
  if (urls.length) lines.push("", "[attachments]", ...urls);

  const res = await q<never>(
    "INSERT INTO web_tickets (playerid, player_name, subject, category) VALUES (?,?,?,?)",
    [s.uid, s.name, "Compensation Request", "comp"]
  );
  const id = (res as unknown as { insertId: number }).insertId;
  await q(
    "INSERT INTO web_ticket_messages (ticket_id, author_id, author_name, is_staff, body) VALUES (?,?,?,?,?)",
    [id, s.uid, s.name, isStaff(s) ? 1 : 0, lines.join("\n")]
  );
  revalidatePath("/support-tickets");
  redirect(`/support-tickets/${id}`);
}

// Config-driven guided ticket: composes the body from a category's form spec.
export async function createGuidedTicket(fd: FormData) {
  const s = await getSession();
  if (!s) throw new Error("Not authenticated");
  const category = str(fd, "category", 32);
  if (!isValidCategory(category)) return;
  // hidden categories (police-app / ng-app) have a dedicated flow/table — never a web ticket.
  if (ticketCat(category).hidden) redirect(category === "ng-app" ? "/trauma-team/apply" : "/maxsec/apply");
  const spec = ticketCat(category).form;
  if (spec.gate && !fd.get("confirm")) throw new Error("Requirements not confirmed");

  const lines: string[] = [];
  const values: Record<string, string> = {};
  let hasContent = false;
  for (const f of spec.fields) {
    let v = str(fd, f.name, f.type === "textarea" ? 4000 : 300);
    if (f.type === "youtube") v = v && youtubeOk(v) ? v : "";
    values[f.name] = v;
    if (!v) continue;
    hasContent = true;
    lines.push(f.type === "textarea" ? `${f.label}:\n${v}` : `${f.label}: ${v}`);
  }
  if (!hasContent) return;

  const files = fd.getAll("images").filter((x): x is File => x instanceof File && x.size > 0).slice(0, 5);
  const urls: string[] = [];
  for (const f of files) { const u = await saveTicketImage(f); if (u) urls.push(u); }
  if (urls.length) lines.push("", "[attachments]", ...urls);

  const subject = spec.subjectPrefix
    ? (spec.subjectFrom && values[spec.subjectFrom] ? `${spec.subjectPrefix}: ${values[spec.subjectFrom]}` : spec.subjectPrefix)
    : ticketCat(category).label;

  const res = await q<never>(
    "INSERT INTO web_tickets (playerid, player_name, subject, category) VALUES (?,?,?,?)",
    [s.uid, s.name, subject.slice(0, 160), category]
  );
  const id = (res as unknown as { insertId: number }).insertId;
  await q(
    "INSERT INTO web_ticket_messages (ticket_id, author_id, author_name, is_staff, body) VALUES (?,?,?,?,?)",
    [id, s.uid, s.name, isStaff(s) ? 1 : 0, lines.join("\n")]
  );
  revalidatePath("/support-tickets");
  redirect(`/support-tickets/${id}`);
}

// Website MaxSec / Trauma Team application. Both route into the maxsec_applications table
// (faction column: 'apd' = police / Officer Maggot bot, 'ng' = Trauma Team) — so web
// applications appear in the faction's Applications tab, NOT in Support Tickets.
// The stored discriminators stay 'apd' and 'ng' through the MaxSec and Trauma Team rebrands ON
// PURPOSE: they are VALUES in existing rows, not identifiers. Renaming either would hide every
// historical application until a data migration ran. Keep writing them unless that migration is
// written too.
async function createFactionApplication(fd: FormData, faction: "apd" | "ng") {
  const s = await getSession();
  if (!s) throw new Error("Not authenticated");
  if (!fd.get("confirm")) throw new Error("Requirements not confirmed");

  const discordName = str(fd, "discord_name", 128);
  const readRules = str(fd, "read_rules", 8);
  const bannedBefore = str(fd, "banned_before", 8);
  const experience = str(fd, "cop_experience", 4000);
  const why = str(fd, "why", 4000);
  if (!experience || !why) return;

  const base = faction === "ng" ? "/trauma-team" : "/maxsec";

  // one pending web application per player, per faction
  const dup = await one<{ id: number }>(
    "SELECT id FROM maxsec_applications WHERE pid=? AND status='pending' AND faction=? LIMIT 1", [s.uid, faction]);
  if (dup) redirect(`${base}?tab=applications&dup=1`);

  // discord_id is NOT NULL on the table; use a linked account if present, else 0.
  const link = await one<{ discord_id: number | string }>(
    "SELECT discord_id FROM discord_links WHERE playerid=? LIMIT 1", [s.uid]);
  const discordId = link?.discord_id ?? 0;

  const disciplinary =
    `Banned before: ${bannedBefore || "—"}. Read & understands server rules: ${readRules || "—"}. (Submitted via website.)`;

  await q(
    `INSERT INTO maxsec_applications
       (discord_id, discord_name, ig_name, pid, dob, time_on_server, cop_experience, why, disciplinary, faction)
     VALUES (?,?,?,?,?,?,?,?,?,?)`,
    [discordId, discordName || "—", s.name, s.uid, "", "Submitted via website", experience, why, disciplinary, faction]
  );
  revalidatePath(base);
  redirect(`${base}?tab=applications&submitted=1`);
}
export async function createMaxSecApplication(fd: FormData) { return createFactionApplication(fd, "apd"); }
export async function createTTApplication(fd: FormData) { return createFactionApplication(fd, "ng"); }

// Guided MaxSec / Trauma Team member report (evidence-lite gate + structured fields).
export async function createFactionReport(fd: FormData) {
  const s = await getSession();
  if (!s) throw new Error("Not authenticated");
  if (!fd.get("confirm")) throw new Error("Requirements not confirmed");
  const isTT = String(fd.get("faction")) === "ng";
  const category = isTT ? "ng-report" : "apd-report";
  const label = isTT ? "TT" : "MaxSec";

  const reported = str(fd, "reported_name", 64);
  const description = str(fd, "description", 4000);
  const videoRaw = str(fd, "video_url", 300);
  if (!reported || !description) return;
  const video = videoRaw && youtubeOk(videoRaw) ? videoRaw : "";

  const files = fd.getAll("images").filter((x): x is File => x instanceof File && x.size > 0).slice(0, 5);
  const urls: string[] = [];
  for (const f of files) { const u = await saveTicketImage(f); if (u) urls.push(u); }

  const body = [
    `Reported ${label} Member: ${reported}`,
    `Video Evidence: ${video || "—"}`,
    "",
    description,
    ...(urls.length ? ["", "[attachments]", ...urls] : []),
  ].join("\n");

  const res = await q<never>(
    "INSERT INTO web_tickets (playerid, player_name, subject, category) VALUES (?,?,?,?)",
    [s.uid, s.name, `${label} Report: ${reported}`.slice(0, 160), category]
  );
  const id = (res as unknown as { insertId: number }).insertId;
  await q(
    "INSERT INTO web_ticket_messages (ticket_id, author_id, author_name, is_staff, body) VALUES (?,?,?,?,?)",
    [id, s.uid, s.name, isStaff(s) ? 1 : 0, body]
  );
  revalidatePath("/support-tickets");
  redirect(`/support-tickets/${id}`);
}

export async function setFeatureStatus(fd: FormData) {
  const s = await getSession();
  if (!isEditor(s)) throw new Error("Forbidden");
  const id = Number(fd.get("feature_id"));
  const status = str(fd, "status", 16);
  if (!["open", "planned", "done", "declined"].includes(status)) return;
  await q("UPDATE web_feature_requests SET status=? WHERE id=?", [status, id]);
  revalidatePath("/voting");
}

// ---------------------------------------------------------------- changelogs
export async function postChangelog(fd: FormData) {
  const s = await getSession();
  if (!isEditor(s)) throw new Error("Forbidden");
  const version = str(fd, "version", 32);
  const title = str(fd, "title", 160);
  const body = str(fd, "body", 20000);
  if (!title) return;
  await q("INSERT INTO web_changelogs (version, title, body, author_name) VALUES (?,?,?,?)",
    [version, title, body, s!.name]);
  revalidatePath("/changelogs");
}

// ---------------------------------------------------------------- faction whitelist
export async function setFactionRank(fd: FormData) {
  const s = await getSession();
  if (!s) throw new Error("Not authenticated");

  const f = getFaction(str(fd, "faction", 24));
  if (!f) throw new Error("Unknown faction");
  const targetUid = str(fd, "target", 17);
  const newRank = Number(fd.get("new_rank"));
  if (!/^\d{17}$/.test(targetUid) || !Number.isInteger(newRank)) return;

  // AUTHORITATIVE: re-read the actor's powers from the live DB (never trust cookie).
  const powers = await getActorPowers(s.uid);
  const targetRank = await getTargetRank(f, targetUid);

  if (!canManage(f, powers, targetRank, newRank)) throw new Error("Forbidden");
  if (newRank === targetRank) return; // no-op

  // can't whitelist a player who's on this faction's blacklist — remove it first.
  if (newRank > 0) {
    const bl = await one<{ id: number }>(
      "SELECT id FROM web_faction_blacklist WHERE faction=? AND playerid=? AND removed_at IS NULL LIMIT 1",
      [f.key, targetUid]
    );
    if (bl) throw new Error("Player is blacklisted from this faction — remove the blacklist first.");
  }

  // f.column is from a fixed registry (coplevel|mediclevel) — not user input.
  await q(
    `INSERT INTO players_global (playerid, ${f.column}) VALUES (?, ?)
       ON CONFLICT (playerid) DO UPDATE SET ${f.column} = EXCLUDED.${f.column}`,
    [targetUid, newRank]
  );

  const target = await one<{ name: string }>("SELECT name FROM players WHERE playerid=? LIMIT 1", [targetUid]);
  const role = powers.isOwner
    ? "Owner"
    : powers.adminlevel >= ADMIN_WL_LEVEL
    ? `Admin L${powers.adminlevel}`
    : rankName(f, powers.ranks[f.key] ?? 0);

  await q(
    `INSERT INTO web_whitelist_log
       (faction, actor_id, actor_name, actor_role, target_id, target_name, old_rank, new_rank, action)
       VALUES (?,?,?,?,?,?,?,?,?)`,
    [f.key, s.uid, s.name, role, targetUid, target?.name ?? "", targetRank, newRank, actionFor(targetRank, newRank)]
  );

  revalidatePath("/whitelist");
  revalidatePath("/maxsec");
  revalidatePath("/trauma-team");
  revalidatePath("/player-detail");
}

export async function setFactionSub(fd: FormData) {
  const s = await getSession();
  if (!s) throw new Error("Not authenticated");

  const f = getFaction(str(fd, "faction", 24));
  if (!f) throw new Error("Unknown faction");
  const sub = f.subs.find((x) => x.key === str(fd, "sub", 24));
  if (!sub) throw new Error("Unknown sub-whitelist");
  const targetUid = str(fd, "target", 17);
  const value = Number(fd.get("value")) ? 1 : 0;
  if (!/^\d{17}$/.test(targetUid)) return;

  const powers = await getActorPowers(s.uid); // AUTHORITATIVE
  const targetRank = await getTargetRank(f, targetUid);
  if (!canManageSub(f, powers, targetRank)) throw new Error("Forbidden");

  const old = await getSubValue(sub.column, targetUid);
  if (old === value) return; // no-op

  // sub.column is from the fixed registry (ismaxtac|isscd) — not user input.
  await q(`UPDATE players SET ${sub.column} = ? WHERE playerid = ?`, [value, targetUid]);

  const target = await one<{ name: string }>("SELECT name FROM players WHERE playerid=? LIMIT 1", [targetUid]);
  const role = powers.isOwner ? "Owner"
    : powers.adminlevel >= ADMIN_WL_LEVEL ? `Admin L${powers.adminlevel}`
    : rankName(f, powers.ranks[f.key] ?? 0);

  await q(
    `INSERT INTO web_whitelist_log
       (faction, actor_id, actor_name, actor_role, target_id, target_name, old_rank, new_rank, action)
       VALUES (?,?,?,?,?,?,?,?,?)`,
    [f.key, s.uid, s.name, role, targetUid, target?.name ?? "", old, value, `${sub.key} ${value ? "on" : "off"}`]
  );
  revalidatePath("/whitelist");
}

// ---------------------------------------------------------------- bans
export async function banPlayer(fd: FormData) {
  const s = await getSession();
  if (!s) throw new Error("Not authenticated");

  const powers = await getActorPowers(s.uid); // AUTHORITATIVE
  const isStaff = powers.isOwner || powers.adminlevel >= 1;
  const isAdmin = powers.isOwner || powers.adminlevel >= ADMIN_WL_LEVEL; // 4+
  if (!isStaff) throw new Error("Forbidden");

  const targetUid = str(fd, "playerid", 17);
  if (!/^\d{17}$/.test(targetUid)) return;
  const reason = cleanReason(str(fd, "reason", 240)) || "No reason";
  const durKey = str(fd, "duration", 8);
  if (!(durKey in BAN_DURATIONS)) return;
  const secs = BAN_DURATIONS[durKey];

  // permission: mods (adminlevel 1-3) capped at 3 days, no perma
  if (secs === null && !isAdmin) throw new Error("Mods cannot permaban");
  if (secs !== null && secs > MOD_MAX_SECONDS && !isAdmin) throw new Error("Mods limited to 3 days");

  const by = `${s.name}`.slice(0, 40);
  if (secs === null) {
    await q("INSERT INTO bans (playerid, reason, banned_by, until) VALUES (?,?,?,NULL)", [targetUid, reason, by]);
  } else {
    await q(
      "INSERT INTO bans (playerid, reason, banned_by, until) VALUES (?,?,?, now() + make_interval(secs => ?))",
      [targetUid, reason, by, secs]
    );
  }
  // immediate kick (same bridge the bot uses) — ban-on-connect + CLANKR BM mirror handle the rest
  await q("INSERT INTO bot_commands (command, target, arg1, arg2, issued_by) VALUES ('kick', ?, NULL, ?, ?)",
    [targetUid, `Banned: ${reason}`, by]);

  revalidatePath("/bans");
  revalidatePath("/player-detail");
}

export async function unbanPlayer(fd: FormData) {
  const s = await getSession();
  if (!s) throw new Error("Not authenticated");
  const powers = await getActorPowers(s.uid);
  const isAdmin = powers.isOwner || powers.adminlevel >= ADMIN_WL_LEVEL;
  if (!isAdmin) throw new Error("Forbidden"); // unban = admin 4+ only

  const targetUid = str(fd, "playerid", 17);
  if (!/^\d{17}$/.test(targetUid)) return;
  // expire (keep row for history); local enforcement stops on next connect.
  await q("UPDATE bans SET until = NOW() WHERE playerid=? AND (until IS NULL OR until > NOW())", [targetUid]);
  revalidatePath("/bans");
  revalidatePath("/player-detail");
}

// ---------------------------------------------------------------- VPN exemptions (BattleMetrics flag)
export async function addVpnExempt(fd: FormData) {
  const actor = await requireAdmin();
  if (!bmEnabled()) throw new Error("BattleMetrics token not set");

  const steam = str(fd, "playerid", 17);
  if (!/^\d{17}$/.test(steam)) throw new Error("Enter a valid 17-digit Steam ID");
  const note = str(fd, "note", 255);

  const flagId = await resolveFlagId();
  if (!flagId) throw new Error("VPN flag not found in BattleMetrics — create it or set BM_VPN_FLAG_ID");

  const player = await findPlayerBySteam(steam);
  if (!player) throw new Error("Player not found on BattleMetrics (they must have connected at least once)");

  const res = await addFlag(player.id, flagId);
  if (!res.ok) throw new Error(`BattleMetrics: ${res.error}`);

  const local = await one<{ name: string }>("SELECT name FROM players WHERE playerid=? LIMIT 1", [steam]);
  await q(
    `INSERT INTO web_vpn_exempt (playerid, name, note, added_by, bm_player_id) VALUES (?,?,?,?,?)
       ON CONFLICT (playerid) DO UPDATE SET note=EXCLUDED.note, added_by=EXCLUDED.added_by, bm_player_id=EXCLUDED.bm_player_id`,
    [steam, local?.name ?? player.name, note, actor.name, player.id]
  );
  revalidatePath("/vpn-whitelist");
}

export async function removeVpnExempt(fd: FormData) {
  await requireAdmin();
  const steam = str(fd, "playerid", 17);
  if (!/^\d{17}$/.test(steam)) return;

  const row = await one<{ bm_player_id: string }>("SELECT bm_player_id FROM web_vpn_exempt WHERE playerid=? LIMIT 1", [steam]);
  if (bmEnabled() && row?.bm_player_id) {
    const flagId = await resolveFlagId();
    if (flagId) await removeFlag(row.bm_player_id, flagId); // best-effort
  }
  await q("DELETE FROM web_vpn_exempt WHERE playerid=?", [steam]);
  revalidatePath("/vpn-whitelist");
}

// ---------------------------------------------------------------- wiki
export async function saveWiki(fd: FormData) {
  const s = await getSession();
  if (!isEditor(s)) throw new Error("Forbidden");
  const slug = str(fd, "slug", 96).toLowerCase().replace(/[^a-z0-9-]+/g, "-").replace(/^-+|-+$/g, "");
  const title = str(fd, "title", 160);
  const category = str(fd, "category", 48) || "General";
  const description = str(fd, "description", 300);
  const body = str(fd, "body", 50000);
  if (!slug || !title) return;
  await q(
    `INSERT INTO web_wiki_pages (slug, title, category, description, body, updated_by) VALUES (?,?,?,?,?,?)
       ON CONFLICT (slug) DO UPDATE SET title=EXCLUDED.title, category=EXCLUDED.category, description=EXCLUDED.description, body=EXCLUDED.body, updated_by=EXCLUDED.updated_by`,
    [slug, title, category, description, body, s!.name]
  );
  revalidatePath("/wiki");
  revalidatePath(`/wiki/${slug}`);
  redirect(`/wiki/${slug}`);
}

async function saveWikiImage(file: File): Promise<string | null> {
  if (!/^image\/(png|jpe?g|gif|webp)$/.test(file.type)) return null;
  if (file.size > 8 * 1024 * 1024) return null;
  const ext = file.type === "image/png" ? "png" : file.type === "image/gif" ? "gif"
    : file.type === "image/webp" ? "webp" : "jpg";
  const name = `${randomUUID()}.${ext}`;
  const dir = path.join(process.cwd(), "uploads", "wiki");
  await mkdir(dir, { recursive: true });
  await writeFile(path.join(dir, name), Buffer.from(await file.arrayBuffer()));
  return `/api/images/wiki/${name}`;
}

// Editor uploads an image and gets back its URL to drop into the page markdown.
export async function uploadWikiImage(fd: FormData): Promise<{ url?: string; error?: string }> {
  const s = await getSession();
  if (!isEditor(s)) return { error: "Forbidden" };
  const f = fd.get("image");
  if (!(f instanceof File) || f.size === 0) return { error: "No image" };
  const url = await saveWikiImage(f);
  return url ? { url } : { error: "Only PNG/JPG/GIF/WebP up to 8MB" };
}

export async function deleteWiki(fd: FormData) {
  const s = await getSession();
  if (!isEditor(s)) throw new Error("Forbidden");
  const slug = str(fd, "slug", 96).toLowerCase().replace(/[^a-z0-9-]+/g, "-").replace(/^-+|-+$/g, "");
  if (!slug) return;
  await q("DELETE FROM web_wiki_pages WHERE slug=?", [slug]);
  revalidatePath("/wiki");
  redirect("/wiki");
}
