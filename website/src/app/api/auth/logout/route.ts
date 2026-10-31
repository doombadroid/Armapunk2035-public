import { NextResponse } from "next/server";
import { destroySession } from "@/lib/session";
import { siteUrl } from "@/lib/steam";

export const dynamic = "force-dynamic";

export async function GET() {
  await destroySession();
  return NextResponse.redirect(`${siteUrl()}/`);
}
