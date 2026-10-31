import type { Department, Employee, Shift } from "@/lib/schemas";

export type SchedulerDataset = {
  departments: Department[];
  employees: Employee[];
  shifts: Shift[];
};
