import { z } from "zod";

export const employeeRoleSchema = z.enum([
  "store_manager",
  "assistant_store_manager",
  "gray_shirt",
  "red_shirt",
  "commercial_sales_manager",
  "commercial_manager",
  "commercial_driver",
  "hub_coordinator",
  "hub_specialist",
  "picker",
  "hub_driver"
]);
export const shiftCoverageRoleSchema = z.enum(["manager", "staff"]);
export const employmentTypeSchema = z.enum(["full_time", "part_time"]);
export const shiftStatusSchema = z.enum(["draft", "published"]);
export const fundingDepartmentModeSchema = z.enum(["primary_department", "worked_department"]);

export const roleRequirementSchema = z.object({
  role: employeeRoleSchema,
  count: z.number().int().positive()
});

export const coverageRuleSchema = z.object({
  id: z.string(),
  dayOfWeek: z.number().min(0).max(6).nullable(),
  startTime: z.string(),
  endTime: z.string(),
  requiredRoles: z.array(roleRequirementSchema).default([]),
  alternativeRoleSets: z.array(z.array(roleRequirementSchema)).default([])
});

export const openHoursRuleSchema = z.object({
  id: z.string(),
  dayOfWeek: z.number().min(0).max(6),
  openTime: z.string(),
  closeTime: z.string()
});

export const departmentSchema = z.object({
  id: z.string(),
  name: z.string(),
  coverageRules: z.array(coverageRuleSchema),
  openHours: z.array(openHoursRuleSchema),
  payBudget: z.number().nonnegative(),
  payPeriodLengthDays: z.number().int().positive(),
  budgetChargeMode: fundingDepartmentModeSchema.default("primary_department")
});

export const availabilitySchema = z.object({
  employeeId: z.string(),
  dayOfWeek: z.number().min(0).max(6),
  startTime: z.string(),
  endTime: z.string()
});

export const dayRestrictionSchema = z.object({
  employeeId: z.string(),
  dayOfWeek: z.number().min(0).max(6),
  reason: z.string()
});

export const timeRestrictionSchema = z.object({
  employeeId: z.string(),
  earliestStart: z.string(),
  latestEnd: z.string()
});

export const employeeSchema = z.object({
  id: z.string(),
  name: z.string(),
  role: employeeRoleSchema,
  primaryDepartmentId: z.string(),
  crossTrainedDepartmentIds: z.array(z.string()),
  employmentType: employmentTypeSchema,
  hourlyRate: z.number().positive(),
  weeklyHourCap: z.number().positive(),
  weeklyHourFloor: z.number().nonnegative(),
  availability: z.array(availabilitySchema),
  dayRestrictions: z.array(dayRestrictionSchema),
  timeRestriction: timeRestrictionSchema.nullable()
});

export const shiftSchema = z.object({
  id: z.string(),
  employeeId: z.string().nullable(),
  departmentId: z.string(),
  start: z.string().datetime(),
  end: z.string().datetime(),
  requiredRole: shiftCoverageRoleSchema,
  requiredEmployeeRoles: z.array(employeeRoleSchema).min(1),
  status: shiftStatusSchema
});

export const validateShiftRequestSchema = z.object({
  proposedShift: shiftSchema,
  employee: employeeSchema,
  existingShifts: z.array(shiftSchema),
  department: departmentSchema,
  allDepartmentShifts: z.array(shiftSchema).default([]),
  employees: z.array(employeeSchema).default([]),
  minimumRestHours: z.number().nonnegative().default(10)
});

export const conflictSchema = z.object({
  code: z.string(),
  message: z.string(),
  severity: z.literal("hard")
});

export const warningSchema = z.object({
  code: z.string(),
  message: z.string(),
  severity: z.literal("soft")
});

export const validationResultSchema = z.object({
  conflicts: z.array(conflictSchema),
  warnings: z.array(warningSchema)
});

export type EmployeeRole = z.infer<typeof employeeRoleSchema>;
export type ShiftCoverageRole = z.infer<typeof shiftCoverageRoleSchema>;
export type EmploymentType = z.infer<typeof employmentTypeSchema>;
export type ShiftStatus = z.infer<typeof shiftStatusSchema>;
export type RoleRequirement = z.infer<typeof roleRequirementSchema>;
export type CoverageRule = z.infer<typeof coverageRuleSchema>;
export type OpenHoursRule = z.infer<typeof openHoursRuleSchema>;
export type Department = z.infer<typeof departmentSchema>;
export type Availability = z.infer<typeof availabilitySchema>;
export type DayRestriction = z.infer<typeof dayRestrictionSchema>;
export type TimeRestriction = z.infer<typeof timeRestrictionSchema>;
export type Employee = z.infer<typeof employeeSchema>;
export type Shift = z.infer<typeof shiftSchema>;
export type Conflict = z.infer<typeof conflictSchema>;
export type Warning = z.infer<typeof warningSchema>;
export type ValidateShiftRequest = {
  proposedShift: Shift;
  employee: Employee;
  existingShifts: Shift[];
  department: Department;
  allDepartmentShifts?: Shift[];
  employees?: Employee[];
  minimumRestHours?: number;
};
export type ValidationResult = z.infer<typeof validationResultSchema>;
