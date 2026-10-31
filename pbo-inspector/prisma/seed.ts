import { PrismaClient } from "@prisma/client";

import { seedDataset } from "@/lib/data/seed";

const prisma = new PrismaClient();

async function main() {
  await prisma.shift.deleteMany();
  await prisma.timeRestriction.deleteMany();
  await prisma.dayRestriction.deleteMany();
  await prisma.availability.deleteMany();
  await prisma.alternativeRoleRequirement.deleteMany();
  await prisma.coverageAlternative.deleteMany();
  await prisma.coverageRequirement.deleteMany();
  await prisma.coverageRule.deleteMany();
  await prisma.openHoursRule.deleteMany();
  await prisma.employee.deleteMany();
  await prisma.department.deleteMany();

  for (const department of seedDataset.departments) {
    await prisma.department.create({
      data: {
        id: department.id,
        name: department.name,
        payBudget: department.payBudget,
        payPeriodLengthDays: department.payPeriodLengthDays,
        budgetChargeMode: department.budgetChargeMode,
        openHours: {
          create: department.openHours.map((openHours) => ({
            id: openHours.id,
            dayOfWeek: openHours.dayOfWeek,
            openTime: openHours.openTime,
            closeTime: openHours.closeTime
          }))
        },
        coverageRules: {
          create: department.coverageRules.map((rule) => ({
            id: rule.id,
            dayOfWeek: rule.dayOfWeek,
            startTime: rule.startTime,
            endTime: rule.endTime,
            requiredRoles: {
              create: rule.requiredRoles.map((requirement, index) => ({
                id: `${rule.id}-required-${index}`,
                role: requirement.role,
                count: requirement.count
              }))
            },
            alternativeRoleSets: {
              create: rule.alternativeRoleSets.map((alternative, alternativeIndex) => ({
                id: `${rule.id}-alt-${alternativeIndex}`,
                requirements: {
                  create: alternative.map((requirement, requirementIndex) => ({
                    id: `${rule.id}-alt-${alternativeIndex}-req-${requirementIndex}`,
                    role: requirement.role,
                    count: requirement.count
                  }))
                }
              }))
            }
          }))
        }
      }
    });
  }

  for (const employee of seedDataset.employees) {
    await prisma.employee.create({
      data: {
        id: employee.id,
        name: employee.name,
        role: employee.role,
        primaryDepartmentId: employee.primaryDepartmentId,
        crossTrainedDepartmentIds: employee.crossTrainedDepartmentIds,
        employmentType: employee.employmentType,
        hourlyRate: employee.hourlyRate,
        weeklyHourCap: employee.weeklyHourCap,
        weeklyHourFloor: employee.weeklyHourFloor,
        availability: {
          create: employee.availability.map((window, index) => ({
            id: `${employee.id}-availability-${index}`,
            dayOfWeek: window.dayOfWeek,
            startTime: window.startTime,
            endTime: window.endTime
          }))
        },
        dayRestrictions: {
          create: employee.dayRestrictions.map((restriction, index) => ({
            id: `${employee.id}-day-restriction-${index}`,
            dayOfWeek: restriction.dayOfWeek,
            reason: restriction.reason
          }))
        },
        timeRestriction: employee.timeRestriction
          ? {
              create: {
                id: `${employee.id}-time-restriction`,
                earliestStart: employee.timeRestriction.earliestStart,
                latestEnd: employee.timeRestriction.latestEnd
              }
            }
          : undefined
      }
    });
  }

  for (const shift of seedDataset.shifts) {
    await prisma.shift.create({
      data: {
        id: shift.id,
        employeeId: shift.employeeId,
        departmentId: shift.departmentId,
        start: new Date(shift.start),
        end: new Date(shift.end),
        requiredRole: shift.requiredRole,
        requiredEmployeeRoles: shift.requiredEmployeeRoles,
        status: shift.status
      }
    });
  }
}

main()
  .then(async () => {
    await prisma.$disconnect();
  })
  .catch(async (error) => {
    console.error(error);
    await prisma.$disconnect();
    process.exit(1);
  });
