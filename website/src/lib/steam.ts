// Steam OpenID 2.0 — minimal, no external lib.
const STEAM_OPENID = "https://steamcommunity.com/openid/login";

export function siteUrl(): string {
  return (process.env.SITE_URL ?? "http://localhost:3000").replace(/\/$/, "");
}

/** URL to send the user to begin Steam login. */
export function steamLoginUrl(): string {
  const base = siteUrl();
  const params = new URLSearchParams({
    "openid.ns": "http://specs.openid.net/auth/2.0",
    "openid.mode": "checkid_setup",
    "openid.return_to": `${base}/api/auth/callback`,
    "openid.realm": base,
    "openid.identity": "http://specs.openid.net/auth/2.0/identifier_select",
    "openid.claimed_id": "http://specs.openid.net/auth/2.0/identifier_select",
  });
  return `${STEAM_OPENID}?${params.toString()}`;
}

/** Verify the callback params with Steam; returns the steam64 id or null. */
export async function verifySteamCallback(query: URLSearchParams): Promise<string | null> {
  const claimed = query.get("openid.claimed_id");
  const m = claimed?.match(/^https?:\/\/steamcommunity\.com\/openid\/id\/(\d{17})$/);
  if (!m) return null;

  const body = new URLSearchParams();
  for (const [k, v] of query.entries()) body.set(k, v);
  body.set("openid.mode", "check_authentication");

  const res = await fetch(STEAM_OPENID, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: body.toString(),
  });
  const text = await res.text();
  if (!/is_valid\s*:\s*true/i.test(text)) return null;
  return m[1];
}

export interface SteamProfile { name: string | null; avatar: string | null }

/** Resolve display name + avatar for many steamids at once (Steam Web API, ≤100/call). */
export async function fetchSteamProfiles(ids: string[]): Promise<Map<string, SteamProfile>> {
  const out = new Map<string, SteamProfile>();
  const apiKey = process.env.STEAM_API_KEY;
  const uniq = Array.from(new Set(ids.filter((s) => /^\d{17}$/.test(s))));
  if (!apiKey || uniq.length === 0) return out;
  try {
    // Steam allows up to 100 ids per request
    for (let i = 0; i < uniq.length; i += 100) {
      const batch = uniq.slice(i, i + 100).join(",");
      const url = `https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v2/?key=${apiKey}&steamids=${batch}`;
      const res = await fetch(url, { next: { revalidate: 3600 } });
      const data = await res.json();
      for (const p of data?.response?.players ?? []) {
        out.set(String(p.steamid), { name: p.personaname ?? null, avatar: p.avatarfull ?? null });
      }
    }
  } catch {
    /* fall back to initials */
  }
  return out;
}

/** Resolve a single profile (name + avatar). */
export async function fetchSteamProfile(steamid: string): Promise<SteamProfile> {
  const m = await fetchSteamProfiles([steamid]);
  return m.get(steamid) ?? { name: null, avatar: null };
}
