import { q, one, num } from "./db";

// ---- tickets ----
export interface Ticket {
  id: number; playerid: string; player_name: string; subject: string;
  category: string; status: "open" | "answered" | "closed";
  created_at: Date; updated_at: Date; messages?: number;
}
export interface TicketMessage {
  id: number; ticket_id: number; author_id: string; author_name: string;
  is_staff: number; body: string; created_at: Date;
}

export async function listTickets(opts: {
  playerid?: string; all?: boolean; category?: string; status?: string; search?: string;
} = {}): Promise<Ticket[]> {
  // never dump every ticket without an explicit scope (own tickets, staff-all, or category queue)
  if (!opts.playerid && !opts.all && !opts.category) return [];
  const where: string[] = [];
  const params: (string | number)[] = [];
  if (opts.playerid) { where.push("t.playerid=?"); params.push(opts.playerid); }
  if (opts.category) { where.push("t.category=?"); params.push(opts.category); }
  if (opts.status && opts.status !== "all") { where.push("t.status=?"); params.push(opts.status); }
  if (opts.search) {
    where.push("(t.subject LIKE ? OR t.playerid LIKE ? OR t.player_name LIKE ?)");
    const s = `%${opts.search}%`; params.push(s, s, s);
  }
  const whereSql = where.length ? `WHERE ${where.join(" AND ")}` : "";
  return q<Ticket>(
    `SELECT t.*, (SELECT COUNT(*) FROM web_ticket_messages m WHERE m.ticket_id=t.id) messages
       FROM web_tickets t ${whereSql} ORDER BY (t.status='closed'), t.updated_at DESC`,
    params
  );
}

export async function getTicket(id: number): Promise<{ ticket: Ticket; messages: TicketMessage[] } | null> {
  const ticket = await one<Ticket>("SELECT * FROM web_tickets WHERE id=? LIMIT 1", [id]);
  if (!ticket) return null;
  const messages = await q<TicketMessage>(
    "SELECT * FROM web_ticket_messages WHERE ticket_id=? ORDER BY created_at ASC", [id]
  );
  return { ticket, messages };
}

// ---- community voting ----
export type FeatureStatus = "open" | "planned" | "done" | "declined";
export interface Feature {
  id: number; playerid: string; author_name: string; title: string; body: string | null;
  image_url: string | null; status: FeatureStatus;
  closes_at: Date | string | null; created_at: Date | string;
  up: number; down: number; comments: number; myVote?: number; // myVote: 1 | -1 | 0
}
export interface FeatureComment {
  id: number; feature_id: number; author_id: string; author_name: string;
  body: string; created_at: Date | string;
}

const FEATURE_SELECT = `
  SELECT f.*,
         COUNT(*) FILTER (WHERE v.vote = 1)  AS up,
         COUNT(*) FILTER (WHERE v.vote = -1) AS down,
         (SELECT COUNT(*) FROM web_feature_comments c WHERE c.feature_id = f.id) AS comments
    FROM web_feature_requests f
    LEFT JOIN web_feature_votes v ON v.feature_id = f.id`;

function mapFeature(r: Record<string, unknown>): Feature {
  return {
    id: num(r.id), playerid: String(r.playerid), author_name: String(r.author_name ?? ""),
    title: String(r.title), body: (r.body as string) ?? null, image_url: (r.image_url as string) ?? null,
    status: r.status as FeatureStatus, closes_at: (r.closes_at as Date | string) ?? null,
    created_at: r.created_at as Date | string,
    up: num(r.up), down: num(r.down), comments: num(r.comments),
  };
}

async function attachVotes(rows: Feature[], voterId?: string): Promise<Feature[]> {
  if (!voterId || rows.length === 0) return rows;
  const mine = await q<{ feature_id: number; vote: number }>(
    "SELECT feature_id, vote FROM web_feature_votes WHERE playerid=?", [voterId]
  );
  const map = new Map(mine.map((m) => [num(m.feature_id), num(m.vote)]));
  return rows.map((f) => ({ ...f, myVote: map.get(f.id) ?? 0 }));
}

export async function listFeatures(voterId?: string): Promise<Feature[]> {
  const rows = await q<Record<string, unknown>>(
    `${FEATURE_SELECT} GROUP BY f.id
      ORDER BY (f.status <> 'open'), (COALESCE(SUM(v.vote),0)) DESC, f.created_at DESC`
  );
  return attachVotes(rows.map(mapFeature), voterId);
}

export async function getFeature(id: number, voterId?: string): Promise<Feature | null> {
  const row = await one<Record<string, unknown>>(`${FEATURE_SELECT} WHERE f.id=? GROUP BY f.id`, [id]);
  if (!row) return null;
  return (await attachVotes([mapFeature(row)], voterId))[0];
}

export async function listFeatureComments(featureId: number): Promise<FeatureComment[]> {
  return q<FeatureComment>(
    "SELECT * FROM web_feature_comments WHERE feature_id=? ORDER BY created_at ASC", [featureId]
  );
}

// ---- changelogs ----
export interface Changelog {
  id: number; version: string; title: string; body: string;
  author_name: string; published: boolean; created_at: Date;
}
export async function listChangelogs(): Promise<Changelog[]> {
  return q<Changelog>(
    "SELECT * FROM web_changelogs WHERE published ORDER BY created_at DESC"
  );
}

// ---- wiki ----
export interface WikiPage {
  id: number; slug: string; title: string; category: string;
  description: string; body: string; updated_by: string; updated_at: Date;
}
export async function listWiki(): Promise<WikiPage[]> {
  return q<WikiPage>("SELECT id, slug, title, category, COALESCE(description,'') AS description, updated_at, updated_by, '' AS body FROM web_wiki_pages ORDER BY category, title");
}
export async function getWikiPage(slug: string): Promise<WikiPage | null> {
  return one<WikiPage>("SELECT * FROM web_wiki_pages WHERE slug=? LIMIT 1", [slug]);
}
