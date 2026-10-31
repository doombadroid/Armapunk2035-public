/** $1,234,567 */
export function money(v: number | string | null | undefined): string {
  const n = typeof v === "string" ? Number(v) : v ?? 0;
  return "$" + Math.round(Number(n) || 0).toLocaleString("en-US");
}

/** 1,234,567 */
export function commas(v: number | string | null | undefined): string {
  const n = typeof v === "string" ? Number(v) : v ?? 0;
  return Math.round(Number(n) || 0).toLocaleString("en-US");
}

/** minutes -> "2212h 33m" (matches the in-game playtime unit) */
export function playtime(minutes: number | null | undefined): string {
  const m = Math.max(0, Math.round(Number(minutes) || 0));
  const h = Math.floor(m / 60);
  return `${h.toLocaleString("en-US")}h ${m % 60}m`;
}

/** "Jun 21, 2025" */
export function dateShort(d: Date | string | null | undefined): string {
  if (!d) return "—";
  const dt = typeof d === "string" ? new Date(d) : d;
  if (isNaN(dt.getTime())) return "—";
  return dt.toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" });
}

/** "Jun 21, 2025, 05:38 PM" */
export function dateLong(d: Date | string | null | undefined): string {
  if (!d) return "—";
  const dt = typeof d === "string" ? new Date(d) : d;
  if (isNaN(dt.getTime())) return "—";
  return dt.toLocaleString("en-US", {
    month: "short", day: "numeric", year: "numeric",
    hour: "2-digit", minute: "2-digit",
  });
}

/** "3 days ago" */
export function relative(d: Date | string | null | undefined): string {
  if (!d) return "—";
  const dt = typeof d === "string" ? new Date(d) : d;
  if (isNaN(dt.getTime())) return "—";
  const s = Math.floor((Date.now() - dt.getTime()) / 1000);
  if (s < 60) return "just now";
  const units: [number, string][] = [
    [31536000, "year"], [2592000, "month"], [604800, "week"],
    [86400, "day"], [3600, "hour"], [60, "minute"],
  ];
  for (const [secs, name] of units) {
    const v = Math.floor(s / secs);
    if (v >= 1) return `${v} ${name}${v > 1 ? "s" : ""} ago`;
  }
  return "just now";
}

/** 1234567 -> "1.2M", 8700 -> "8.7K", 206 -> "206" */
export function abbrev(v: number | string | null | undefined): string {
  const n = typeof v === "string" ? Number(v) : v ?? 0;
  const a = Math.abs(Number(n) || 0);
  if (a >= 1e9) return (Number(n) / 1e9).toFixed(1) + "B";
  if (a >= 1e6) return (Number(n) / 1e6).toFixed(1) + "M";
  if (a >= 1e3) return (Number(n) / 1e3).toFixed(1) + "K";
  return String(Math.round(Number(n) || 0));
}
export function moneyAbbrev(v: number | string | null | undefined): string {
  return "$" + abbrev(v);
}

/** New Drachma: exact 4dp wallet — trim trailing zeros, keep decimals ("12.5 ND", "4.1667 ND") */
export function nd(v: number | string | null | undefined): string {
  const n = typeof v === "string" ? Number(v) : v ?? 0;
  const s = (Number(n) || 0).toFixed(4).replace(/\.?0+$/, "");
  return Number(s).toLocaleString("en-US", { maximumFractionDigits: 4 }) + " ND";
}

/** "Land_i_Stone_HouseSmall_V1_F" -> "Stone House Small (V1)" */
export function houseTypeName(classname: string): string {
  let s = classname.replace(/^Land_[iI]?_?/, "").replace(/_F$/, "");
  const v = s.match(/_V(\d+)$/);
  if (v) s = s.replace(/_V\d+$/, "");
  s = s.replace(/([a-z])([A-Z])/g, "$1 $2").replace(/_/g, " ").trim();
  return v ? `${s} (V${v[1]})` : s || "House";
}

/** Arma map grid reference from world XY, e.g. "234 / 199". */
export function gridRef(x: number, y: number): string {
  return `${String(Math.floor(x / 100)).padStart(3, "0")} / ${String(Math.floor(y / 100)).padStart(3, "0")}`;
}

export function initials(name: string | null | undefined): string {
  const n = (name ?? "").trim();
  if (!n) return "??";
  const parts = n.split(/\s+/);
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}
