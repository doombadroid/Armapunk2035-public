import { NextRequest, NextResponse } from "next/server";
import { verifySteamCallback, fetchSteamProfile, siteUrl } from "@/lib/steam";
import { createSession } from "@/lib/session";
import { one, num } from "@/lib/db";

export const dynamic = "force-dynamic";

export async function GET(req: NextRequest) {
  const url = new URL(req.url);
  const uid = await verifySteamCallback(url.searchParams);
  if (!uid) {
    return NextResponse.redirect(`${siteUrl()}/?login=failed`);
  }

  // resolve display name + privileges from the game DB (fallback to Steam profile)
  const [player, global, profile] = await Promise.all([
    one<{ name: string }>(
      "SELECT name FROM players WHERE playerid=? LIMIT 1", [uid]
    ),
    one<{ adminlevel: number; coplevel: number; mediclevel: number }>(
      "SELECT adminlevel, coplevel, mediclevel FROM players_global WHERE playerid=? LIMIT 1", [uid]
    ),
    fetchSteamProfile(uid),
  ]);

  await createSession({
    uid,
    name: player?.name ?? profile.name ?? "Player",
    adminLevel: num(global?.adminlevel),
    copLevel: num(global?.coplevel),
    medicLevel: num(global?.mediclevel),
    isOwner: uid === (process.env.OWNER_STEAMID ?? ""),
    avatar: profile.avatar,
  });

  return NextResponse.redirect(`${siteUrl()}/player-detail?playerid=${uid}`);
}
