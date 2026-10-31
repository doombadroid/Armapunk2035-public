import { NextRequest, NextResponse } from "next/server";

import { validateShiftAssignment } from "@/lib/conflict-engine";
import { validateShiftRequestSchema } from "@/lib/schemas";

export async function POST(request: NextRequest) {
  const payload = validateShiftRequestSchema.parse(await request.json());
  return NextResponse.json(validateShiftAssignment(payload));
}
