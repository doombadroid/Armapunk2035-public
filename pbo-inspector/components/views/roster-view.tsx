"use client";

import {
  flexRender,
  getCoreRowModel,
  getFilteredRowModel,
  getSortedRowModel,
  useReactTable,
  type SortingState,
  type ColumnDef,
} from "@tanstack/react-table";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { Download } from "lucide-react";
import { useEffect, useMemo, useState } from "react";

import { fetchJson } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Chip } from "@/components/ui/chip";
import { getWeeklyHoursForEmployee } from "@/lib/data/metrics";
import { schedulerKeys } from "@/lib/query/keys";
import { formatEmployeeRole } from "@/lib/roles";
import type { DayRestriction, Employee } from "@/lib/schemas";
import type { SchedulerDataset } from "@/lib/types";

type Row = Employee & {
  scheduledHours: number;
  utilization: number;
};

const days = [
  { value: 0, label: "Sun" },
  { value: 1, label: "Mon" },
  { value: 2, label: "Tue" },
  { value: 3, label: "Wed" },
  { value: 4, label: "Thu" },
  { value: 5, label: "Fri" },
  { value: 6, label: "Sat" }
];

function RestrictionEditor({
  employee,
  onClose,
  onSave
}: {
  employee: Employee;
  onClose: () => void;
  onSave: (payload: Pick<Employee, "availability" | "dayRestrictions" | "timeRestriction">) => void;
}) {
  const [blockedDays, setBlockedDays] = useState<number[]>(employee.dayRestrictions.map((entry) => entry.dayOfWeek));
  const [earliestStart, setEarliestStart] = useState(employee.timeRestriction?.earliestStart ?? "05:00");
  const [latestEnd, setLatestEnd] = useState(employee.timeRestriction?.latestEnd ?? "22:00");

  useEffect(() => {
    setBlockedDays(employee.dayRestrictions.map((entry) => entry.dayOfWeek));
    setEarliestStart(employee.timeRestriction?.earliestStart ?? "05:00");
    setLatestEnd(employee.timeRestriction?.latestEnd ?? "22:00");
  }, [employee]);

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/35 px-4">
      <div className="w-full max-w-xl rounded-3xl bg-white p-6 shadow-panel">
        <div className="flex items-center justify-between">
          <div>
            <p className="font-display text-2xl">{employee.name}</p>
            <p className="text-sm text-ink/60">Update blocked days and allowed clock-in window</p>
          </div>
          <Button variant="ghost" onClick={onClose}>Close</Button>
        </div>

        <div className="mt-6">
          <p className="text-xs uppercase tracking-[0.25em] text-ink/45">Blocked Days</p>
          <div className="mt-3 flex flex-wrap gap-2">
            {days.map((day) => {
              const active = blockedDays.includes(day.value);
              return (
                <button
                  key={day.value}
                  className={`rounded-full px-3 py-2 text-sm ${active ? "bg-rose-600 text-white" : "bg-sand text-ink"}`}
                  onClick={() =>
                    setBlockedDays((current) =>
                      current.includes(day.value)
                        ? current.filter((value) => value !== day.value)
                        : [...current, day.value].sort(),
                    )
                  }
                >
                  {day.label}
                </button>
              );
            })}
          </div>
        </div>

        <div className="mt-6 grid gap-4 md:grid-cols-2">
          <label className="text-sm">
            <span className="mb-2 block text-xs uppercase tracking-[0.25em] text-ink/45">Earliest Start</span>
            <input
              type="time"
              value={earliestStart}
              onChange={(event) => setEarliestStart(event.target.value)}
              className="w-full rounded-2xl border border-black/10 px-3 py-2"
            />
          </label>
          <label className="text-sm">
            <span className="mb-2 block text-xs uppercase tracking-[0.25em] text-ink/45">Latest End</span>
            <input
              type="time"
              value={latestEnd}
              onChange={(event) => setLatestEnd(event.target.value)}
              className="w-full rounded-2xl border border-black/10 px-3 py-2"
            />
          </label>
        </div>

        <div className="mt-6 flex justify-end gap-3">
          <Button variant="secondary" onClick={onClose}>Cancel</Button>
          <Button
            onClick={() =>
              onSave({
                availability: employee.availability,
                dayRestrictions: blockedDays.map<DayRestriction>((dayOfWeek) => ({
                  employeeId: employee.id,
                  dayOfWeek,
                  reason: "Blocked in scheduler"
                })),
                timeRestriction: {
                  employeeId: employee.id,
                  earliestStart,
                  latestEnd
                }
              })
            }
          >
            Save Restrictions
          </Button>
        </div>
      </div>
    </div>
  );
}

export function RosterView({
  dataset,
  anchorDate
}: {
  dataset: SchedulerDataset;
  anchorDate: Date;
}) {
  const [globalFilter, setGlobalFilter] = useState("");
  const [sorting, setSorting] = useState<SortingState>([]);
  const [editingEmployee, setEditingEmployee] = useState<Employee | null>(null);
  const queryClient = useQueryClient();

  const rows = useMemo<Row[]>(
    () =>
      dataset.employees.map((employee) => {
        const scheduledHours = getWeeklyHoursForEmployee(employee.id, dataset.shifts, anchorDate);
        return {
          ...employee,
          scheduledHours,
          utilization: (scheduledHours / employee.weeklyHourCap) * 100
        };
      }),
    [dataset, anchorDate],
  );
  const departmentNameMap = useMemo(
    () => new Map(dataset.departments.map((department) => [department.id, department.name])),
    [dataset.departments],
  );

  const restrictionsMutation = useMutation({
    mutationFn: async ({
      employeeId,
      payload
    }: {
      employeeId: string;
      payload: Pick<Employee, "availability" | "dayRestrictions" | "timeRestriction">;
    }) =>
      fetchJson(`/api/employees/${employeeId}/restrictions`, {
        method: "PATCH",
        body: JSON.stringify(payload)
      }),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: schedulerKeys.root });
      setEditingEmployee(null);
    }
  });

  const columns = useMemo<ColumnDef<Row>[]>(
    () => [
      {
        accessorKey: "name",
        header: "Employee"
      },
      {
        accessorKey: "employmentType",
        header: "Employment"
      },
      {
        accessorKey: "primaryDepartmentId",
        header: "Department",
        cell: ({ row }) => departmentNameMap.get(row.original.primaryDepartmentId) ?? row.original.primaryDepartmentId
      },
      {
        accessorKey: "role",
        header: "Role",
        cell: ({ row }) => formatEmployeeRole(row.original.role)
      },
      {
        id: "restrictions",
        header: "Restrictions",
        cell: ({ row }) => (
          <div className="flex flex-wrap gap-2">
            {row.original.dayRestrictions.length ? <Chip tone="amber">{row.original.dayRestrictions.length} day</Chip> : null}
            {row.original.timeRestriction ? <Chip tone="red">{row.original.timeRestriction.earliestStart}-{row.original.timeRestriction.latestEnd}</Chip> : null}
            {!row.original.dayRestrictions.length && !row.original.timeRestriction ? <Chip>clear</Chip> : null}
          </div>
        )
      },
      {
        id: "actions",
        header: "Edit",
        cell: ({ row }) => (
          <Button variant="secondary" onClick={() => setEditingEmployee(row.original)}>
            Restrictions
          </Button>
        )
      },
      {
        accessorKey: "scheduledHours",
        header: "Weekly Hours",
        cell: ({ getValue }) => `${Number(getValue()).toFixed(1)}h`
      },
      {
        accessorKey: "weeklyHourCap",
        header: "Cap",
        cell: ({ getValue }) => `${getValue<number>()}h`
      },
      {
        accessorKey: "utilization",
        header: "Utilization",
        cell: ({ getValue }) => `${Number(getValue()).toFixed(0)}%`
      }
    ],
    [departmentNameMap],
  );

  const table = useReactTable({
    data: rows,
    columns,
    state: {
      globalFilter,
      sorting
    },
    onGlobalFilterChange: setGlobalFilter,
    onSortingChange: setSorting,
    getCoreRowModel: getCoreRowModel(),
    getFilteredRowModel: getFilteredRowModel(),
    getSortedRowModel: getSortedRowModel()
  });

  function exportCsv() {
    const header = ["name", "employmentType", "primaryDepartmentId", "role", "scheduledHours", "weeklyHourCap", "utilization"];
    const lines = rows.map((row) =>
      [
        row.name,
        row.employmentType,
        departmentNameMap.get(row.primaryDepartmentId) ?? row.primaryDepartmentId,
        formatEmployeeRole(row.role),
        row.scheduledHours.toFixed(1),
        row.weeklyHourCap,
        row.utilization.toFixed(0)
      ].join(","),
    );
    const blob = new Blob([[header.join(","), ...lines].join("\n")], { type: "text/csv;charset=utf-8" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = "roster-export.csv";
    link.click();
    URL.revokeObjectURL(url);
  }

  return (
    <>
      <Card className="overflow-hidden">
        <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
          <div>
            <p className="font-display text-2xl">Roster</p>
            <p className="text-sm text-ink/60">Filter, sort, export, and edit employee restrictions.</p>
          </div>
          <div className="flex gap-3">
            <input
              value={globalFilter}
              onChange={(event) => setGlobalFilter(event.target.value)}
              placeholder="Search employees"
              className="rounded-full border border-black/10 bg-white px-4 py-2 text-sm outline-none"
            />
            <Button variant="secondary" onClick={exportCsv}>
              <Download className="mr-2 h-4 w-4" />
              Export
            </Button>
          </div>
        </div>

        <div className="mt-6 overflow-auto">
          <table className="min-w-full border-separate border-spacing-y-2">
            <thead>
              {table.getHeaderGroups().map((headerGroup) => (
                <tr key={headerGroup.id}>
                  {headerGroup.headers.map((header) => (
                    <th
                      key={header.id}
                      className="px-3 py-2 text-left text-xs font-semibold uppercase tracking-[0.25em] text-ink/45"
                    >
                      {header.isPlaceholder ? null : (
                        <button
                          className="transition hover:text-ink"
                          onClick={header.column.getToggleSortingHandler()}
                        >
                          {flexRender(header.column.columnDef.header, header.getContext())}
                        </button>
                      )}
                    </th>
                  ))}
                </tr>
              ))}
            </thead>
            <tbody>
              {table.getRowModel().rows.map((row) => (
                <tr key={row.id} className="rounded-2xl bg-sand/30">
                  {row.getVisibleCells().map((cell) => (
                    <td key={cell.id} className="px-3 py-3 text-sm first:rounded-l-2xl last:rounded-r-2xl">
                      {cell.column.columnDef.cell
                        ? flexRender(cell.column.columnDef.cell, cell.getContext())
                        : String(cell.getValue() ?? "")}
                    </td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Card>

      {editingEmployee ? (
        <RestrictionEditor
          employee={editingEmployee}
          onClose={() => setEditingEmployee(null)}
          onSave={(payload) =>
            restrictionsMutation.mutate({
              employeeId: editingEmployee.id,
              payload
            })
          }
        />
      ) : null}
    </>
  );
}
