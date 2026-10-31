import { NextResponse, type NextRequest } from "next/server";
import { getSession } from "@/lib/session";
import { pixelAllowed } from "@/lib/pixel/access";
import { parseChatCursor } from "@/lib/pixel/chat";
import { TOO_FAST } from "@/lib/pixel/engine";
import { parseAction } from "@/lib/pixel/parse";
import { doAction } from "@/lib/pixel/store";

export const dynamic = "force-dynamic";

/**
 * POST /api/pixel/action { type, ...payload, sinceChat, chatRevision, chatGeneration } -> { snapshot, result }.
 * 200 even when result.ok is false (the client pops result.error); 4xx only for a bad body, auth
 * and the rate limit (429 with Retry-After, as the reference client expects).
 */
export async function POST(req: NextRequest) {
  const s = await getSession();
  if (!s) return NextResponse.json({ error: "Signed out" }, { status: 401 });
  if (!pixelAllowed(s)) return NextResponse.json({ error: "Not found" }, { status: 404 });
  let body: unknown = null;
  try { body = await req.json(); } catch { body = null; }
  const action = parseAction(body);
  if (!action) return NextResponse.json({ error: "Bad action" }, { status: 400 });
  const b = (body ?? {}) as Record<string, unknown>;
  const cursor = parseChatCursor({ sinceChat: b.sinceChat, chatRevision: b.chatRevision, chatGeneration: b.chatGeneration });
  const r = await doAction({ uid: s.uid, name: s.name, avatar: s.avatar }, action, cursor);
  if (!r.result.ok && r.result.error === TOO_FAST) {
    return NextResponse.json({ error: TOO_FAST }, { status: 429, headers: { "Retry-After": "1" } });
  }
  return NextResponse.json(r);
}
