import { NextResponse, type NextRequest } from "next/server";
import { getSession } from "@/lib/session";
import { pixelAllowed } from "@/lib/pixel/access";
import { getGang } from "@/lib/pixel/store";

export const dynamic = "force-dynamic";

/** GET /api/pixel/gang?id= -> { gang } or { error: "That gang no longer exists." } (404). */
export async function GET(req: NextRequest) {
  const s = await getSession();
  if (!s) return NextResponse.json({ error: "Signed out" }, { status: 401 });
  if (!pixelAllowed(s)) return NextResponse.json({ error: "Not found" }, { status: 404 });
  const id = req.nextUrl.searchParams.get("id") ?? "";
  if (!/^[a-z0-9]{1,40}$/.test(id)) return NextResponse.json({ error: "That gang no longer exists." }, { status: 404 });
  const gang = await getGang({ uid: s.uid, name: s.name, avatar: s.avatar }, id);
  if (!gang) return NextResponse.json({ error: "That gang no longer exists." }, { status: 404 });
  return NextResponse.json({ gang });
}
