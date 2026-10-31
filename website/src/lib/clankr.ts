import { q } from "./db";

export interface ClankrAlert {
  id: number; ts: Date; severity: string; rule: string;
  playerid: string; name: string; detail: string | null; snippet: string | null; event_ts: string;
}

export async function getClankrAlerts(playerid?: string, limit = 80): Promise<ClankrAlert[]> {
  if (playerid) {
    return q<ClankrAlert>(
      "SELECT * FROM clankr_alerts WHERE playerid=? ORDER BY id DESC LIMIT ?", [playerid, limit]
    );
  }
  return q<ClankrAlert>("SELECT * FROM clankr_alerts ORDER BY id DESC LIMIT ?", [limit]);
}

export async function clankrStats(): Promise<{ high: number; med: number; low: number; total: number }> {
  const rows = await q<{ severity: string; n: number }>(
    "SELECT severity, COUNT(*) n FROM clankr_alerts WHERE ts > NOW() - INTERVAL '7 days' GROUP BY severity"
  );
  const m: Record<string, number> = {};
  for (const r of rows) m[r.severity] = Number(r.n);
  return {
    high: m.HIGH ?? 0, med: m.MED ?? 0, low: m.LOW ?? 0,
    total: (m.HIGH ?? 0) + (m.MED ?? 0) + (m.LOW ?? 0),
  };
}

export function severityColor(sev: string): string {
  return sev === "HIGH" ? "red" : sev === "MED" ? "orange" : "gray";
}
