import { NextResponse, type NextRequest } from "next/server";
import { getSession } from "@/lib/session";
import { pixelAllowed } from "@/lib/pixel/access";
import { parseChatCursor } from "@/lib/pixel/chat";
import { getState } from "@/lib/pixel/store";

export const dynamic = "force-dynamic";

/** GET /api/pixel/state?sinceChat=&chatRevision=&chatGeneration= -> the snapshot (reference shape). */
export async function GET(req: NextRequest) {
  const s = await getSession();
  if (!s) return NextResponse.json({ error: "Your session expired. Sign in again." }, { status: 401 });
  if (!pixelAllowed(s)) return NextResponse.json({ error: "Not found" }, { status: 404 });
  const q = req.nextUrl.searchParams;
  const cursor = parseChatCursor({ sinceChat: q.get("sinceChat"), chatRevision: q.get("chatRevision"), chatGeneration: q.get("chatGeneration") });
  return NextResponse.json(await getState({ uid: s.uid, name: s.name, avatar: s.avatar }, cursor));
}
