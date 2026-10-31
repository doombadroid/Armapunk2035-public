import { NextResponse } from "next/server";
import { getSession } from "@/lib/session";
import { getActorPowers, getAuditLog } from "@/lib/whitelist";
import { isAdminPlus, manageableFactions } from "@/lib/factions";

export const dynamic = "force-dynamic";

export async function GET() {
  const s = await getSession();
  if (!s) return NextResponse.json({ rows: [] }, { status: 401 });

  const powers = await getActorPowers(s.uid);
  const admin = isAdminPlus(powers);
  const scope = admin ? null : manageableFactions(powers).map((f) => f.key);
  if (!admin && (!scope || scope.length === 0)) {
    return NextResponse.json({ rows: [] }, { status: 403 });
  }
  const rows = await getAuditLog(scope, 50);
  return NextResponse.json({ rows });
}
