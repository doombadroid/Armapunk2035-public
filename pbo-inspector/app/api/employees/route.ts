import { NextResponse } from "next/server";

import { getEmployees } from "@/lib/data/store";

export async function GET() {
  return NextResponse.json(getEmployees());
}
