"use client";

import {
  addDays,
  format,
  startOfWeek,
} from "date-fns";
import { useMemo, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { CalendarBoard } from "@/components/calendar/calendar-board";
import { CoverageView } from "@/components/views/coverage-view";
import { PayView } from "@/components/views/pay-view";
import { RosterView } from "@/components/views/roster-view";
import { autoGenerateAssignments, fetchJson, getSchedulerSnapshot } from "@/lib/api";
import { schedulerKeys } from "@/lib/query/keys";
import type { SchedulerDataset } from "@/lib/types";

const viewOptions = [
  { id: "calendar", label: "Calendar" },
  { id: "coverage", label: "Coverage" },
  { id: "pay", label: "Pay" },
  { id: "roster", label: "Roster" }
] as const;

type DashboardView = (typeof viewOptions)[number]["id"];

export function SchedulerDashboard() {
  const [view, setView] = useState<DashboardView>("calendar");
  const [windowMode, setWindowMode] = useState<"week" | "two-week" | "month">("week");
  const [rangeStart, setRangeStart] = useState(() =>
    startOfWeek(new Date("2026-04-20T00:00:00.000Z"), { weekStartsOn: 1 }).toISOString(),
  );
  const queryClient = useQueryClient();

  const snapshotQuery = useQuery({
    queryKey: schedulerKeys.snapshot(rangeStart),
    queryFn: () => getSchedulerSnapshot(rangeStart)
  });

  const publishMutation = useMutation({
    mutationFn: async (shiftIds: string[]) =>
      fetchJson("/api/shifts/publish", {
        method: "POST",
        body: JSON.stringify({ shiftIds })
      }),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: schedulerKeys.snapshot(rangeStart) });
    }
  });
  const autoGenerateMutation = useMutation({
    mutationFn: async ({ start, end }: { start: string; end: string }) => autoGenerateAssignments(start, end),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: schedulerKeys.snapshot(rangeStart) });
    }
  });

  const range = useMemo(() => {
    const start = new Date(rangeStart);
    return {
      start,
      end:
        windowMode === "week"
          ? addDays(start, 6)
          : windowMode === "two-week"
            ? addDays(start, 13)
            : addDays(start, 29)
    };
  }, [rangeStart, windowMode]);

  const dataset = snapshotQuery.data as SchedulerDataset | undefined;
  const draftIds = dataset?.shifts.filter((shift) => shift.status === "draft").map((shift) => shift.id) ?? [];

  return (
    <main className="mx-auto flex min-h-screen max-w-[1500px] flex-col gap-6 px-6 py-8">
      <Card className="overflow-hidden bg-[linear-gradient(135deg,rgba(18,33,28,0.95),rgba(31,111,80,0.92))] text-white">
        <div className="flex flex-col gap-6 lg:flex-row lg:items-end lg:justify-between">
          <div className="max-w-3xl">
            <p className="font-display text-sm uppercase tracking-[0.32em] text-white/70">Shift Scheduler</p>
            <h1 className="mt-2 font-display text-4xl font-bold">Live staffing, coverage, and budget control in one board.</h1>
            <p className="mt-3 max-w-2xl text-sm text-white/80">
              Assign from the pool, drag across departments, and let the conflict engine call out what is blocked,
              what is risky, and what still needs coverage.
            </p>
          </div>
          <div className="flex flex-wrap items-center gap-3">
            <Button variant="secondary" onClick={() => setRangeStart(addDays(new Date(rangeStart), -7).toISOString())}>
              Previous
            </Button>
            <Button variant="secondary" onClick={() => setRangeStart(addDays(new Date(rangeStart), 7).toISOString())}>
              Next
            </Button>
            <Button
              variant="secondary"
              onClick={() => autoGenerateMutation.mutate({ start: range.start.toISOString(), end: range.end.toISOString() })}
              disabled={autoGenerateMutation.isPending}
            >
              Auto Generate
            </Button>
            <Button
              onClick={() => publishMutation.mutate(draftIds)}
              disabled={draftIds.length === 0 || publishMutation.isPending}
            >
              Publish Draft Shifts
            </Button>
          </div>
        </div>
      </Card>

      <div className="flex flex-wrap items-center justify-between gap-4">
        <div className="flex flex-wrap gap-2">
          {viewOptions.map((option) => (
            <Button
              key={option.id}
              variant={view === option.id ? "primary" : "secondary"}
              onClick={() => setView(option.id)}
            >
              {option.label}
            </Button>
          ))}
        </div>
        <div className="flex items-center gap-2 rounded-full border border-black/10 bg-white/70 p-1">
          {(["week", "two-week", "month"] as const).map((mode) => (
            <button
              key={mode}
              className={`rounded-full px-3 py-1.5 text-sm font-medium ${windowMode === mode ? "bg-ink text-white" : "text-ink/70"}`}
              onClick={() => setWindowMode(mode)}
            >
              {mode}
            </button>
          ))}
        </div>
      </div>

      <Card className="p-4">
        <div className="flex items-center justify-between">
          <div>
            <p className="text-sm font-medium uppercase tracking-[0.25em] text-ink/45">Current window</p>
            <p className="mt-1 font-display text-2xl">
              {format(range.start, "MMM d")} - {format(range.end, "MMM d, yyyy")}
            </p>
          </div>
          <p className="text-sm text-ink/65">
            {dataset ? `${dataset.employees.length} employees, ${dataset.shifts.length} shifts` : "Loading schedule..."}
          </p>
        </div>
      </Card>

      {view === "calendar" && dataset ? (
        <CalendarBoard dataset={dataset} range={range} windowMode={windowMode} />
      ) : null}
      {view === "coverage" && dataset ? (
        <CoverageView dataset={dataset} range={range} />
      ) : null}
      {view === "pay" && dataset ? <PayView dataset={dataset} range={range} /> : null}
      {view === "roster" && dataset ? <RosterView dataset={dataset} anchorDate={range.start} /> : null}
    </main>
  );
}
