import {
  differenceInHours,
  differenceInMinutes,
  endOfWeek,
  getDay,
  isAfter,
  isBefore,
  isEqual,
  isSameWeek,
  parse,
  startOfWeek,
} from "date-fns";

import type {
  Conflict,
  CoverageRule,
  Department,
  Employee,
  RoleRequirement,
  Shift,
  ValidateShiftRequest,
  ValidationResult,
  Warning,
} from "@/lib/schemas";
import { getCoverageRoleForEmployeeRole } from "@/lib/roles";

function parseTimeOnDate(baseDate: Date, value: string) {
  return parse(value, "HH:mm", baseDate);
}

function rangesOverlap(startA: Date, endA: Date, startB: Date, endB: Date) {
  return isBefore(startA, endB) && isAfter(endA, startB);
}

function isWithinWindow(start: Date, end: Date, windowStart: Date, windowEnd: Date) {
  return (isAfter(start, windowStart) || isEqual(start, windowStart)) &&
    (isBefore(end, windowEnd) || isEqual(end, windowEnd));
}

function shiftHours(shift: Shift) {
  return differenceInMinutes(new Date(shift.end), new Date(shift.start)) / 60;
}

function getWeeklyHours(shifts: Shift[], employeeId: string, anchor: Date) {
  return shifts
    .filter((shift) => shift.employeeId === employeeId)
    .filter((shift) => isSameWeek(new Date(shift.start), anchor, { weekStartsOn: 1 }))
    .reduce((total, shift) => total + shiftHours(shift), 0);
}

function getRoleCounts(shifts: Shift[], employees: Employee[]) {
  const counts = new Map<Employee["role"], number>();

  for (const shift of shifts) {
    if (!shift.employeeId) {
      continue;
    }

    const employee = employees.find((candidate) => candidate.id === shift.employeeId);
    if (!employee) {
      continue;
    }

    counts.set(employee.role, (counts.get(employee.role) ?? 0) + 1);
  }

  return counts;
}

function rolesNeeded(requirements: RoleRequirement[], roleCounts: Map<Employee["role"], number>) {
  return requirements
    .map((requirement) => {
      const scheduled = roleCounts.get(requirement.role) ?? 0;
      return {
        role: requirement.role,
        required: requirement.count,
        scheduled,
        unmet: Math.max(0, requirement.count - scheduled)
      };
    });
}

export function getCoverageStatusForRule(
  rule: CoverageRule,
  departmentShifts: Shift[],
  employees: Employee[],
  day: Date,
  proposedShift?: Shift,
) {
  const ruleStart = parseTimeOnDate(day, rule.startTime);
  const ruleEnd = parseTimeOnDate(day, rule.endTime);
  const relevantShifts = (proposedShift ? [...departmentShifts, proposedShift] : departmentShifts).filter((shift) =>
    shift.departmentId === (proposedShift?.departmentId ?? departmentShifts[0]?.departmentId) &&
    rangesOverlap(new Date(shift.start), new Date(shift.end), ruleStart, ruleEnd),
  );
  const roleCounts = getRoleCounts(relevantShifts, employees);
  const baseRoles = rolesNeeded(rule.requiredRoles, roleCounts);
  const baseMet = baseRoles.every((entry) => entry.unmet === 0);

  const alternatives = rule.alternativeRoleSets.length
    ? rule.alternativeRoleSets.map((requirements) => {
        const statuses = rolesNeeded(requirements, roleCounts);
        return {
          requirements,
          statuses,
          met: statuses.every((entry) => entry.unmet === 0),
          totalUnmet: statuses.reduce((sum, entry) => sum + entry.unmet, 0)
        };
      })
    : [];

  const bestAlternative = alternatives.length
    ? alternatives.slice().sort((a, b) => a.totalUnmet - b.totalUnmet)[0]
    : null;

  const met = baseMet && (bestAlternative ? bestAlternative.met : true);
  const unmetRoles = [
    ...baseRoles.filter((entry) => entry.unmet > 0),
    ...(bestAlternative ? bestAlternative.statuses.filter((entry) => entry.unmet > 0) : [])
  ];

  return {
    met,
    baseRoles,
    bestAlternative,
    unmetRoles
  };
}

function formatRequirementLabel(role: Employee["role"], count: number) {
  const label = role
    .split("_")
    .map((part) => part[0].toUpperCase() + part.slice(1))
    .join(" ");
  return `${count} ${label}`;
}

function formatCoverageMessage(status: ReturnType<typeof getCoverageStatusForRule>, departmentName: string, rule: CoverageRule) {
  const baseNeeds = status.baseRoles
    .filter((entry) => entry.unmet > 0)
    .map((entry) => formatRequirementLabel(entry.role, entry.unmet));
  const altNeeds = status.bestAlternative
    ? status.bestAlternative.statuses
        .filter((entry) => entry.unmet > 0)
        .map((entry) => formatRequirementLabel(entry.role, entry.unmet))
    : [];

  const parts = [...baseNeeds, ...altNeeds];
  return `${departmentName} still needs ${parts.join(", ")} for ${rule.startTime}-${rule.endTime}.`;
}

export function validateShiftAssignment({
  proposedShift,
  employee,
  existingShifts,
  department,
  allDepartmentShifts = [],
  employees = [],
  minimumRestHours = 10,
}: ValidateShiftRequest): ValidationResult {
  const conflicts: Conflict[] = [];
  const warnings: Warning[] = [];
  const shiftStart = new Date(proposedShift.start);
  const shiftEnd = new Date(proposedShift.end);
  const shiftDay = getDay(shiftStart);
  const employeeAssignments = existingShifts.filter((shift) => shift.id !== proposedShift.id);

  const overlapping = employeeAssignments.find((shift) =>
    shift.employeeId === employee.id &&
    rangesOverlap(shiftStart, shiftEnd, new Date(shift.start), new Date(shift.end)),
  );

  if (overlapping) {
    conflicts.push({
      code: "OVERLAPPING_SHIFT",
      message: `${employee.name} already has an overlapping shift.`,
      severity: "hard"
    });
  }

  const dayRestriction = employee.dayRestrictions.find((restriction) => restriction.dayOfWeek === shiftDay);

  if (dayRestriction) {
    conflicts.push({
      code: "DAY_RESTRICTION",
      message: `${employee.name} is unavailable on this day: ${dayRestriction.reason}.`,
      severity: "hard"
    });
  }

  const availabilityWindows = employee.availability.filter((availability) => availability.dayOfWeek === shiftDay);

  if (availabilityWindows.length === 0) {
    conflicts.push({
      code: "NO_AVAILABILITY",
      message: `${employee.name} has no availability configured for this day.`,
      severity: "hard"
    });
  } else {
    const available = availabilityWindows.some((window) =>
      isWithinWindow(
        shiftStart,
        shiftEnd,
        parseTimeOnDate(shiftStart, window.startTime),
        parseTimeOnDate(shiftStart, window.endTime),
      ),
    );

    if (!available) {
      conflicts.push({
        code: "OUTSIDE_AVAILABILITY",
        message: `${employee.name} is not available for the full shift window.`,
        severity: "hard"
      });
    }
  }

  if (employee.timeRestriction) {
    const earliest = parseTimeOnDate(shiftStart, employee.timeRestriction.earliestStart);
    const latest = parseTimeOnDate(shiftStart, employee.timeRestriction.latestEnd);

    if (isBefore(shiftStart, earliest) || isAfter(shiftEnd, latest)) {
      conflicts.push({
        code: "TIME_RESTRICTION",
        message: `${employee.name} cannot work outside ${employee.timeRestriction.earliestStart}-${employee.timeRestriction.latestEnd}.`,
        severity: "hard"
      });
    }
  }

  const weeklyHours = getWeeklyHours(existingShifts, employee.id, shiftStart) + shiftHours(proposedShift);

  if (weeklyHours > employee.weeklyHourCap) {
    conflicts.push({
      code: "WEEKLY_CAP_EXCEEDED",
      message: `${employee.name} would exceed the weekly hour cap.`,
      severity: "hard"
    });
  }

  if (!proposedShift.requiredEmployeeRoles.includes(employee.role)) {
    conflicts.push({
      code: "ROLE_MISMATCH",
      message: `${employee.name} cannot cover this role-specific shift.`,
      severity: "hard"
    });
  } else if (proposedShift.requiredRole !== getCoverageRoleForEmployeeRole(employee.role)) {
    conflicts.push({
      code: "ROLE_MISMATCH",
      message: `${employee.name} does not match the shift coverage role.`,
      severity: "hard"
    });
  }

  const canWorkDepartment =
    employee.primaryDepartmentId === proposedShift.departmentId ||
    employee.crossTrainedDepartmentIds.includes(proposedShift.departmentId);

  if (!canWorkDepartment) {
    conflicts.push({
      code: "DEPARTMENT_MISMATCH",
      message: `${employee.name} is not assigned or cross-trained for ${department.name}.`,
      severity: "hard"
    });
  }

  if (employee.employmentType === "part_time" && weeklyHours >= 32) {
    warnings.push({
      code: "PART_TIME_THRESHOLD",
      message: `${employee.name} is approaching a full-time workload.`,
      severity: "soft"
    });
  }

  if (employee.employmentType === "full_time" && weeklyHours < employee.weeklyHourFloor) {
    warnings.push({
      code: "FULL_TIME_FLOOR",
      message: `${employee.name} is still below the weekly floor after this assignment.`,
      severity: "soft"
    });
  }

  const adjacent = employeeAssignments.find((shift) => {
    if (shift.employeeId !== employee.id) {
      return false;
    }

    const priorEnd = new Date(shift.end);
    const nextStart = new Date(shift.start);
    const restGap =
      priorEnd <= shiftStart
        ? differenceInHours(shiftStart, priorEnd)
        : nextStart >= shiftEnd
          ? differenceInHours(nextStart, shiftEnd)
          : Infinity;

    return restGap < minimumRestHours;
  });

  if (adjacent) {
    warnings.push({
      code: "MINIMUM_REST",
      message: `${employee.name} has less than ${minimumRestHours} hours of rest between shifts.`,
      severity: "soft"
    });
  }

  const departmentShifts = allDepartmentShifts.filter(
    (shift) => shift.id !== proposedShift.id && shift.departmentId === proposedShift.departmentId,
  );
  const ruleMatch = department.coverageRules.filter((rule) => {
    const sameDay = rule.dayOfWeek === null || rule.dayOfWeek === shiftDay;
    return sameDay &&
      rangesOverlap(
        shiftStart,
        shiftEnd,
        parseTimeOnDate(shiftStart, rule.startTime),
        parseTimeOnDate(shiftStart, rule.endTime),
      );
  });

  for (const rule of ruleMatch) {
    const status = getCoverageStatusForRule(rule, departmentShifts, employees, shiftStart, proposedShift);
    if (!status.met) {
      warnings.push({
        code: "COVERAGE_UNMET",
        message: formatCoverageMessage(status, department.name, rule),
        severity: "soft"
      });
      break;
    }
  }

  const chargeDepartmentId =
    department.budgetChargeMode === "worked_department"
      ? proposedShift.departmentId
      : employee.primaryDepartmentId;

  const periodStart = startOfWeek(shiftStart, { weekStartsOn: 1 });
  const periodEnd = endOfWeek(shiftStart, { weekStartsOn: 1 });
  const departmentBudgetHours = allDepartmentShifts
    .filter((shift) => {
      if (!shift.employeeId) {
        return false;
      }

      const assignee = employees.find((candidate) => candidate.id === shift.employeeId);
      if (!assignee) {
        return false;
      }

      const fundingDepartmentId =
        department.budgetChargeMode === "worked_department"
          ? shift.departmentId
          : assignee.primaryDepartmentId;

      const date = new Date(shift.start);
      return fundingDepartmentId === chargeDepartmentId && date >= periodStart && date <= periodEnd;
    })
    .reduce((sum, shift) => {
      const assignee = employees.find((candidate) => candidate.id === shift.employeeId);
      return sum + shiftHours(shift) * (assignee?.hourlyRate ?? 0);
    }, 0);

  const projectedBudget = departmentBudgetHours + shiftHours(proposedShift) * employee.hourlyRate;

  if (projectedBudget > department.payBudget) {
    warnings.push({
      code: "BUDGET_EXCEEDED",
      message: `${department.name} would exceed its pay budget for the period.`,
      severity: "soft"
    });
  }

  return { conflicts, warnings };
}
