import { q, one } from "./db";

export interface BanStatus {
  banned: boolean;
  reason: string;
  by: string;
  until: Date | null; // null = permanent
  created: Date;
  clankr: boolean;
}

export async function getBanStatus(uid: string): Promise<BanStatus | null> {
  const b = await one<{ reason: string; banned_by: string; until: Date | null; created: Date }>(
    `SELECT reason, banned_by, until, created FROM bans
       WHERE playerid=? AND (until IS NULL OR until > NOW())
       ORDER BY id DESC LIMIT 1`,
    [uid]
  );
  if (!b) return null;
  return {
    banned: true,
    reason: b.reason,
    by: b.banned_by,
    until: b.until,
    created: b.created,
    clankr: /CLANKR/i.test(b.banned_by ?? ""),
  };
}

export interface ActiveBan {
  id: number; playerid: string; name: string | null;
  reason: string; banned_by: string; until: Date | null; created: Date; clankr: boolean;
}

export async function getActiveBans(limit = 200): Promise<ActiveBan[]> {
  const rows = await q<{
    id: number; playerid: string; name: string | null;
    reason: string; banned_by: string; until: Date | null; created: Date;
  }>(
    `SELECT b.id, b.playerid, p.name, b.reason, b.banned_by, b.until, b.created
       FROM bans b LEFT JOIN players p ON p.playerid = b.playerid
      WHERE b.until IS NULL OR b.until > NOW()
      ORDER BY b.created DESC LIMIT ?`,
    [limit]
  );
  return rows.map((r) => ({ ...r, clankr: /CLANKR/i.test(r.banned_by ?? "") }));
}

// duration key -> seconds; null = permanent. Mod cap = 3 days.
export const BAN_DURATIONS: Record<string, number | null> = {
  "1h": 3600, "3h": 10800, "12h": 43200, "1d": 86400, "3d": 259200,
  "7d": 604800, "14d": 1209600, "30d": 2592000, perma: null,
};
export const MOD_MAX_SECONDS = 259200; // 3 days
