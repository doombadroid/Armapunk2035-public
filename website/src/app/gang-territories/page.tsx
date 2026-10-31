import { Map as MapIcon, Swords, Flag, Target } from "lucide-react";
import { Card, SectionCard, Badge, PageHeader, Empty } from "@/components/ui";
import { getTerritories, listGangs } from "@/lib/queries";

export const metadata = { title: "Gang Territories" };

const titleCase = (s: string) =>
  s.replace(/\w\S*/g, (w) => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase());

export default async function GangTerritoriesPage() {
  const [territories, gangs] = await Promise.all([getTerritories(), listGangs()]);

  const gangName = new Map<number, string>(gangs.map((g) => [g.id, g.name.trim()]));
  const nameFor = (id: number | null | undefined) => {
    const n = Number(id);
    if (!n) return null; // 0 / null / NaN => unowned/contested
    return gangName.get(n) ?? `Gang #${n}`;
  };

  const { cartels, turf, captures, fort } = territories;

  return (
    <div className="space-y-6">
      <PageHeader title="Gang Territories" />

      {/* Cartels */}
      <SectionCard title="Cartels" icon={<Swords className="w-4 h-4" />}>
        {cartels.length === 0 ? (
          <Empty>No cartels active.</Empty>
        ) : (
          <div className="grid gap-3" style={{ gridTemplateColumns: "repeat(auto-fit, minmax(220px, 1fr))" }}>
            {cartels.map((c) => {
              const owner = nameFor(c.gangId ? Number(c.gangId) : null);
              const pct = Math.round((Number(c.progress) || 0) * 100);
              return (
                <Card key={c.cartel} className="p-4">
                  <div className="flex items-center justify-between mb-1">
                    <span className="font-bold text-th-300 flex items-center gap-1.5">
                      <Flag className="w-3.5 h-3.5 text-th-500" />
                      {titleCase(c.cartel)}
                    </span>
                    <span className="text-xs font-mono text-gray-400">{pct}%</span>
                  </div>
                  <div className="text-xs text-gray-500 mb-2 truncate">
                    {owner ? (
                      <span className="text-gray-300">{owner}</span>
                    ) : (
                      <span className="italic">Unowned</span>
                    )}
                  </div>
                  <div className="h-2 rounded-full bg-gray-800 overflow-hidden">
                    <div className="h-full rounded-full bg-th-600" style={{ width: `${pct}%` }} />
                  </div>
                </Card>
              );
            })}
          </div>
        )}
      </SectionCard>

      <div className="grid gap-6" style={{ gridTemplateColumns: "repeat(auto-fit, minmax(300px, 1fr))" }}>
        {/* Turf */}
        <SectionCard title="Turf" icon={<MapIcon className="w-4 h-4" />}>
          {turf.length === 0 ? (
            <Empty>No turf zones.</Empty>
          ) : (
            <div className="grid gap-2" style={{ gridTemplateColumns: "repeat(auto-fill, minmax(140px, 1fr))" }}>
              {turf.map((t) => {
                const owner = nameFor(t.gang);
                return (
                  <div
                    key={t.id}
                    className="flex items-center justify-between gap-2 rounded-lg bg-gray-800/60 border border-gray-800 px-3 py-2"
                  >
                    <span className="text-xs font-mono text-gray-500 shrink-0">#{t.id}</span>
                    {owner ? (
                      <span className="text-xs text-th-300 font-semibold truncate">{owner}</span>
                    ) : (
                      <Badge color="gray">Contested</Badge>
                    )}
                  </div>
                );
              })}
            </div>
          )}
        </SectionCard>

        {/* Capture Points */}
        <SectionCard title="Capture Points" icon={<Target className="w-4 h-4" />}>
          {captures.length === 0 ? (
            <Empty>No capture points.</Empty>
          ) : (
            <ul className="space-y-2.5">
              {captures.map((cp) => {
                const owner = nameFor(cp.gang);
                const pct = Math.max(0, Math.min(100, Number(cp.percent) || 0));
                return (
                  <li key={cp.id} className="rounded-lg bg-gray-800/40 border border-gray-800 px-3 py-2.5">
                    <div className="flex items-center justify-between mb-1.5">
                      <span className="flex items-center gap-2 min-w-0">
                        <span className="text-xs font-mono text-gray-500 shrink-0">#{cp.id}</span>
                        <span className="text-sm truncate">
                          {owner ? (
                            <span className="text-th-300 font-semibold">{owner}</span>
                          ) : (
                            <span className="text-gray-500 italic">Unowned</span>
                          )}
                        </span>
                      </span>
                      <Badge color="th">Lvl {cp.level}</Badge>
                    </div>
                    <div className="h-2 rounded-full bg-gray-800 overflow-hidden">
                      <div className="h-full rounded-full bg-th-600" style={{ width: `${pct}%` }} />
                    </div>
                  </li>
                );
              })}
            </ul>
          )}
        </SectionCard>
      </div>

      {/* Gang Fortress */}
      <SectionCard title="Gang Fortress" icon={<Flag className="w-4 h-4" />}>
        <div className="flex items-center justify-between gap-4 flex-wrap">
          <div>
            <div className="text-xs text-gray-500 uppercase tracking-wider mb-1">Last Winner</div>
            <div className="text-lg font-bold text-th-300">
              {fort?.winnerName?.trim() || <span className="text-gray-500 italic font-normal">None yet</span>}
            </div>
          </div>
          {fort && fort.active === 1 ? (
            <Badge color="green">Active</Badge>
          ) : (
            <Badge color="gray">Idle</Badge>
          )}
        </div>
      </SectionCard>
    </div>
  );
}
