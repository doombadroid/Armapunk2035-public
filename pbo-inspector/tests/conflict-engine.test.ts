import { addDays, setHours, setMinutes } from "date-fns";
import { describe, expect, it } from "vitest";

import { validateShiftAssignment } from "@/lib/conflict-engine";
import type { Department, Employee, Shift } from "@/lib/schemas";

const monday = new Date("2026-04-20T08:00:00.000Z");

function at(dayOffset: number, hours: number, minutes = 0) {
  return setMinutes(setHours(addDays(monday, dayOffset), hours), minutes).toISOString();
}

function makeEmployee(overrides: Partial<Employee> = {}): Employee {
  return {
    id: "emp-1",
    name: "Jordan Smith",
    role: "red_shirt",
    primaryDepartmentId: "diy",
    crossTrainedDepartmentIds: [],
    employmentType: "part_time",
    hourlyRate: 20,
    weeklyHourCap: 30,
    weeklyHourFloor: 0,
    availability: [
      { employeeId: "emp-1", dayOfWeek: 1, startTime: "05:45", endTime: "12:15" }
    ],
    dayRestrictions: [],
    timeRestriction: { employeeId: "emp-1", earliestStart: "05:45", latestEnd: "12:15" },
    ...overrides
  };
}

function makeDepartment(overrides: Partial<Department> = {}): Department {
  return {
    id: "diy",
    name: "DIY",
    payBudget: 1500,
    payPeriodLengthDays: 7,
    budgetChargeMode: "primary_department",
    openHours: [{ id: "diy-mon", dayOfWeek: 1, openTime: "05:45", closeTime: "12:15" }],
    coverageRules: [
      {
        id: "rule-1",
        dayOfWeek: 1,
        startTime: "05:45",
        endTime: "12:15",
        requiredRoles: [{ role: "red_shirt", count: 1 }],
        alternativeRoleSets: [
          [{ role: "store_manager", count: 1 }],
          [{ role: "assistant_store_manager", count: 1 }]
        ]
      }
    ],
    ...overrides
  };
}

function makeShift(overrides: Partial<Shift> = {}): Shift {
  return {
    id: "shift-1",
    employeeId: "emp-1",
    departmentId: "diy",
    start: at(0, 6),
    end: at(0, 12),
    requiredRole: "staff",
    requiredEmployeeRoles: ["red_shirt"],
    status: "draft",
    ...overrides
  };
}

describe("validateShiftAssignment", () => {
  it("passes a valid assignment", () => {
    const employee = makeEmployee({ role: "store_manager", weeklyHourCap: 40 });
    const proposedShift = makeShift({ requiredRole: "manager", requiredEmployeeRoles: ["store_manager", "assistant_store_manager"] });
    const existingShifts = [makeShift({ id: "shift-existing", employeeId: "emp-2", start: at(1, 6), end: at(1, 12) })];
    const department = makeDepartment();
    const result = validateShiftAssignment({
      proposedShift,
      employee,
      existingShifts,
      department,
      allDepartmentShifts: existingShifts,
      employees: [employee],
      minimumRestHours: 10
    });
    expect(result.conflicts).toHaveLength(0);
  });

  it("blocks overlapping assigned shifts", () => {
    const employee = makeEmployee();
    const proposedShift = makeShift();
    const existingShifts = [makeShift({ id: "existing", start: at(0, 8), end: at(0, 12) })];
    const result = validateShiftAssignment({
      proposedShift,
      employee,
      existingShifts,
      department: makeDepartment(),
      allDepartmentShifts: [],
      employees: [],
      minimumRestHours: 10
    });
    expect(result.conflicts.map((conflict) => conflict.code)).toContain("OVERLAPPING_SHIFT");
  });

  it("allows non-overlapping shifts", () => {
    const employee = makeEmployee();
    const proposedShift = makeShift();
    const existingShifts = [makeShift({ id: "existing", start: at(0, 12), end: at(0, 13) })];
    const result = validateShiftAssignment({
      proposedShift,
      employee,
      existingShifts,
      department: makeDepartment(),
      allDepartmentShifts: [],
      employees: [],
      minimumRestHours: 10
    });
    expect(result.conflicts.map((conflict) => conflict.code)).not.toContain("OVERLAPPING_SHIFT");
  });

  it("blocks shifts outside availability windows", () => {
    const employee = makeEmployee();
    const proposedShift = makeShift({ start: at(0, 4), end: at(0, 10) });
    const result = validateShiftAssignment({
      proposedShift,
      employee,
      existingShifts: [],
      department: makeDepartment(),
      allDepartmentShifts: [],
      employees: [],
      minimumRestHours: 10
    });
    expect(result.conflicts.map((conflict) => conflict.code)).toContain("OUTSIDE_AVAILABILITY");
  });

  it("passes shifts within availability windows", () => {
    const employee = makeEmployee();
    const proposedShift = makeShift();
    const result = validateShiftAssignment({
      proposedShift,
      employee,
      existingShifts: [],
      department: makeDepartment(),
      allDepartmentShifts: [],
      employees: [],
      minimumRestHours: 10
    });
    expect(result.conflicts.map((conflict) => conflict.code)).not.toContain("OUTSIDE_AVAILABILITY");
  });

  it("blocks day restrictions", () => {
    const employee = makeEmployee({
      dayRestrictions: [{ employeeId: "emp-1", dayOfWeek: 1, reason: "Class" }]
    });
    const result = validateShiftAssignment({
      proposedShift: makeShift(),
      employee,
      existingShifts: [],
      department: makeDepartment(),
      allDepartmentShifts: [],
      employees: [],
      minimumRestHours: 10
    });
    expect(result.conflicts.map((conflict) => conflict.code)).toContain("DAY_RESTRICTION");
  });

  it("passes when no day restriction applies", () => {
    const employee = makeEmployee({
      dayRestrictions: [{ employeeId: "emp-1", dayOfWeek: 2, reason: "Class" }]
    });
    const result = validateShiftAssignment({
      proposedShift: makeShift(),
      employee,
      existingShifts: [],
      department: makeDepartment(),
      allDepartmentShifts: [],
      employees: [],
      minimumRestHours: 10
    });
    expect(result.conflicts.map((conflict) => conflict.code)).not.toContain("DAY_RESTRICTION");
  });

  it("blocks time restriction violations", () => {
    const employee = makeEmployee();
    const result = validateShiftAssignment({
      proposedShift: makeShift({ start: at(0, 5), end: at(0, 12) }),
      employee,
      existingShifts: [],
      department: makeDepartment(),
      allDepartmentShifts: [],
      employees: [],
      minimumRestHours: 10
    });
    expect(result.conflicts.map((conflict) => conflict.code)).toContain("TIME_RESTRICTION");
  });

  it("passes time restriction compliant shifts", () => {
    const employee = makeEmployee();
    const result = validateShiftAssignment({
      proposedShift: makeShift(),
      employee,
      existingShifts: [],
      department: makeDepartment(),
      allDepartmentShifts: [],
      employees: [],
      minimumRestHours: 10
    });
    expect(result.conflicts.map((conflict) => conflict.code)).not.toContain("TIME_RESTRICTION");
  });

  it("blocks weekly hour cap overages", () => {
    const employee = makeEmployee({ weeklyHourCap: 8 });
    const existingShifts = [makeShift({ id: "existing", start: at(1, 6), end: at(1, 12) })];
    const result = validateShiftAssignment({
      proposedShift: makeShift(),
      employee,
      existingShifts,
      department: makeDepartment(),
      allDepartmentShifts: [],
      employees: [],
      minimumRestHours: 10
    });
    expect(result.conflicts.map((conflict) => conflict.code)).toContain("WEEKLY_CAP_EXCEEDED");
  });

  it("passes within weekly hour cap", () => {
    const employee = makeEmployee({ weeklyHourCap: 20 });
    const existingShifts = [makeShift({ id: "existing", start: at(1, 6), end: at(1, 10) })];
    const result = validateShiftAssignment({
      proposedShift: makeShift(),
      employee,
      existingShifts,
      department: makeDepartment(),
      allDepartmentShifts: [],
      employees: [],
      minimumRestHours: 10
    });
    expect(result.conflicts.map((conflict) => conflict.code)).not.toContain("WEEKLY_CAP_EXCEEDED");
  });

  it("blocks non-matching employee roles on exact-role shifts", () => {
    const employee = makeEmployee({ role: "gray_shirt" });
    const result = validateShiftAssignment({
      proposedShift: makeShift({ requiredEmployeeRoles: ["red_shirt"] }),
      employee,
      existingShifts: [],
      department: makeDepartment(),
      allDepartmentShifts: [],
      employees: [],
      minimumRestHours: 10
    });
    expect(result.conflicts.map((conflict) => conflict.code)).toContain("ROLE_MISMATCH");
  });

  it("passes matching employee roles on exact-role shifts", () => {
    const employee = makeEmployee({ role: "red_shirt" });
    const result = validateShiftAssignment({
      proposedShift: makeShift({ requiredEmployeeRoles: ["red_shirt"] }),
      employee,
      existingShifts: [],
      department: makeDepartment(),
      allDepartmentShifts: [],
      employees: [],
      minimumRestHours: 10
    });
    expect(result.conflicts.map((conflict) => conflict.code)).not.toContain("ROLE_MISMATCH");
  });

  it("blocks department mismatches without cross-training", () => {
    const employee = makeEmployee({ primaryDepartmentId: "commercial" });
    const result = validateShiftAssignment({
      proposedShift: makeShift({ departmentId: "diy" }),
      employee,
      existingShifts: [],
      department: makeDepartment(),
      allDepartmentShifts: [],
      employees: [],
      minimumRestHours: 10
    });
    expect(result.conflicts.map((conflict) => conflict.code)).toContain("DEPARTMENT_MISMATCH");
  });

  it("passes department mismatches with cross-training", () => {
    const employee = makeEmployee({
      primaryDepartmentId: "commercial",
      crossTrainedDepartmentIds: ["diy"]
    });
    const result = validateShiftAssignment({
      proposedShift: makeShift({ departmentId: "diy" }),
      employee,
      existingShifts: [],
      department: makeDepartment(),
      allDepartmentShifts: [],
      employees: [],
      minimumRestHours: 10
    });
    expect(result.conflicts.map((conflict) => conflict.code)).not.toContain("DEPARTMENT_MISMATCH");
  });

  it("warns when part-time employee approaches full-time workload", () => {
    const employee = makeEmployee({ weeklyHourCap: 40 });
    const existingShifts = [
      makeShift({ id: "existing-1", start: at(1, 6), end: at(1, 12) }),
      makeShift({ id: "existing-2", start: at(2, 6), end: at(2, 12) }),
      makeShift({ id: "existing-3", start: at(3, 6), end: at(3, 12) }),
      makeShift({ id: "existing-4", start: at(4, 6), end: at(4, 12) }),
      makeShift({ id: "existing-5", start: at(5, 6), end: at(5, 12) })
    ];
    const result = validateShiftAssignment({
      proposedShift: makeShift(),
      employee,
      existingShifts,
      department: makeDepartment(),
      allDepartmentShifts: [],
      employees: [],
      minimumRestHours: 10
    });
    expect(result.warnings.map((warning) => warning.code)).toContain("PART_TIME_THRESHOLD");
  });

  it("does not warn part-time threshold when far below", () => {
    const employee = makeEmployee();
    const result = validateShiftAssignment({
      proposedShift: makeShift(),
      employee,
      existingShifts: [],
      department: makeDepartment(),
      allDepartmentShifts: [],
      employees: [],
      minimumRestHours: 10
    });
    expect(result.warnings.map((warning) => warning.code)).not.toContain("PART_TIME_THRESHOLD");
  });

  it("warns when a full-time employee remains below floor", () => {
    const employee = makeEmployee({
      role: "store_manager",
      employmentType: "full_time",
      weeklyHourFloor: 40,
      weeklyHourCap: 45
    });
    const result = validateShiftAssignment({
      proposedShift: makeShift({ requiredRole: "manager", requiredEmployeeRoles: ["store_manager"] }),
      employee,
      existingShifts: [],
      department: makeDepartment(),
      allDepartmentShifts: [],
      employees: [],
      minimumRestHours: 10
    });
    expect(result.warnings.map((warning) => warning.code)).toContain("FULL_TIME_FLOOR");
  });

  it("does not warn full-time floor when the floor is met", () => {
    const employee = makeEmployee({
      role: "store_manager",
      employmentType: "full_time",
      weeklyHourFloor: 18,
      weeklyHourCap: 45
    });
    const existingShifts = [
      makeShift({ id: "existing-1", employeeId: "emp-1", start: at(1, 6), end: at(1, 12), requiredRole: "manager", requiredEmployeeRoles: ["store_manager"] }),
      makeShift({ id: "existing-2", employeeId: "emp-1", start: at(2, 6), end: at(2, 12), requiredRole: "manager", requiredEmployeeRoles: ["store_manager"] })
    ];
    const result = validateShiftAssignment({
      proposedShift: makeShift({ requiredRole: "manager", requiredEmployeeRoles: ["store_manager"] }),
      employee,
      existingShifts,
      department: makeDepartment(),
      allDepartmentShifts: [],
      employees: [],
      minimumRestHours: 10
    });
    expect(result.warnings.map((warning) => warning.code)).not.toContain("FULL_TIME_FLOOR");
  });

  it("warns when minimum rest is violated", () => {
    const employee = makeEmployee({ weeklyHourCap: 50 });
    const existingShifts = [makeShift({ id: "existing", start: at(0, 22), end: at(0, 23) })];
    const result = validateShiftAssignment({
      proposedShift: makeShift({ start: at(1, 5, 45), end: at(1, 12, 15) }),
      employee,
      existingShifts,
      department: makeDepartment(),
      allDepartmentShifts: [],
      employees: [],
      minimumRestHours: 10
    });
    expect(result.warnings.map((warning) => warning.code)).toContain("MINIMUM_REST");
  });

  it("does not warn when minimum rest is satisfied", () => {
    const employee = makeEmployee({ weeklyHourCap: 50 });
    const existingShifts = [makeShift({ id: "existing", start: at(0, 6), end: at(0, 8) })];
    const result = validateShiftAssignment({
      proposedShift: makeShift({ start: at(1, 6), end: at(1, 12) }),
      employee,
      existingShifts,
      department: makeDepartment(),
      allDepartmentShifts: [],
      employees: [],
      minimumRestHours: 10
    });
    expect(result.warnings.map((warning) => warning.code)).not.toContain("MINIMUM_REST");
  });

  it("warns when coverage remains unmet", () => {
    const employee = makeEmployee({ role: "red_shirt", weeklyHourCap: 50 });
    const result = validateShiftAssignment({
      proposedShift: makeShift(),
      employee,
      existingShifts: [],
      department: makeDepartment(),
      allDepartmentShifts: [makeShift()],
      employees: [employee],
      minimumRestHours: 10
    });
    expect(result.warnings.map((warning) => warning.code)).toContain("COVERAGE_UNMET");
  });

  it("does not warn when coverage is satisfied", () => {
    const manager = makeEmployee({
      id: "emp-manager",
      name: "Morgan",
      role: "store_manager",
      weeklyHourCap: 50,
      timeRestriction: { employeeId: "emp-manager", earliestStart: "05:45", latestEnd: "12:15" }
    });
    const redShirt = makeEmployee({
      id: "emp-red",
      name: "Avery",
      role: "red_shirt",
      weeklyHourCap: 50
    });
    const result = validateShiftAssignment({
      proposedShift: makeShift({ id: "new", employeeId: "emp-red" }),
      employee: redShirt,
      existingShifts: [],
      department: makeDepartment(),
      allDepartmentShifts: [
        makeShift({ id: "m", employeeId: "emp-manager", requiredRole: "manager", requiredEmployeeRoles: ["store_manager"] })
      ],
      employees: [manager, redShirt],
      minimumRestHours: 10
    });
    expect(result.warnings.map((warning) => warning.code)).not.toContain("COVERAGE_UNMET");
  });

  it("warns when department budget would be exceeded", () => {
    const employee = makeEmployee({ hourlyRate: 50, weeklyHourCap: 50 });
    const result = validateShiftAssignment({
      proposedShift: makeShift(),
      employee,
      existingShifts: [],
      department: makeDepartment({ payBudget: 200 }),
      allDepartmentShifts: [],
      employees: [employee],
      minimumRestHours: 10
    });
    expect(result.warnings.map((warning) => warning.code)).toContain("BUDGET_EXCEEDED");
  });

  it("does not warn when budget remains within limit", () => {
    const employee = makeEmployee({ hourlyRate: 20, weeklyHourCap: 50 });
    const result = validateShiftAssignment({
      proposedShift: makeShift(),
      employee,
      existingShifts: [],
      department: makeDepartment({ payBudget: 500 }),
      allDepartmentShifts: [],
      employees: [employee],
      minimumRestHours: 10
    });
    expect(result.warnings.map((warning) => warning.code)).not.toContain("BUDGET_EXCEEDED");
  });
});
