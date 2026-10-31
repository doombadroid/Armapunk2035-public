"use client";

import {
  DndContext,
  DragEndEvent,
  DragMoveEvent,
  DragOverlay,
  DragStartEvent,
  PointerSensor,
  useDraggable,
  useDroppable,
  useSensor,
  useSensors,
} from "@dnd-kit/core";
import {
  addDays,
  differenceInMinutes,
  eachDayOfInterval,
  endOfMonth,
  format,
  setHours,
  setMinutes,
  startOfMonth,
} from "date-fns";
import { AlertTriangle, Clock3, RotateCcw } from "lucide-react";
import { useMemo, useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";

import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Chip } from "@/components/ui/chip";
import { fetchJson } from "@/lib/api";
import { validateShiftAssignment } from "@/lib/conflict-engine";
import { schedulerKeys } from "@/lib/query/keys";
import { formatEmployeeRole, isManagerRole } from "@/lib/roles";
import type { Employee, Shift, ValidationResult } from "@/lib/schemas";
import type { SchedulerDataset } from "@/lib/types";
import { groupBy } from "@/lib/utils";

type UndoAction = {
  shiftId: string;
  previous: Shift;
};

type DropPreview = {
  employeeId: string;
  dateKey: string;
  shift: Shift;
  result: ValidationResult;
};

const CALENDAR_START_HOUR = 5;
const CALENDAR_END_HOUR = 22;
const UNDO_STACK_LIMIT = 8;

function getVisibleDays(range: { start: Date; end: Date }, mode: "week" | "two-week" | "month") {
  if (mode === "month") {
    return eachDayOfInterval({
      start: startOfMonth(range.start),
      end: endOfMonth(range.start)
    });
  }

  return eachDayOfInterval(range);
}

function shiftDurationMinutes(shift: Shift) {
  return differenceInMinutes(new Date(shift.end), new Date(shift.start));
}

function buildShiftFromDrop(day: Date, shift: Shift, employeeId: string, ratio: number) {
  const durationMinutes = shiftDurationMinutes(shift);
  const dayStart = setMinutes(setHours(new Date(day), CALENDAR_START_HOUR), 0);
  const daySpanMinutes = (CALENDAR_END_HOUR - CALENDAR_START_HOUR) * 60;
  const startOffset = Math.round(Math.max(0, Math.min(1, ratio)) * Math.max(0, daySpanMinutes - durationMinutes));
  const start = addDays(dayStart, 0);
  start.setMinutes(start.getMinutes() + startOffset);
  const end = new Date(start);
  end.setMinutes(end.getMinutes() + durationMinutes);

  return {
    ...shift,
    employeeId,
    start: start.toISOString(),
    end: end.toISOString()
  };
}

function ShiftChip({
  shift,
  employeeName,
  conflictState = "neutral"
}: {
  shift: Shift;
  employeeName?: string;
  conflictState?: "neutral" | "valid" | "invalid";
}) {
  const { attributes, listeners, setNodeRef, isDragging } = useDraggable({
    id: shift.id,
    data: { type: "shift", shift }
  });

  return (
    <button
      ref={setNodeRef}
      {...attributes}
      {...listeners}
      className={`absolute top-2 h-16 rounded-2xl border px-3 py-2 text-left text-xs shadow-sm transition ${
        conflictState === "invalid"
          ? "border-rose-300 bg-rose-100 text-rose-900"
          : conflictState === "valid"
            ? "border-emerald-300 bg-emerald-100 text-emerald-900"
            : "border-moss/25 bg-moss/10 text-ink"
      } ${isDragging ? "opacity-40" : "opacity-100"}`}
      style={{
        left: `${((new Date(shift.start).getHours() + new Date(shift.start).getMinutes() / 60 - CALENDAR_START_HOUR) / (CALENDAR_END_HOUR - CALENDAR_START_HOUR)) * 100}%`,
        width: `${(shiftDurationMinutes(shift) / ((CALENDAR_END_HOUR - CALENDAR_START_HOUR) * 60)) * 100}%`
      }}
    >
      <div className="font-semibold">{employeeName ?? "Unassigned"}</div>
      <div className="mt-1 text-[11px]">
        {format(new Date(shift.start), "HH:mm")} - {format(new Date(shift.end), "HH:mm")}
      </div>
      <div className="mt-1 text-[10px]">
        {shift.requiredEmployeeRoles.map((role) => formatEmployeeRole(role)).join(" / ")}
      </div>
    </button>
  );
}

function CalendarDropCell({
  employee,
  day,
  shifts,
  preview,
}: {
  employee: Employee;
  day: Date;
  shifts: Shift[];
  preview?: DropPreview | null;
}) {
  const dateKey = format(day, "yyyy-MM-dd");
  const { setNodeRef, isOver } = useDroppable({
    id: `${employee.id}-${dateKey}`,
    data: {
      type: "employee-day",
      employeeId: employee.id,
      dateKey,
      dayIso: day.toISOString()
    }
  });

  const cellPreview = preview?.employeeId === employee.id && preview.dateKey === dateKey ? preview : null;
  const hasConflict = Boolean(cellPreview?.result.conflicts.length);
  const hasWarnings = Boolean(cellPreview?.result.warnings.length);

  return (
    <div
      ref={setNodeRef}
      title={
        cellPreview
          ? [
              ...cellPreview.result.conflicts.map((item) => item.message),
              ...cellPreview.result.warnings.map((item) => item.message)
            ].join("\n")
          : undefined
      }
      className={`relative min-w-[220px] border-r border-black/5 px-1 py-1 ${
        isOver ? "bg-black/5" : ""
      } ${hasConflict ? "bg-rose-50" : cellPreview ? "bg-emerald-50" : ""}`}
    >
      <div className="pointer-events-none absolute inset-x-1 top-1 flex justify-between text-[10px] text-ink/25">
        <span>{CALENDAR_START_HOUR}:00</span>
        <span>{CALENDAR_END_HOUR}:00</span>
      </div>
      <div className="relative mt-5 h-20 rounded-2xl bg-black/[0.03]">
        {shifts.map((shift) => (
          <ShiftChip
            key={shift.id}
            shift={cellPreview?.shift.id === shift.id ? cellPreview.shift : shift}
            employeeName={employee.name}
            conflictState={
              cellPreview?.shift.id === shift.id
                ? hasConflict
                  ? "invalid"
                  : "valid"
                : "neutral"
            }
          />
        ))}
      </div>
      {hasWarnings ? (
        <div className="mt-2 flex items-center gap-1 text-[11px] text-amber-700">
          <AlertTriangle className="h-3.5 w-3.5" />
          {cellPreview?.result.warnings[0]?.message}
        </div>
      ) : null}
    </div>
  );
}

function PoolShift({ shift, onFocus }: { shift: Shift; onFocus?: () => void }) {
  const { attributes, listeners, setNodeRef, isDragging } = useDraggable({
    id: shift.id,
    data: { type: "shift", shift }
  });

  return (
    <button
      ref={setNodeRef}
      {...attributes}
      {...listeners}
      onFocus={onFocus}
      className={`w-full rounded-2xl border border-clay/25 bg-white px-3 py-3 text-left transition ${
        isDragging ? "opacity-40" : "hover:border-clay/50 hover:bg-sand/60"
      }`}
    >
      <div className="flex items-center justify-between gap-3">
        <span className="font-semibold text-ink">{format(new Date(shift.start), "EEE HH:mm")}</span>
        <Chip tone={shift.requiredRole === "manager" ? "amber" : "green"}>
          {shift.requiredEmployeeRoles.map((role) => formatEmployeeRole(role)).join(" / ")}
        </Chip>
      </div>
      <p className="mt-2 text-xs text-ink/70">
        {format(new Date(shift.start), "MMM d, HH:mm")} - {format(new Date(shift.end), "HH:mm")}
      </p>
    </button>
  );
}

export function CalendarBoard({
  dataset,
  range,
  windowMode
}: {
  dataset: SchedulerDataset;
  range: { start: Date; end: Date };
  windowMode: "week" | "two-week" | "month";
}) {
  const queryClient = useQueryClient();
  const sensors = useSensors(useSensor(PointerSensor, { activationConstraint: { distance: 6 } }));
  const visibleDays = useMemo(() => getVisibleDays(range, windowMode), [range, windowMode]);
  const [collapsedDepartments, setCollapsedDepartments] = useState<Record<string, boolean>>({});
  const [activeShift, setActiveShift] = useState<Shift | null>(null);
  const [preview, setPreview] = useState<DropPreview | null>(null);
  const [selectedShiftId, setSelectedShiftId] = useState<string | null>(null);
  const [selectedEmployeeIndex, setSelectedEmployeeIndex] = useState(0);
  const [undoStack, setUndoStack] = useState<UndoAction[]>([]);
  const [pointerX, setPointerX] = useState<number | null>(null);

  const departmentMap = new Map(dataset.departments.map((department) => [department.id, department]));
  const employeeMap = new Map(dataset.employees.map((employee) => [employee.id, employee]));
  const groupedEmployees = Object.entries(groupBy(dataset.employees, (employee) => employee.primaryDepartmentId));
  const assignedShifts = dataset.shifts.filter((shift) => shift.employeeId);
  const poolShifts = dataset.shifts.filter((shift) => !shift.employeeId);

  const shiftMutation = useMutation({
    mutationFn: async (shift: Shift) =>
      fetchJson(`/api/shifts/${shift.id}`, {
        method: "PATCH",
        body: JSON.stringify(shift)
      }),
    onMutate: async (nextShift) => {
      await queryClient.cancelQueries({ queryKey: schedulerKeys.snapshot(range.start.toISOString()) });
      const previous = queryClient.getQueryData<SchedulerDataset>(schedulerKeys.snapshot(range.start.toISOString()));
      if (previous) {
        queryClient.setQueryData<SchedulerDataset>(schedulerKeys.snapshot(range.start.toISOString()), {
          ...previous,
          shifts: previous.shifts.map((shift) => (shift.id === nextShift.id ? nextShift : shift))
        });
      }
      return { previous };
    },
    onError: (_error, _variables, context) => {
      if (context?.previous) {
        queryClient.setQueryData(schedulerKeys.snapshot(range.start.toISOString()), context.previous);
      }
    },
    onSettled: () => {
      void queryClient.invalidateQueries({ queryKey: schedulerKeys.snapshot(range.start.toISOString()) });
    }
  });

  function buildPreview(shift: Shift, employee: Employee, day: Date, ratio: number) {
    const proposedShift = buildShiftFromDrop(day, shift, employee.id, ratio);
    const department = departmentMap.get(proposedShift.departmentId);
    if (!department) {
      return null;
    }

    const result = validateShiftAssignment({
      proposedShift,
      employee,
      existingShifts: assignedShifts,
      department,
      allDepartmentShifts: dataset.shifts.filter((entry) => entry.departmentId === proposedShift.departmentId),
      employees: dataset.employees
    });

    return {
      employeeId: employee.id,
      dateKey: format(day, "yyyy-MM-dd"),
      shift: proposedShift,
      result
    };
  }

  function getRatioFromEvent(event: DragMoveEvent | DragEndEvent) {
    if (!event.over) {
      return 0;
    }

    const left = event.over.rect.left;
    const width = event.over.rect.width || 1;
    const translatedLeft = event.active.rect.current.translated?.left ?? pointerX ?? left;
    return (translatedLeft - left) / width;
  }

  function handleDragStart(event: DragStartEvent) {
    const shift = event.active.data.current?.shift as Shift | undefined;
    setActiveShift(shift ?? null);
    setSelectedShiftId(shift?.id ?? null);
  }

  function handleDragMove(event: DragMoveEvent) {
    setPointerX(event.active.rect.current.translated?.left ?? null);
    if (!activeShift || !event.over) {
      setPreview(null);
      return;
    }

    const employeeId = event.over.data.current?.employeeId as string | undefined;
    const dayIso = event.over.data.current?.dayIso as string | undefined;
    if (!employeeId || !dayIso) {
      setPreview(null);
      return;
    }

    const employee = employeeMap.get(employeeId);
    if (!employee) {
      setPreview(null);
      return;
    }

    setPreview(buildPreview(activeShift, employee, new Date(dayIso), getRatioFromEvent(event)));
  }

  function clearDragState() {
    setActiveShift(null);
    setPreview(null);
    setPointerX(null);
  }

  function commitShift(nextShift: Shift) {
    const previous = dataset.shifts.find((entry) => entry.id === nextShift.id);
    if (previous) {
      setUndoStack((current) => [{ shiftId: nextShift.id, previous }, ...current].slice(0, UNDO_STACK_LIMIT));
    }
    shiftMutation.mutate(nextShift);
  }

  function handleDragEnd(event: DragEndEvent) {
    if (!activeShift || !event.over) {
      clearDragState();
      return;
    }

    const employeeId = event.over.data.current?.employeeId as string | undefined;
    const dayIso = event.over.data.current?.dayIso as string | undefined;
    if (!employeeId || !dayIso) {
      clearDragState();
      return;
    }

    const employee = employeeMap.get(employeeId);
    if (!employee) {
      clearDragState();
      return;
    }

    const computedPreview = buildPreview(activeShift, employee, new Date(dayIso), getRatioFromEvent(event));
    if (!computedPreview || computedPreview.result.conflicts.length > 0) {
      clearDragState();
      return;
    }

    commitShift(computedPreview.shift);
    clearDragState();
  }

  function handleUndo() {
    const [next, ...rest] = undoStack;
    if (!next) {
      return;
    }

    setUndoStack(rest);
    shiftMutation.mutate(next.previous);
  }

  function handleKeyboardAssign() {
    if (!selectedShiftId) {
      return;
    }

    const shift = dataset.shifts.find((entry) => entry.id === selectedShiftId);
    const employee = dataset.employees[selectedEmployeeIndex];
    if (!shift || !employee) {
      return;
    }

    const previewResult = buildPreview(shift, employee, new Date(shift.start), 0.2);
    if (previewResult?.result.conflicts.length) {
      return;
    }

    commitShift(previewResult!.shift);
  }

  return (
    <div className="grid gap-6 lg:grid-cols-[300px,1fr]">
      <Card className="h-fit">
        <div className="flex items-center justify-between">
          <div>
            <p className="font-display text-xl">Unassigned Pool</p>
            <p className="text-sm text-ink/60">Drag onto any employee row.</p>
          </div>
          <Button variant="ghost" onClick={handleUndo} disabled={undoStack.length === 0}>
            <RotateCcw className="mr-2 h-4 w-4" />
            Undo
          </Button>
        </div>

        <div className="mt-4 space-y-5">
          {Object.entries(groupBy(poolShifts, (shift) => shift.departmentId)).map(([departmentId, shifts]) => (
            <div key={departmentId}>
              <div className="mb-2 flex items-center justify-between">
                <h3 className="font-semibold">{departmentMap.get(departmentId)?.name}</h3>
                <Chip>{shifts.length} open</Chip>
              </div>
              <div className="space-y-3">
                {shifts.map((shift) => (
                  <PoolShift key={shift.id} shift={shift} onFocus={() => setSelectedShiftId(shift.id)} />
                ))}
              </div>
            </div>
          ))}
        </div>

        <div className="mt-6 rounded-2xl bg-sand/70 p-4">
          <p className="font-semibold text-ink">Keyboard assignment</p>
          <p className="mt-1 text-sm text-ink/70">
            Select a shift, use arrow keys while this panel is focused to move through employees, then press Enter to assign.
          </p>
          <div
            className="mt-3 rounded-2xl border border-black/10 bg-white px-3 py-3 outline-none"
            tabIndex={0}
            onKeyDown={(event) => {
              if (event.key === "ArrowDown") {
                setSelectedEmployeeIndex((index) => Math.min(dataset.employees.length - 1, index + 1));
              }
              if (event.key === "ArrowUp") {
                setSelectedEmployeeIndex((index) => Math.max(0, index - 1));
              }
              if (event.key === "Enter") {
                handleKeyboardAssign();
              }
            }}
          >
            <p className="text-xs uppercase tracking-[0.25em] text-ink/45">Target employee</p>
            <p className="mt-1 font-semibold">{dataset.employees[selectedEmployeeIndex]?.name ?? "None selected"}</p>
          </div>
        </div>
      </Card>

      <Card className="overflow-hidden p-0">
        <DndContext
          sensors={sensors}
          onDragStart={handleDragStart}
          onDragMove={handleDragMove}
          onDragEnd={handleDragEnd}
          onDragCancel={clearDragState}
        >
          <div className="overflow-auto">
            <div className="sticky top-0 z-10 grid bg-white" style={{ gridTemplateColumns: `260px repeat(${visibleDays.length}, minmax(220px, 1fr))` }}>
              <div className="border-b border-r border-black/10 px-4 py-3">
                <p className="font-display text-lg">Employees</p>
              </div>
              {visibleDays.map((day) => (
                <div key={day.toISOString()} className="border-b border-r border-black/10 px-4 py-3">
                  <p className="text-xs uppercase tracking-[0.25em] text-ink/45">{format(day, "EEE")}</p>
                  <p className="mt-1 font-semibold">{format(day, "MMM d")}</p>
                </div>
              ))}
            </div>

            {groupedEmployees.map(([departmentId, employees]) => {
              const department = departmentMap.get(departmentId);
              if (!department) {
                return null;
              }

              const collapsed = collapsedDepartments[departmentId];

              return (
                <div key={departmentId}>
                  <button
                    className="sticky left-0 z-[5] flex w-full items-center justify-between border-b border-black/10 bg-sand/80 px-4 py-3 text-left"
                    onClick={() =>
                      setCollapsedDepartments((current) => ({ ...current, [departmentId]: !current[departmentId] }))
                    }
                  >
                    <div>
                      <p className="font-display text-lg">{department.name}</p>
                      <p className="text-sm text-ink/60">{employees.length} team members</p>
                    </div>
                    <Chip>{collapsed ? "Expand" : "Collapse"}</Chip>
                  </button>

                  {!collapsed
                    ? employees.map((employee) => (
                        <div
                          key={employee.id}
                          className="grid border-b border-black/5"
                          style={{ gridTemplateColumns: `260px repeat(${visibleDays.length}, minmax(220px, 1fr))` }}
                        >
                          <div className="border-r border-black/5 px-4 py-4">
                            <p className="font-semibold">{employee.name}</p>
                            <div className="mt-2 flex items-center gap-2">
                              <Chip tone={isManagerRole(employee.role) ? "amber" : "neutral"}>
                                {formatEmployeeRole(employee.role)}
                              </Chip>
                              <Chip>{employee.employmentType.replace("_", " ")}</Chip>
                            </div>
                            <p className="mt-2 text-xs text-ink/55">
                              Cap {employee.weeklyHourCap}h · Rate ${employee.hourlyRate}/hr
                            </p>
                          </div>
                          {visibleDays.map((day) => {
                            const dateKey = format(day, "yyyy-MM-dd");
                            const shifts = assignedShifts.filter(
                              (shift) =>
                                shift.employeeId === employee.id &&
                                format(new Date(shift.start), "yyyy-MM-dd") === dateKey,
                            );
                            return (
                              <CalendarDropCell
                                key={`${employee.id}-${dateKey}`}
                                employee={employee}
                                day={day}
                                shifts={shifts}
                                preview={preview}
                              />
                            );
                          })}
                        </div>
                      ))
                    : null}
                </div>
              );
            })}
          </div>

          <DragOverlay>
            {activeShift ? (
              <div className="rounded-2xl border border-moss/35 bg-white px-4 py-3 shadow-panel">
                <p className="font-semibold">{employeeMap.get(activeShift.employeeId ?? "")?.name ?? "Unassigned shift"}</p>
                <p className="mt-1 flex items-center gap-2 text-sm text-ink/65">
                  <Clock3 className="h-4 w-4" />
                  {format(new Date(activeShift.start), "EEE HH:mm")} - {format(new Date(activeShift.end), "HH:mm")}
                </p>
              </div>
            ) : null}
          </DragOverlay>
        </DndContext>
      </Card>
    </div>
  );
}
