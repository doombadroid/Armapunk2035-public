import { NextRequest, NextResponse } from "next/server";

import { getPaySummary } from "@/lib/data/metrics";
import { getDepartments, getEmployees, getShifts } from "@/lib/data/store";

export async function GET(request: NextRequest) {
  const searchParams = request.nextUrl.searchParams;
  const departmentId = searchParams.get("departmentId");
  const periodStart = searchParams.get("periodStart");
  const periodEnd = searchParams.get("periodEnd");

  if (!periodStart || !periodEnd) {
    return NextResponse.json({ message: "periodStart and periodEnd are required" }, { status: 400 });
  }

  const summary = getPaySummary(
    getDepartments(),
    getEmployees(),
    getShifts({ start: periodStart, end: periodEnd }),
    new Date(periodStart),
    new Date(periodEnd),
  );

  return NextResponse.json(
    departmentId
      ? summary.find((entry) => entry.departmentId === departmentId) ?? null
      : summary,
  );
}
