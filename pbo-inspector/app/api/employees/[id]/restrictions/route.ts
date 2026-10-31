import { NextRequest, NextResponse } from "next/server";

import { employeeSchema } from "@/lib/schemas";
import { updateEmployeeRestrictions } from "@/lib/data/store";

export async function PATCH(
  request: NextRequest,
  { params }: { params: { id: string } },
) {
  const payload = employeeSchema.pick({
    availability: true,
    dayRestrictions: true,
    timeRestriction: true
  }).parse(await request.json());

  const updated = updateEmployeeRestrictions(params.id, payload);

  if (!updated) {
    return NextResponse.json({ message: "Employee not found" }, { status: 404 });
  }

  return NextResponse.json(updated);
}
