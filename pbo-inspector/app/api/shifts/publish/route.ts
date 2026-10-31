import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";

import { publishShifts } from "@/lib/data/store";

const publishSchema = z.object({
  shiftIds: z.array(z.string()).min(1)
});

export async function POST(request: NextRequest) {
  const { shiftIds } = publishSchema.parse(await request.json());
  return NextResponse.json(publishShifts(shiftIds));
}
