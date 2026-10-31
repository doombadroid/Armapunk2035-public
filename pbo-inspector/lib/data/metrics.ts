import {
  addMinutes,
  eachDayOfInterval,
  endOfWeek,
  format,
  getDay,
  isWithinInterval,
  parse,
  startOfWeek
} from "date-fns";

import { getCoverageStatusForRule } from "@/lib/conflict-engine";
import { formatEmployeeRole } from "@/lib/roles";
import type { Department, Employee, Shift } from "@/lib/schemas";

function minutesForShift(shift: Shift) {
  return (new Date(shift.end).getTime() - new Date(shift.start).getTime()) / (1000 * 60);
}

function payForShift(shift: Shift, employee: Employee) {
  return (minutesForShift(shift) / 60) * employee.hourlyRate;
}

function parseTimeOnDate(baseDate: Date, value: string) {
  return parse(value, "HH:mm", baseDate);
}

export function getWeeklyHoursForEmployee(employeeId: string, shifts: Shift[], anchor = new Date()) {
  const period = {
    start: startOfWeek(anchor, { weekStartsOn: 1 }),
    end: endOfWeek(anchor, { weekStartsOn: 1 })
  };
  return shifts
    .filter((shift) => shift.employeeId === employeeId)
    .filter((shift) => isWithinInterval(new Date(shift.start), period))
    .reduce((sum, shift) => sum + minutesForShift(shift) / 60, 0);
}

export function getOpenHoursForDay(department: Department, day: Date) {
  return department.openHours.find((entry) => entry.dayOfWeek === getDay(day)) ?? null;
}

export function getCoverageBlocks(
  department: Department,
  employees: Employee[],
  shifts: Shift[],
  start: Date,
  end: Date,
) {
  const blocks = department.coverageRules.flatMap((rule) =>
    eachDayOfInterval({ start, end })
      .filter((day) => rule.dayOfWeek === null || rule.dayOfWeek === getDay(day))
      .map((day) => {
        const blockStart = parseTimeOnDate(day, rule.startTime);
        const blockEnd = parseTimeOnDate(day, rule.endTime);
        const scheduled = shifts.filter((shift) =>
          shift.departmentId === department.id &&
          shift.employeeId &&
          new Date(shift.start) < blockEnd &&
          new Date(shift.end) > blockStart,
        );
        const status = getCoverageStatusForRule(rule, scheduled, employees, day);

        return {
          id: `${department.id}-${format(day, "yyyy-MM-dd")}-${rule.id}`,
          departmentId: department.id,
          dateKey: format(day, "yyyy-MM-dd"),
          label: `${format(day, "EEE MMM d")} ${rule.startTime}-${rule.endTime}`,
          state: status.met ? "green" : "red",
          openHours: getOpenHoursForDay(department, day),
          roleStatuses: [
            ...status.baseRoles,
            ...(status.bestAlternative ? status.bestAlternative.statuses : [])
          ].map((entry) => ({
            role: entry.role,
            roleLabel: formatEmployeeRole(entry.role),
            required: entry.required,
            scheduled: entry.scheduled
          })),
          alternativeLabel: status.bestAlternative
            ? status.bestAlternative.requirements.map((entry) => `${entry.count} ${formatEmployeeRole(entry.role)}`).join(" + ")
            : null
        };
      }),
  );

  return blocks;
}

export function getPaySummary(
  departments: Department[],
  employees: Employee[],
  shifts: Shift[],
  periodStart: Date,
  periodEnd: Date,
) {
  return departments.map((department) => {
    const scheduledPay = shifts.reduce((total, shift) => {
      if (!shift.employeeId) {
        return total;
      }

      const employee = employees.find((candidate) => candidate.id === shift.employeeId);
      if (!employee) {
        return total;
      }

      if (new Date(shift.start) < periodStart || new Date(shift.end) > addMinutes(periodEnd, 1)) {
        return total;
      }

      const budgetDepartmentId =
        department.budgetChargeMode === "worked_department"
          ? shift.departmentId
          : employee.primaryDepartmentId;

      if (budgetDepartmentId !== department.id) {
        return total;
      }

      return total + payForShift(shift, employee);
    }, 0);

    return {
      departmentId: department.id,
      departmentName: department.name,
      scheduledPay,
      budget: department.payBudget,
      variance: department.payBudget - scheduledPay,
      state:
        scheduledPay > department.payBudget
          ? "over"
          : scheduledPay > department.payBudget * 0.9
            ? "amber"
            : "within"
    };
  });
}
