import type { EmployeeRole, ShiftCoverageRole } from "@/lib/schemas";

const managerRoles = new Set<EmployeeRole>([
  "store_manager",
  "assistant_store_manager",
  "commercial_sales_manager",
  "commercial_manager",
  "hub_coordinator"
]);

export function isManagerRole(role: EmployeeRole) {
  return managerRoles.has(role);
}

export function formatEmployeeRole(role: EmployeeRole) {
  return role
    .split("_")
    .map((part) => part[0].toUpperCase() + part.slice(1))
    .join(" ");
}

export function getCoverageRoleForEmployeeRole(role: EmployeeRole): ShiftCoverageRole {
  return isManagerRole(role) ? "manager" : "staff";
}
