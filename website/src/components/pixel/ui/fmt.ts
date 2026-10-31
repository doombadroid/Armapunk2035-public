// Reference portal date helpers (work/ui/FMT.jsx), verbatim.

const DEFAULT_DATETIME: Intl.DateTimeFormatOptions = {
  year: "numeric",
  month: "short",
  day: "numeric",
  hour: "2-digit",
  minute: "2-digit",
};

export const FMT_DATE: Intl.DateTimeFormatOptions = {
  year: "numeric",
  month: "short",
  day: "numeric",
};

export const FMT_DATETIME = DEFAULT_DATETIME;

export const FMT_TIME: Intl.DateTimeFormatOptions = {
  hour: "2-digit",
  minute: "2-digit",
};

export type DateInput = string | number | Date | null | undefined;

export function fmtDateTime(e: DateInput, r: Intl.DateTimeFormatOptions = DEFAULT_DATETIME): string {
  return e ? new Date(e).toLocaleString(undefined, r) : "-";
}

export function timeAgo(e: DateInput): string {
  if (!e) return "-";
  const t = Math.floor((Date.now() - new Date(e).getTime()) / 6e4);
  if (t < 1) return "just now";
  if (t < 60) return `${t}m ago`;
  const r = Math.floor(t / 60);
  if (r < 24) return `${r}h ago`;
  const n = Math.floor(r / 24);
  if (n < 30) return `${n}d ago`;
  const u = Math.floor(n / 30);
  return u < 12 ? `${u}mo ago` : `${Math.floor(u / 12)}y ago`;
}

export function timeUntil(e: DateInput): string | null {
  if (!e) return null;
  const t = new Date(e).getTime() - Date.now();
  if (t <= 0) return null;
  const r = Math.floor(t / 6e4);
  if (r < 1) return "less than a minute";
  if (r < 60) return `${r}m`;
  const n = Math.floor(r / 60);
  if (n < 24) return `${n}h ${r % 60}m`;
  const u = Math.floor(n / 24);
  if (u < 30) return `${u}d ${n % 24}h`;
  const o = Math.floor(u / 30);
  return o < 12 ? `${o}mo ${u % 30}d` : `${Math.floor(o / 12)}y ${o % 12}mo`;
}

export function toDatetimeLocalValue(e: DateInput): string {
  if (!e) return "";
  const t = new Date(e);
  return isNaN(t.getTime()) ? "" : new Date(t.getTime() - 6e4 * t.getTimezoneOffset()).toISOString().slice(0, 16);
}
