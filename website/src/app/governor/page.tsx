import { Crown } from "lucide-react";
import { Card, Avatar, PlayerLink, Badge, PageHeader, Empty } from "@/components/ui";
import { getGovernor } from "@/lib/queries";
import { commas } from "@/lib/format";

export const metadata = { title: "Governor Election" };

export default async function GovernorPage() {
  const candidates = await getGovernor();

  if (candidates.length === 0) {
    return (
      <div>
        <PageHeader title="Governor Election" />
        <Card className="p-2">
          <Empty>No election in progress.</Empty>
        </Card>
      </div>
    );
  }

  const total = candidates.reduce((s, c) => s + c.votes, 0);
  const maxVotes = Math.max(...candidates.map((c) => c.votes), 1);

  return (
    <div>
      <div className="flex items-center gap-2 mb-6">
        <Crown className="w-6 h-6 text-th-400" />
        <h1 className="text-2xl font-black text-th-400">Governor Election</h1>
        <span className="ml-auto text-xs text-gray-500">{commas(total)} total votes</span>
      </div>

      <Card className="p-2 sm:p-4">
        <ul className="space-y-2">
          {candidates.map((c, i) => {
            const pctOfTotal = total > 0 ? Math.round((c.votes / total) * 100) : 0;
            const barPct = Math.round((c.votes / maxVotes) * 100);
            return (
              <li
                key={c.candidate}
                className="flex items-center gap-3 rounded-xl px-3 py-3 bg-gray-800/40 border border-gray-800"
              >
                <span className={`w-6 text-center text-lg font-black ${i === 0 ? "text-th-400" : "text-gray-600"}`}>
                  {i + 1}
                </span>
                <Avatar name={c.name} size={9} />
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 mb-1.5">
                    <PlayerLink uid={c.candidate} name={c.name} className="text-sm truncate" />
                    {i === 0 && <Badge color="amber">Leading</Badge>}
                  </div>
                  <div className="h-2.5 rounded-full bg-gray-800 overflow-hidden">
                    <div className="h-full rounded-full bg-th-600" style={{ width: `${barPct}%` }} />
                  </div>
                </div>
                <div className="text-right shrink-0">
                  <div className="text-sm font-bold text-th-300 font-mono">{commas(c.votes)}</div>
                  <div className="text-xs text-gray-500">{pctOfTotal}%</div>
                </div>
              </li>
            );
          })}
        </ul>
      </Card>
    </div>
  );
}
