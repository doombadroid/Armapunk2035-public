import { Crosshair, Target } from "lucide-react";
import { Card, Avatar, PlayerLink, Badge, PageHeader, Empty } from "@/components/ui";
import { getWantedList } from "@/lib/queries";
import { money } from "@/lib/format";

export const metadata = { title: "Bounty Board" };

export default async function BountiesPage() {
  const wanted = await getWantedList();

  return (
    <div>
      <div className="flex items-center gap-2 mb-6">
        <Target className="w-6 h-6 text-th-400" />
        <h1 className="text-2xl font-black text-th-400">Bounty Board</h1>
        {wanted.length > 0 && (
          <span className="ml-auto text-xs text-gray-500">{wanted.length} wanted</span>
        )}
      </div>

      {wanted.length === 0 ? (
        <Card className="p-2">
          <Empty>No active bounties.</Empty>
        </Card>
      ) : (
        <Card className="p-2 sm:p-4">
          <ul className="space-y-2">
            {wanted.map((w, i) => {
              const top = i === 0;
              return (
                <li
                  key={w.uid}
                  className={`flex items-center gap-3 rounded-xl px-3 py-3 border ${
                    top
                      ? "bg-th-600/20 border-th-700/30"
                      : "bg-gray-800/40 border-gray-800"
                  }`}
                >
                  <span className={`w-6 text-center text-lg font-black ${top ? "text-th-400" : "text-gray-600"}`}>
                    {i + 1}
                  </span>
                  <Avatar name={w.name} size={9} />
                  <div className="flex items-center gap-2 flex-1 min-w-0">
                    <PlayerLink uid={w.uid} name={w.name} className="text-sm truncate" />
                    {top && <Badge color="red">Most Wanted</Badge>}
                  </div>
                  <span
                    className={`shrink-0 inline-flex items-center gap-1.5 font-mono font-bold ${
                      top ? "text-red-300 text-base" : "text-th-300 text-sm"
                    }`}
                  >
                    <Crosshair className="w-3.5 h-3.5" />
                    {money(w.bounty)}
                  </span>
                </li>
              );
            })}
          </ul>
        </Card>
      )}
    </div>
  );
}
