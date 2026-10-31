import { eachDayOfInterval, endOfDay, getDay, isWithinInterval, parse, startOfDay } from "date-fns";

import { validateShiftAssignment } from "@/lib/conflict-engine";
import { seedDataset } from "@/lib/data/seed";
import { getCoverageRoleForEmployeeRole } from "@/lib/roles";
import type { Department, Employee, EmployeeRole, Shift } from "@/lib/schemas";

type Dataset = {
  departments: Department[];
  employees: Employee[];
  shifts: Shift[];
};

const dataset: Dataset = structuredClone(seedDataset);

function parseTimeOnDate(baseDate: Date, value: string) {
  return parse(value, "HH:mm", baseDate);
}

function getNextShiftId() {
  const current = dataset.shifts
    .map((shift) => Number(shift.id.replace("shift-", "")))
    .filter((value) => Number.isFinite(value));
  return `shift-${Math.max(0, ...current) + 1}`;
}

function shiftFallsInRange(shift: Shift, start: string, end: string) {
  return isWithinInterval(new Date(shift.start), {
    start: startOfDay(new Date(start)),
    end: endOfDay(new Date(end))
  });
}

function buildShift(
  departmentId: string,
  employeeId: string | null,
  start: Date,
  end: Date,
  requiredEmployeeRoles: EmployeeRole[],
): Shift {
  return {
    id: getNextShiftId(),
    employeeId,
    departmentId,
    start: start.toISOString(),
    end: end.toISOString(),
    requiredEmployeeRoles,
    requiredRole: getCoverageRoleForEmployeeRole(requiredEmployeeRoles[0]),
    status: "draft"
  };
}

function canAssignShift(shift: Shift, employee: Employee, allShifts: Shift[], department: Department) {
  const result = validateShiftAssignment({
    proposedShift: shift,
    employee,
    existingShifts: allShifts,
    department,
    allDepartmentShifts: allShifts.filter((entry) => entry.departmentId === shift.departmentId),
    employees: dataset.employees,
    minimumRestHours: 10
  });

  return result.conflicts.length === 0;
}

function pickEmployeesForRoles(
  department: Department,
  start: Date,
  end: Date,
  requirements: { role: EmployeeRole; count: number }[],
  shifts: Shift[],
) {
  const assignments: Shift[] = [];
  let totalAssigned = 0;

  for (const requirement of requirements) {
    for (let index = 0; index < requirement.count; index += 1) {
      const shift = buildShift(department.id, null, start, end, [requirement.role]);
      const candidate = dataset.employees
        .filter((employee) =>
          employee.role === requirement.role &&
          (employee.primaryDepartmentId === department.id || employee.crossTrainedDepartmentIds.includes(department.id)),
        )
        .sort((a, b) => {
          const aHours = shifts.filter((entry) => entry.employeeId === a.id).length;
          const bHours = shifts.filter((entry) => entry.employeeId === b.id).length;
          return aHours - bHours;
        })
        .find((employee) => canAssignShift({ ...shift, employeeId: employee.id }, employee, [...shifts, ...assignments], department));

      if (candidate) {
        assignments.push({ ...shift, employeeId: candidate.id });
        totalAssigned += 1;
      } else {
        assignments.push(shift);
      }
    }
  }

  return { assignments, totalAssigned };
}

export function getDepartments() {
  return dataset.departments;
}

export function getDepartmentById(departmentId: string) {
  return dataset.departments.find((department) => department.id === departmentId);
}

export function getEmployees() {
  return dataset.employees;
}

export function getEmployeeById(employeeId: string) {
  return dataset.employees.find((employee) => employee.id === employeeId);
}

export function updateEmployeeRestrictions(
  employeeId: string,
  nextRestrictions: Pick<Employee, "availability" | "dayRestrictions" | "timeRestriction">,
) {
  const index = dataset.employees.findIndex((employee) => employee.id === employeeId);
  if (index === -1) {
    return null;
  }

  dataset.employees[index] = {
    ...dataset.employees[index],
    ...nextRestrictions
  };
  return dataset.employees[index];
}

export function getShifts(filters?: {
  start?: string;
  end?: string;
  departmentId?: string;
}) {
  return dataset.shifts.filter((shift) => {
    if (filters?.departmentId && shift.departmentId !== filters.departmentId) {
      return false;
    }

    if (!filters?.start || !filters?.end) {
      return true;
    }

    return shiftFallsInRange(shift, filters.start, filters.end);
  });
}

export function getShiftById(shiftId: string) {
  return dataset.shifts.find((shift) => shift.id === shiftId);
}

export function upsertShift(shift: Shift) {
  const index = dataset.shifts.findIndex((entry) => entry.id === shift.id);
  if (index === -1) {
    dataset.shifts.push(shift);
    return shift;
  }

  dataset.shifts[index] = shift;
  return shift;
}

export function deleteShift(shiftId: string) {
  const index = dataset.shifts.findIndex((shift) => shift.id === shiftId);
  if (index === -1) {
    return null;
  }

  const [removed] = dataset.shifts.splice(index, 1);
  return removed;
}

export function publishShifts(shiftIds: string[]) {
  dataset.shifts = dataset.shifts.map((shift) =>
    shiftIds.includes(shift.id) ? { ...shift, status: "published" } : shift,
  );
  return dataset.shifts.filter((shift) => shiftIds.includes(shift.id));
}

export function autoGenerateShifts(start: string, end: string) {
  const preserved = dataset.shifts.filter((shift) => !(shift.status === "draft" && shiftFallsInRange(shift, start, end)));
  const generated: Shift[] = [];

  for (const department of dataset.departments) {
    for (const day of eachDayOfInterval({ start: new Date(start), end: new Date(end) })) {
      const openHours = department.openHours.find((entry) => entry.dayOfWeek === getDay(day));
      if (!openHours) {
        continue;
      }

      const applicableRules = department.coverageRules.filter(
        (rule) => rule.dayOfWeek === null || rule.dayOfWeek === getDay(day),
      );

      for (const rule of applicableRules) {
        const shiftStart = parseTimeOnDate(day, rule.startTime);
        const shiftEnd = parseTimeOnDate(day, rule.endTime);
        const openStart = parseTimeOnDate(day, openHours.openTime);
        const openEnd = parseTimeOnDate(day, openHours.closeTime);
        const startTime = shiftStart < openStart ? openStart : shiftStart;
        const endTime = shiftEnd > openEnd ? openEnd : shiftEnd;

        if (startTime >= endTime) {
          continue;
        }

        const options = (rule.alternativeRoleSets.length ? rule.alternativeRoleSets : [[]]).map((alternative) => {
          const requirements = [...rule.requiredRoles, ...alternative];
          const result = pickEmployeesForRoles(
            department,
            startTime,
            endTime,
            requirements,
            [...preserved, ...generated],
          );

          return {
            assignments: result.assignments,
            totalAssigned: result.totalAssigned,
            totalRequired: requirements.reduce((sum, entry) => sum + entry.count, 0)
          };
        });

        const best = options.sort((a, b) => {
          if (b.totalAssigned !== a.totalAssigned) {
            return b.totalAssigned - a.totalAssigned;
          }
          return a.totalRequired - b.totalRequired;
        })[0];

        generated.push(...best.assignments);
      }
    }
  }

  dataset.shifts = [...preserved, ...generated];
  return generated;
}

export function snapshot() {
  return structuredClone(dataset);
}
