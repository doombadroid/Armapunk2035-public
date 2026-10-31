// Minimal BattleMetrics REST client for managing the VPN-exemption player flag.
// BM does the VPN detection + enforcement via a Trigger; the exemption is a player
// flag the trigger is configured to skip. This adds/removes that flag.
const API = "https://api.battlemetrics.com";

export function bmEnabled(): boolean {
  return !!(process.env.BM_TOKEN && process.env.BM_TOKEN.trim());
}
function token(): string {
  return (process.env.BM_TOKEN ?? "").trim();
}
function orgId(): string {
  return (process.env.BM_ORG_ID ?? "131365").trim();
}
const FLAG_NAME = (process.env.BM_VPN_FLAG_NAME ?? "VPN Whitelist").trim();

type Json = Record<string, unknown>;

async function bm(method: string, path: string, body?: unknown): Promise<{ status: number; json: any }> {
  if (!bmEnabled()) return { status: 0, json: { _err: "BM_TOKEN not set" } };
  try {
    const res = await fetch(path.startsWith("http") ? path : API + path, {
      method,
      headers: {
        Authorization: `Bearer ${token()}`,
        Accept: "application/json",
        ...(body !== undefined ? { "Content-Type": "application/json" } : {}),
      },
      body: body !== undefined ? JSON.stringify(body) : undefined,
      cache: "no-store",
    });
    const text = await res.text();
    return { status: res.status, json: text.trim() ? JSON.parse(text) : {} };
  } catch (e) {
    return { status: 0, json: { _err: String(e) } };
  }
}

function bmError(json: any): string {
  const errs = json?.errors;
  if (Array.isArray(errs) && errs.length) {
    return errs.map((e: Json) => (e.detail || e.title || "?")).join("; ");
  }
  return json?._err || "BattleMetrics request failed";
}

export interface BmPlayer { id: string; name: string }

/** Find a BattleMetrics player by Steam64. */
export async function findPlayerBySteam(steam64: string): Promise<BmPlayer | null> {
  const { status, json } = await bm("GET", `/players?filter[search]=${encodeURIComponent(steam64)}&page[size]=10&include=identifier`);
  if (status !== 200) return null;
  const data: Json[] = json?.data ?? [];
  const included: Json[] = json?.included ?? [];
  // prefer the player whose included steamID identifier exactly matches
  const steamIdentifier = included.find(
    (i) => i.type === "identifier" && (i.attributes as Json)?.type === "steamID" && (i.attributes as Json)?.identifier === steam64
  );
  if (steamIdentifier) {
    const pid = (((steamIdentifier.relationships as Json)?.player as Json)?.data as Json)?.id;
    const p = data.find((d) => d.id === pid) ?? data[0];
    if (p) return { id: String(p.id), name: String((p.attributes as Json)?.name ?? "") };
  }
  if (data[0]) return { id: String(data[0].id), name: String((data[0].attributes as Json)?.name ?? "") };
  return null;
}

let _flagId: string | null | undefined;
/** Resolve the exemption flag UUID (env override, else by name in the org). null if absent. */
export async function resolveFlagId(): Promise<string | null> {
  if (process.env.BM_VPN_FLAG_ID) return process.env.BM_VPN_FLAG_ID.trim();
  if (_flagId !== undefined) return _flagId;
  const { status, json } = await bm("GET", `/player-flags?page[size]=100`);
  if (status !== 200) { _flagId = null; return null; }
  const data: Json[] = json?.data ?? [];
  const hit = data.find((f) => String((f.attributes as Json)?.name ?? "").toLowerCase() === FLAG_NAME.toLowerCase());
  _flagId = hit ? String(hit.id) : null;
  return _flagId;
}

/** Create the exemption flag in the org; returns its id. */
export async function createFlag(): Promise<{ ok: boolean; id?: string; error?: string }> {
  const body = {
    data: {
      type: "playerFlag",
      attributes: { name: FLAG_NAME, description: "Exempt from the VPN/proxy trigger (managed by the Armapunk site)", color: "#22c55e" },
      relationships: { organization: { data: { type: "organization", id: orgId() } } },
    },
  };
  const { status, json } = await bm("POST", "/player-flags", body);
  if (status === 200 || status === 201) {
    _flagId = String(json?.data?.id);
    return { ok: true, id: _flagId };
  }
  return { ok: false, error: bmError(json) };
}

export async function addFlag(playerId: string, flagId: string): Promise<{ ok: boolean; error?: string }> {
  const { status, json } = await bm("POST", `/players/${playerId}/relationships/flags`, {
    data: [{ type: "playerFlag", id: flagId }],
  });
  if (status === 200 || status === 201 || status === 204) return { ok: true };
  return { ok: false, error: bmError(json) };
}

export async function removeFlag(playerId: string, flagId: string): Promise<{ ok: boolean; error?: string }> {
  // BM marks the flagPlayer record removedAt; the id-in-path DELETE is the supported form.
  const { status, json } = await bm("DELETE", `/players/${playerId}/relationships/flags/${flagId}`);
  if (status === 200 || status === 204) return { ok: true };
  return { ok: false, error: bmError(json) };
}
