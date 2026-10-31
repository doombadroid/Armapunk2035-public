import { NextResponse } from "next/server";

import { getDepartments } from "@/lib/data/store";

export async function GET() {
  return NextResponse.json(getDepartments());
}
