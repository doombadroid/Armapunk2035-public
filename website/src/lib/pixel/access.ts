import type { Session } from "@/lib/session";

// Armapunk Pixel is a closed test: the owner's Steam account only (owner 2026-09-10, "restrict it
// to my steam account only for now"). Widening it later is a change to this one function plus the
// nav flag in the root layout; every route and page asks here.
export function pixelAllowed(s: Session | null | undefined): s is Session {
  const owner = process.env.OWNER_STEAMID ?? "";
  return !!s && owner !== "" && s.uid === owner;
}
