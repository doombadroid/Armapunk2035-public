// Reference formatters (deminified F / E / O / B), verbatim.

export const fmtMoney = (e: number): string => `$${Math.round(e).toLocaleString()}`;

export function fmtCompact(e: number): string {
  const t = Math.abs(e);
  return t >= 1e9
    ? `$${(e / 1e9).toFixed(2)}B`
    : t >= 1e6
      ? `$${(e / 1e6).toFixed(2)}M`
      : t >= 1e4
        ? `$${(e / 1e3).toFixed(1)}K`
        : `$${Math.round(e).toLocaleString()}`;
}

export const fmtSecs = (e: number): string => `${Math.max(0, Math.ceil(e / 1e3))}s`;

export function fmtAgo(e: number): string {
  const t = Math.max(0, Math.round(e / 1e3));
  return t < 60 ? `${t}s` : t < 3600 ? `${Math.floor(t / 60)}m` : `${Math.floor(t / 3600)}h`;
}
