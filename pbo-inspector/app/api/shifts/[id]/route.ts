import { NextRequest, NextResponse } from "next/server";

import { deleteShift, getShiftById, upsertShift } from "@/lib/data/store";
import { shiftSchema } from "@/lib/schemas";

export async function PATCH(
  request: NextRequest,
  { params }: { params: { id: string } },
) {
  const current = getShiftById(params.id);
  if (!current) {
    return NextResponse.json({ message: "Shift not found" }, { status: 404 });
  }

  const payload = shiftSchema.partial().parse(await request.json());
  const updated = { ...current, ...payload, id: params.id };
  return NextResponse.json(upsertShift(updated));
}

export async function DELETE(
  _request: NextRequest,
  { params }: { params: { id: string } },
) {
  const removed = deleteShift(params.id);
  if (!removed) {
    return NextResponse.json({ message: "Shift not found" }, { status: 404 });
  }

  return NextResponse.json(removed);
}
