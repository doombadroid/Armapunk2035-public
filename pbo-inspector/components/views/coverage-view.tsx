import { Card } from "@/components/ui/card";
import { Chip } from "@/components/ui/chip";
import { getCoverageBlocks } from "@/lib/data/metrics";
import type { SchedulerDataset } from "@/lib/types";

export function CoverageView({
  dataset,
  range
}: {
  dataset: SchedulerDataset;
  range: { start: Date; end: Date };
}) {
  return (
    <div className="grid gap-5 lg:grid-cols-3">
      {dataset.departments.map((department) => {
        const blocks = getCoverageBlocks(department, dataset.employees, dataset.shifts, range.start, range.end);

        return (
          <Card key={department.id}>
            <div className="flex items-center justify-between">
              <div>
                <p className="font-display text-2xl">{department.name}</p>
                <p className="text-sm text-ink/60">Open coverage windows and role requirements</p>
              </div>
              <Chip>{blocks.length} blocks</Chip>
            </div>

            <div className="mt-5 space-y-3">
              {blocks.map((block) => (
                <div
                  key={block.id}
                  className={`rounded-2xl border p-4 ${
                    block.state === "red" ? "border-rose-200 bg-rose-50" : "border-emerald-200 bg-emerald-50"
                  }`}
                >
                  <div className="flex items-start justify-between gap-4">
                    <div>
                      <p className="font-semibold">{block.label}</p>
                      <p className="mt-1 text-xs text-ink/60">
                        Open: {block.openHours?.openTime ?? "--"} - {block.openHours?.closeTime ?? "--"}
                      </p>
                    </div>
                    <Chip tone={block.state === "red" ? "red" : "green"}>
                      {block.state === "red" ? "Unmet" : "Met"}
                    </Chip>
                  </div>

                  <div className="mt-4 space-y-2">
                    {block.roleStatuses.map((role) => (
                      <div key={`${block.id}-${role.role}`} className="flex items-center justify-between rounded-xl bg-white/70 px-3 py-2">
                        <span className="text-sm font-medium">{role.roleLabel}</span>
                        <span className={`text-sm ${role.scheduled < role.required ? "text-rose-700" : "text-emerald-700"}`}>
                          {role.scheduled} / {role.required}
                        </span>
                      </div>
                    ))}
                  </div>

                  {block.alternativeLabel ? (
                    <p className="mt-3 text-xs text-ink/55">Alternative manager set considered: {block.alternativeLabel}</p>
                  ) : null}
                </div>
              ))}
            </div>
          </Card>
        );
      })}
    </div>
  );
}
