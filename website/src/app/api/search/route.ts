import { NextRequest, NextResponse } from "next/server";
import { searchPlayers, listGangs } from "@/lib/queries";

export const dynamic = "force-dynamic";

export async function GET(req: NextRequest) {
  const term = (req.nextUrl.searchParams.get("q") ?? "").trim();
  if (term.length < 2) return NextResponse.json({ results: [] });

  const [players, gangs] = await Promise.all([
    searchPlayers(term, 8),
    listGangs(term),
  ]);

  const results = [
    ...players.map((p) => ({
      type: "player" as const,
      id: p.uid,
      name: p.name,
      sub: p.gangName ? `Gang · ${p.gangName}` : "Player",
    })),
    ...gangs.slice(0, 6).map((g) => ({
      type: "gang" as const,
      id: String(g.id),
      name: g.name.trim(),
      sub: `Gang · ${g.members} members`,
    })),
  ];

  return NextResponse.json({ results });
}
