import { getPaySummary } from "@/lib/data/metrics";
import type { SchedulerDataset } from "@/lib/types";
import { Card } from "@/components/ui/card";
import { Chip } from "@/components/ui/chip";

export function PayView({
  dataset,
  range
}: {
  dataset: SchedulerDataset;
  range: { start: Date; end: Date };
}) {
  const summary = getPaySummary(dataset.departments, dataset.employees, dataset.shifts, range.start, range.end);

  return (
    <div className="grid gap-5 lg:grid-cols-3">
      {summary.map((entry) => (
        <Card key={entry.departmentId} className="bg-white">
          <div className="flex items-center justify-between">
            <div>
              <p className="font-display text-2xl">{entry.departmentName}</p>
              <p className="text-sm text-ink/60">Scheduled pay vs pay-period budget</p>
            </div>
            <Chip tone={entry.state === "over" ? "red" : entry.state === "amber" ? "amber" : "green"}>
              {entry.state === "over" ? "Over budget" : entry.state === "amber" ? "Watch" : "Healthy"}
            </Chip>
          </div>
          <div className="mt-6 grid gap-4">
            <div className="rounded-2xl bg-sand/55 p-4">
              <p className="text-xs uppercase tracking-[0.25em] text-ink/45">Scheduled Pay</p>
              <p className="mt-2 font-display text-3xl">${entry.scheduledPay.toFixed(0)}</p>
            </div>
            <div className="rounded-2xl border border-black/8 p-4">
              <p className="text-xs uppercase tracking-[0.25em] text-ink/45">Budget</p>
              <p className="mt-2 text-xl font-semibold">${entry.budget.toFixed(0)}</p>
            </div>
            <div className="rounded-2xl border border-black/8 p-4">
              <p className="text-xs uppercase tracking-[0.25em] text-ink/45">Variance</p>
              <p className={`mt-2 text-xl font-semibold ${entry.variance < 0 ? "text-rose-700" : "text-emerald-700"}`}>
                ${Math.abs(entry.variance).toFixed(0)} {entry.variance < 0 ? "over" : "remaining"}
              </p>
            </div>
          </div>
        </Card>
      ))}
    </div>
  );
}
