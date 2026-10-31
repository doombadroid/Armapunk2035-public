import { NextResponse } from "next/server";
import { steamLoginUrl } from "@/lib/steam";

export const dynamic = "force-dynamic";

export function GET() {
  return NextResponse.redirect(steamLoginUrl());
}
