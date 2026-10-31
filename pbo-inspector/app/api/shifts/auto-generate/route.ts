import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";

import { autoGenerateShifts } from "@/lib/data/store";

const schema = z.object({
  start: z.string().datetime(),
  end: z.string().datetime()
});

export async function POST(request: NextRequest) {
  const { start, end } = schema.parse(await request.json());
  return NextResponse.json(autoGenerateShifts(start, end));
}
