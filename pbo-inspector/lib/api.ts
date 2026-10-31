import { addDays } from "date-fns";

import type {
  Department,
  Employee,
  Shift,
  ValidateShiftRequest,
  ValidationResult,
} from "@/lib/schemas";

export async function fetchJson<T>(input: RequestInfo, init?: RequestInit): Promise<T> {
  const response = await fetch(input, {
    ...init,
    headers: {
      "Content-Type": "application/json",
      ...(init?.headers ?? {})
    }
  });

  if (!response.ok) {
    const error = await response.json().catch(() => ({ message: "Request failed" }));
    throw new Error(error.message ?? "Request failed");
  }

  return response.json() as Promise<T>;
}

export async function getSchedulerSnapshot(rangeStart: string) {
  const rangeEnd = addDays(new Date(rangeStart), 14).toISOString();
  const [employees, shifts, departments] = await Promise.all([
    fetchJson<Employee[]>("/api/employees"),
    fetchJson<Shift[]>(`/api/shifts?start=${rangeStart}&end=${rangeEnd}`),
    fetchJson<Department[]>("/api/departments")
  ]);

  return {
    employees,
    shifts,
    departments
  };
}

export function validateAssignment(payload: ValidateShiftRequest) {
  return fetchJson<ValidationResult>("/api/shifts/validate", {
    method: "POST",
    body: JSON.stringify(payload)
  });
}

export function autoGenerateAssignments(start: string, end: string) {
  return fetchJson<Shift[]>("/api/shifts/auto-generate", {
    method: "POST",
    body: JSON.stringify({ start, end })
  });
}
