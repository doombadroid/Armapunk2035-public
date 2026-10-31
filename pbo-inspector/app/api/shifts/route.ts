import { NextRequest, NextResponse } from "next/server";

import { getShifts, upsertShift } from "@/lib/data/store";
import { shiftSchema } from "@/lib/schemas";

export async function GET(request: NextRequest) {
  const searchParams = request.nextUrl.searchParams;
  return NextResponse.json(
    getShifts({
      start: searchParams.get("start") ?? undefined,
      end: searchParams.get("end") ?? undefined,
      departmentId: searchParams.get("departmentId") ?? undefined
    }),
  );
}

export async function POST(request: NextRequest) {
  const payload = shiftSchema.parse(await request.json());
  return NextResponse.json(upsertShift(payload), { status: 201 });
}
