import { NextRequest, NextResponse } from "next/server";

import { getCoverageBlocks } from "@/lib/data/metrics";
import { getDepartmentById, getEmployees, getShifts } from "@/lib/data/store";

export async function GET(request: NextRequest) {
  const searchParams = request.nextUrl.searchParams;
  const departmentId = searchParams.get("departmentId");
  const start = searchParams.get("start");
  const end = searchParams.get("end");

  if (!departmentId || !start || !end) {
    return NextResponse.json({ message: "departmentId, start, and end are required" }, { status: 400 });
  }

  const department = getDepartmentById(departmentId);
  if (!department) {
    return NextResponse.json({ message: "Department not found" }, { status: 404 });
  }

  return NextResponse.json(
    getCoverageBlocks(
      department,
      getEmployees(),
      getShifts({ start, end, departmentId }),
      new Date(start),
      new Date(end),
    ),
  );
}
