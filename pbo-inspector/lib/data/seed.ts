import { addDays, setHours, setMinutes } from "date-fns";

import { getCoverageRoleForEmployeeRole } from "@/lib/roles";
import type { Department, Employee, EmployeeRole, RoleRequirement, Shift } from "@/lib/schemas";

const monday = new Date("2026-04-20T00:00:00.000Z");

function dateAt(dayOffset: number, hours: number, minutes = 0) {
  return setMinutes(setHours(addDays(monday, dayOffset), hours), minutes).toISOString();
}

function fullWeekAvailability(employeeId: string, startTime: string, endTime: string, weekdaysOnly = false) {
  const days = weekdaysOnly ? [1, 2, 3, 4, 5, 6] : [0, 1, 2, 3, 4, 5, 6];
  return days.map((day) => ({
    employeeId,
    dayOfWeek: day,
    startTime,
    endTime
  }));
}

function makeShift(
  id: string,
  employeeId: string | null,
  departmentId: string,
  start: string,
  end: string,
  requiredEmployeeRoles: EmployeeRole[],
): Shift {
  return {
    id,
    employeeId,
    departmentId,
    start,
    end,
    requiredEmployeeRoles,
    requiredRole: getCoverageRoleForEmployeeRole(requiredEmployeeRoles[0]),
    status: "draft"
  };
}

function requirement(role: EmployeeRole, count: number): RoleRequirement {
  return { role, count };
}

export const departments: Department[] = [
  {
    id: "diy",
    name: "DIY",
    payBudget: 8600,
    payPeriodLengthDays: 14,
    budgetChargeMode: "primary_department",
    openHours: [
      { id: "diy-sun", dayOfWeek: 0, openTime: "06:45", closeTime: "12:15" },
      { id: "diy-mon", dayOfWeek: 1, openTime: "05:45", closeTime: "12:15" },
      { id: "diy-tue", dayOfWeek: 2, openTime: "05:45", closeTime: "12:15" },
      { id: "diy-wed", dayOfWeek: 3, openTime: "05:45", closeTime: "12:15" },
      { id: "diy-thu", dayOfWeek: 4, openTime: "05:45", closeTime: "12:15" },
      { id: "diy-fri", dayOfWeek: 5, openTime: "05:45", closeTime: "12:15" },
      { id: "diy-sat", dayOfWeek: 6, openTime: "05:45", closeTime: "12:15" }
    ],
    coverageRules: [
      {
        id: "diy-sun-open",
        dayOfWeek: 0,
        startTime: "06:45",
        endTime: "12:15",
        requiredRoles: [requirement("red_shirt", 1)],
        alternativeRoleSets: [
          [requirement("store_manager", 1)],
          [requirement("assistant_store_manager", 1)]
        ]
      },
      ...[1, 2, 3, 4, 5, 6].map((dayOfWeek) => ({
        id: `diy-open-${dayOfWeek}`,
        dayOfWeek,
        startTime: "05:45",
        endTime: "12:15",
        requiredRoles: [requirement("red_shirt", 1)],
        alternativeRoleSets: [
          [requirement("store_manager", 1)],
          [requirement("assistant_store_manager", 1)]
        ]
      }))
    ]
  },
  {
    id: "commercial",
    name: "Commercial",
    payBudget: 9200,
    payPeriodLengthDays: 14,
    budgetChargeMode: "primary_department",
    openHours: [
      { id: "commercial-mon", dayOfWeek: 1, openTime: "07:30", closeTime: "18:00" },
      { id: "commercial-tue", dayOfWeek: 2, openTime: "07:30", closeTime: "18:00" },
      { id: "commercial-wed", dayOfWeek: 3, openTime: "07:30", closeTime: "18:00" },
      { id: "commercial-thu", dayOfWeek: 4, openTime: "07:30", closeTime: "18:00" },
      { id: "commercial-fri", dayOfWeek: 5, openTime: "07:30", closeTime: "18:00" },
      { id: "commercial-sat", dayOfWeek: 6, openTime: "07:30", closeTime: "18:00" }
    ],
    coverageRules: [
      {
        id: "commercial-open-all-day",
        dayOfWeek: null,
        startTime: "07:30",
        endTime: "18:00",
        requiredRoles: [requirement("commercial_driver", 5)],
        alternativeRoleSets: [
          [
            requirement("commercial_sales_manager", 1),
            requirement("commercial_manager", 1)
          ],
          [requirement("commercial_manager", 2)]
        ]
      }
    ]
  },
  {
    id: "hub",
    name: "Hub",
    payBudget: 5600,
    payPeriodLengthDays: 14,
    budgetChargeMode: "primary_department",
    openHours: [
      { id: "hub-sun", dayOfWeek: 0, openTime: "05:00", closeTime: "22:00" },
      { id: "hub-mon", dayOfWeek: 1, openTime: "05:00", closeTime: "22:00" },
      { id: "hub-tue", dayOfWeek: 2, openTime: "05:00", closeTime: "22:00" },
      { id: "hub-wed", dayOfWeek: 3, openTime: "05:00", closeTime: "22:00" },
      { id: "hub-thu", dayOfWeek: 4, openTime: "05:00", closeTime: "22:00" },
      { id: "hub-fri", dayOfWeek: 5, openTime: "05:00", closeTime: "22:00" },
      { id: "hub-sat", dayOfWeek: 6, openTime: "05:00", closeTime: "22:00" }
    ],
    coverageRules: [
      {
        id: "hub-open-all-day",
        dayOfWeek: null,
        startTime: "05:00",
        endTime: "22:00",
        requiredRoles: [
          requirement("picker", 1),
          requirement("hub_driver", 6)
        ],
        alternativeRoleSets: [
          [requirement("hub_coordinator", 1)],
          [requirement("hub_specialist", 1)]
        ]
      }
    ]
  }
];

export const employees: Employee[] = [
  {
    id: "emp-dm-1",
    name: "Alicia Reyes",
    role: "store_manager",
    primaryDepartmentId: "diy",
    crossTrainedDepartmentIds: [],
    employmentType: "full_time",
    hourlyRate: 34,
    weeklyHourCap: 42,
    weeklyHourFloor: 38,
    availability: fullWeekAvailability("emp-dm-1", "05:30", "12:30"),
    dayRestrictions: [],
    timeRestriction: { employeeId: "emp-dm-1", earliestStart: "05:30", latestEnd: "12:30" }
  },
  {
    id: "emp-dm-2",
    name: "Marcus Bell",
    role: "assistant_store_manager",
    primaryDepartmentId: "diy",
    crossTrainedDepartmentIds: [],
    employmentType: "full_time",
    hourlyRate: 32,
    weeklyHourCap: 40,
    weeklyHourFloor: 36,
    availability: fullWeekAvailability("emp-dm-2", "05:30", "12:30"),
    dayRestrictions: [{ employeeId: "emp-dm-2", dayOfWeek: 0, reason: "Protected day off" }],
    timeRestriction: { employeeId: "emp-dm-2", earliestStart: "05:30", latestEnd: "12:30" }
  },
  {
    id: "emp-ds-1",
    name: "Nina Park",
    role: "gray_shirt",
    primaryDepartmentId: "diy",
    crossTrainedDepartmentIds: [],
    employmentType: "full_time",
    hourlyRate: 22,
    weeklyHourCap: 40,
    weeklyHourFloor: 35,
    availability: fullWeekAvailability("emp-ds-1", "05:45", "12:15"),
    dayRestrictions: [],
    timeRestriction: { employeeId: "emp-ds-1", earliestStart: "05:45", latestEnd: "12:15" }
  },
  {
    id: "emp-ds-2",
    name: "Devin Ortiz",
    role: "red_shirt",
    primaryDepartmentId: "diy",
    crossTrainedDepartmentIds: [],
    employmentType: "part_time",
    hourlyRate: 20,
    weeklyHourCap: 28,
    weeklyHourFloor: 0,
    availability: fullWeekAvailability("emp-ds-2", "05:45", "12:15"),
    dayRestrictions: [{ employeeId: "emp-ds-2", dayOfWeek: 3, reason: "Trade school" }],
    timeRestriction: { employeeId: "emp-ds-2", earliestStart: "05:45", latestEnd: "12:15" }
  },
  {
    id: "emp-ds-3",
    name: "Priya Shah",
    role: "red_shirt",
    primaryDepartmentId: "diy",
    crossTrainedDepartmentIds: ["hub"],
    employmentType: "part_time",
    hourlyRate: 21,
    weeklyHourCap: 26,
    weeklyHourFloor: 0,
    availability: fullWeekAvailability("emp-ds-3", "05:45", "12:15"),
    dayRestrictions: [{ employeeId: "emp-ds-3", dayOfWeek: 6, reason: "Caregiving" }],
    timeRestriction: { employeeId: "emp-ds-3", earliestStart: "05:45", latestEnd: "12:15" }
  },
  {
    id: "emp-ds-4",
    name: "Leo Carter",
    role: "gray_shirt",
    primaryDepartmentId: "diy",
    crossTrainedDepartmentIds: [],
    employmentType: "part_time",
    hourlyRate: 19,
    weeklyHourCap: 24,
    weeklyHourFloor: 0,
    availability: fullWeekAvailability("emp-ds-4", "06:45", "12:15"),
    dayRestrictions: [{ employeeId: "emp-ds-4", dayOfWeek: 2, reason: "Morning classes" }],
    timeRestriction: { employeeId: "emp-ds-4", earliestStart: "06:45", latestEnd: "12:15" }
  },
  {
    id: "emp-cm-1",
    name: "Tessa Wong",
    role: "commercial_sales_manager",
    primaryDepartmentId: "commercial",
    crossTrainedDepartmentIds: [],
    employmentType: "full_time",
    hourlyRate: 31,
    weeklyHourCap: 40,
    weeklyHourFloor: 36,
    availability: fullWeekAvailability("emp-cm-1", "07:30", "18:00", true),
    dayRestrictions: [],
    timeRestriction: { employeeId: "emp-cm-1", earliestStart: "07:30", latestEnd: "18:00" }
  },
  {
    id: "emp-cm-2",
    name: "Owen Brooks",
    role: "commercial_manager",
    primaryDepartmentId: "commercial",
    crossTrainedDepartmentIds: [],
    employmentType: "full_time",
    hourlyRate: 27,
    weeklyHourCap: 38,
    weeklyHourFloor: 32,
    availability: fullWeekAvailability("emp-cm-2", "07:30", "18:00", true),
    dayRestrictions: [],
    timeRestriction: { employeeId: "emp-cm-2", earliestStart: "07:30", latestEnd: "18:00" }
  },
  {
    id: "emp-cm-3",
    name: "Lena Hart",
    role: "commercial_manager",
    primaryDepartmentId: "commercial",
    crossTrainedDepartmentIds: [],
    employmentType: "full_time",
    hourlyRate: 28,
    weeklyHourCap: 40,
    weeklyHourFloor: 32,
    availability: fullWeekAvailability("emp-cm-3", "07:30", "18:00", true),
    dayRestrictions: [],
    timeRestriction: { employeeId: "emp-cm-3", earliestStart: "07:30", latestEnd: "18:00" }
  },
  {
    id: "emp-cd-1",
    name: "Maya Chen",
    role: "commercial_driver",
    primaryDepartmentId: "commercial",
    crossTrainedDepartmentIds: [],
    employmentType: "part_time",
    hourlyRate: 18,
    weeklyHourCap: 26,
    weeklyHourFloor: 0,
    availability: fullWeekAvailability("emp-cd-1", "07:30", "18:00", true),
    dayRestrictions: [{ employeeId: "emp-cd-1", dayOfWeek: 5, reason: "Volunteer shift" }],
    timeRestriction: { employeeId: "emp-cd-1", earliestStart: "07:30", latestEnd: "18:00" }
  },
  {
    id: "emp-cd-2",
    name: "Noah Diaz",
    role: "commercial_driver",
    primaryDepartmentId: "commercial",
    crossTrainedDepartmentIds: ["hub"],
    employmentType: "part_time",
    hourlyRate: 18,
    weeklyHourCap: 24,
    weeklyHourFloor: 0,
    availability: fullWeekAvailability("emp-cd-2", "07:30", "18:00", true),
    dayRestrictions: [{ employeeId: "emp-cd-2", dayOfWeek: 0, reason: "Family commitment" }],
    timeRestriction: { employeeId: "emp-cd-2", earliestStart: "07:30", latestEnd: "18:00" }
  },
  {
    id: "emp-cd-3",
    name: "Rina Gomez",
    role: "commercial_driver",
    primaryDepartmentId: "commercial",
    crossTrainedDepartmentIds: [],
    employmentType: "part_time",
    hourlyRate: 18,
    weeklyHourCap: 24,
    weeklyHourFloor: 0,
    availability: fullWeekAvailability("emp-cd-3", "07:30", "18:00", true),
    dayRestrictions: [],
    timeRestriction: { employeeId: "emp-cd-3", earliestStart: "07:30", latestEnd: "18:00" }
  },
  {
    id: "emp-cd-4",
    name: "Jonah Price",
    role: "commercial_driver",
    primaryDepartmentId: "commercial",
    crossTrainedDepartmentIds: [],
    employmentType: "part_time",
    hourlyRate: 19,
    weeklyHourCap: 30,
    weeklyHourFloor: 0,
    availability: fullWeekAvailability("emp-cd-4", "07:30", "18:00", true),
    dayRestrictions: [],
    timeRestriction: { employeeId: "emp-cd-4", earliestStart: "07:30", latestEnd: "18:00" }
  },
  {
    id: "emp-cd-5",
    name: "Iris Flynn",
    role: "commercial_driver",
    primaryDepartmentId: "commercial",
    crossTrainedDepartmentIds: [],
    employmentType: "part_time",
    hourlyRate: 19,
    weeklyHourCap: 30,
    weeklyHourFloor: 0,
    availability: fullWeekAvailability("emp-cd-5", "07:30", "18:00", true),
    dayRestrictions: [],
    timeRestriction: { employeeId: "emp-cd-5", earliestStart: "07:30", latestEnd: "18:00" }
  },
  {
    id: "emp-hm-1",
    name: "Harper Cole",
    role: "hub_coordinator",
    primaryDepartmentId: "hub",
    crossTrainedDepartmentIds: [],
    employmentType: "full_time",
    hourlyRate: 36,
    weeklyHourCap: 40,
    weeklyHourFloor: 37,
    availability: fullWeekAvailability("emp-hm-1", "05:00", "22:00"),
    dayRestrictions: [],
    timeRestriction: { employeeId: "emp-hm-1", earliestStart: "05:00", latestEnd: "22:00" }
  },
  {
    id: "emp-hs-1",
    name: "Rory Kim",
    role: "hub_specialist",
    primaryDepartmentId: "hub",
    crossTrainedDepartmentIds: [],
    employmentType: "full_time",
    hourlyRate: 24,
    weeklyHourCap: 40,
    weeklyHourFloor: 34,
    availability: fullWeekAvailability("emp-hs-1", "05:00", "22:00"),
    dayRestrictions: [],
    timeRestriction: { employeeId: "emp-hs-1", earliestStart: "05:00", latestEnd: "22:00" }
  },
  {
    id: "emp-hs-2",
    name: "Emma Torres",
    role: "picker",
    primaryDepartmentId: "hub",
    crossTrainedDepartmentIds: ["diy"],
    employmentType: "part_time",
    hourlyRate: 23,
    weeklyHourCap: 20,
    weeklyHourFloor: 0,
    availability: fullWeekAvailability("emp-hs-2", "05:00", "22:00"),
    dayRestrictions: [{ employeeId: "emp-hs-2", dayOfWeek: 2, reason: "Internship" }],
    timeRestriction: { employeeId: "emp-hs-2", earliestStart: "05:00", latestEnd: "22:00" }
  },
  {
    id: "emp-hd-1",
    name: "Casey Morgan",
    role: "hub_driver",
    primaryDepartmentId: "hub",
    crossTrainedDepartmentIds: ["diy", "commercial"],
    employmentType: "part_time",
    hourlyRate: 20,
    weeklyHourCap: 30,
    weeklyHourFloor: 0,
    availability: fullWeekAvailability("emp-hd-1", "05:00", "22:00"),
    dayRestrictions: [{ employeeId: "emp-hd-1", dayOfWeek: 4, reason: "Campus clinic" }],
    timeRestriction: { employeeId: "emp-hd-1", earliestStart: "05:00", latestEnd: "22:00" }
  },
  {
    id: "emp-hd-2",
    name: "Andre Moss",
    role: "hub_driver",
    primaryDepartmentId: "hub",
    crossTrainedDepartmentIds: [],
    employmentType: "part_time",
    hourlyRate: 20,
    weeklyHourCap: 30,
    weeklyHourFloor: 0,
    availability: fullWeekAvailability("emp-hd-2", "05:00", "22:00"),
    dayRestrictions: [],
    timeRestriction: { employeeId: "emp-hd-2", earliestStart: "05:00", latestEnd: "22:00" }
  },
  {
    id: "emp-hd-3",
    name: "Sara Lin",
    role: "hub_driver",
    primaryDepartmentId: "hub",
    crossTrainedDepartmentIds: [],
    employmentType: "part_time",
    hourlyRate: 20,
    weeklyHourCap: 28,
    weeklyHourFloor: 0,
    availability: fullWeekAvailability("emp-hd-3", "05:00", "22:00"),
    dayRestrictions: [],
    timeRestriction: { employeeId: "emp-hd-3", earliestStart: "05:00", latestEnd: "22:00" }
  },
  {
    id: "emp-hd-4",
    name: "Mila Voss",
    role: "hub_driver",
    primaryDepartmentId: "hub",
    crossTrainedDepartmentIds: [],
    employmentType: "part_time",
    hourlyRate: 20,
    weeklyHourCap: 28,
    weeklyHourFloor: 0,
    availability: fullWeekAvailability("emp-hd-4", "05:00", "22:00"),
    dayRestrictions: [],
    timeRestriction: { employeeId: "emp-hd-4", earliestStart: "05:00", latestEnd: "22:00" }
  },
  {
    id: "emp-hd-5",
    name: "Theo Grant",
    role: "hub_driver",
    primaryDepartmentId: "hub",
    crossTrainedDepartmentIds: [],
    employmentType: "part_time",
    hourlyRate: 21,
    weeklyHourCap: 30,
    weeklyHourFloor: 0,
    availability: fullWeekAvailability("emp-hd-5", "05:00", "22:00"),
    dayRestrictions: [],
    timeRestriction: { employeeId: "emp-hd-5", earliestStart: "05:00", latestEnd: "22:00" }
  },
  {
    id: "emp-hd-6",
    name: "Jules Ortega",
    role: "hub_driver",
    primaryDepartmentId: "hub",
    crossTrainedDepartmentIds: [],
    employmentType: "part_time",
    hourlyRate: 21,
    weeklyHourCap: 30,
    weeklyHourFloor: 0,
    availability: fullWeekAvailability("emp-hd-6", "05:00", "22:00"),
    dayRestrictions: [],
    timeRestriction: { employeeId: "emp-hd-6", earliestStart: "05:00", latestEnd: "22:00" }
  }
];

export const shifts: Shift[] = [
  makeShift("shift-1", "emp-dm-1", "diy", dateAt(0, 6, 45), dateAt(0, 12, 15), ["store_manager", "assistant_store_manager"]),
  makeShift("shift-2", "emp-ds-2", "diy", dateAt(0, 6, 45), dateAt(0, 12, 15), ["red_shirt"]),
  makeShift("shift-3", null, "diy", dateAt(1, 5, 45), dateAt(1, 12, 15), ["store_manager", "assistant_store_manager"]),
  makeShift("shift-4", "emp-ds-3", "diy", dateAt(1, 5, 45), dateAt(1, 12, 15), ["red_shirt"]),
  makeShift("shift-5", "emp-cm-1", "commercial", dateAt(0, 7, 30), dateAt(0, 18, 0), ["commercial_sales_manager", "commercial_manager"]),
  makeShift("shift-6", "emp-cm-2", "commercial", dateAt(0, 7, 30), dateAt(0, 18, 0), ["commercial_manager"]),
  makeShift("shift-7", "emp-cd-1", "commercial", dateAt(0, 7, 30), dateAt(0, 18, 0), ["commercial_driver"]),
  makeShift("shift-8", "emp-cd-2", "commercial", dateAt(0, 7, 30), dateAt(0, 18, 0), ["commercial_driver"]),
  makeShift("shift-9", null, "commercial", dateAt(0, 7, 30), dateAt(0, 18, 0), ["commercial_driver"]),
  makeShift("shift-10", null, "commercial", dateAt(0, 7, 30), dateAt(0, 18, 0), ["commercial_driver"]),
  makeShift("shift-11", null, "commercial", dateAt(0, 7, 30), dateAt(0, 18, 0), ["commercial_driver"]),
  makeShift("shift-12", "emp-hm-1", "hub", dateAt(0, 5, 0), dateAt(0, 22, 0), ["hub_coordinator", "hub_specialist"]),
  makeShift("shift-13", "emp-hs-2", "hub", dateAt(0, 5, 0), dateAt(0, 22, 0), ["picker"]),
  makeShift("shift-14", "emp-hd-1", "hub", dateAt(0, 5, 0), dateAt(0, 22, 0), ["hub_driver"]),
  makeShift("shift-15", "emp-hd-2", "hub", dateAt(0, 5, 0), dateAt(0, 22, 0), ["hub_driver"]),
  makeShift("shift-16", "emp-hd-3", "hub", dateAt(0, 5, 0), dateAt(0, 22, 0), ["hub_driver"]),
  makeShift("shift-17", null, "hub", dateAt(0, 5, 0), dateAt(0, 22, 0), ["hub_driver"]),
  makeShift("shift-18", null, "hub", dateAt(0, 5, 0), dateAt(0, 22, 0), ["hub_driver"]),
  makeShift("shift-19", null, "hub", dateAt(0, 5, 0), dateAt(0, 22, 0), ["hub_driver"])
];

export const seedDataset = { departments, employees, shifts };
