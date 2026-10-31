import Link from "next/link";
import { Users, Trophy, Search } from "lucide-react";
import { Card, PageHeader, Empty } from "@/components/ui";
import { listGangs } from "@/lib/queries";
import { commas, money } from "@/lib/format";

export const metadata = { title: "Gang Lookup" };

// 1st / 2nd / 3rd accent ring + medal color
const MEDALS: { ring: string; text: string; label: string }[] = [
  { ring: "border-amber-500/50", text: "text-amber-400", label: "1st" },
  { ring: "border-gray-400/50", text: "text-gray-300", label: "2nd" },
  { ring: "border-orange-600/50", text: "text-orange-400", label: "3rd" },
];

export default async function GangLookupPage({
  searchParams,
}: { searchParams: Promise<{ q?: string }> }) {
  const { q } = await searchParams;
  const gangs = await listGangs(q);

  return (
    <div>
      <PageHeader title="Gang Lookup" />

      <form method="get" className="mb-6 flex gap-2">
        <div className="relative flex-1">
          <Search className="w-4 h-4 text-gray-500 absolute left-3 top-1/2 -translate-y-1/2 pointer-events-none" />
          <input
            type="text"
            name="q"
            defaultValue={q ?? ""}
            placeholder="Search gangs by name…"
            className="w-full bg-gray-900 border border-th-700/30 rounded-xl pl-9 pr-3 py-2.5 text-sm text-gray-200 placeholder:text-gray-600 focus:outline-none focus:border-th-600 transition"
          />
        </div>
        <button
          type="submit"
          className="px-5 py-2.5 rounded-xl bg-th-600 hover:bg-th-500 text-white font-bold text-sm transition shrink-0"
        >
          Search
        </button>
      </form>

      {gangs.length === 0 ? (
        <Card className="p-0">
          <Empty>{q ? `No gangs match “${q}”.` : "No gangs found."}</Empty>
        </Card>
      ) : (
        <div className="grid gap-4" style={{ gridTemplateColumns: "repeat(auto-fill, minmax(280px, 1fr))" }}>
          {gangs.map((g, i) => {
            const medal = i < 3 ? MEDALS[i] : null;
            return (
              <Card
                key={g.id}
                className={`p-5 hover:border-th-600/50 transition ${medal ? medal.ring : ""}`}
              >
                <div className="flex items-start justify-between gap-2 mb-3">
                  <Link
                    href={`/gameserver/gang-detail?id=${g.id}`}
                    className="text-lg font-black text-th-400 hover:text-th-300 transition truncate"
                  >
                    {g.name.trim()}
                  </Link>
                  {medal && (
                    <span className={`inline-flex items-center gap-1 text-xs font-black shrink-0 ${medal.text}`}>
                      <Trophy className="w-3.5 h-3.5" /> {medal.label}
                    </span>
                  )}
                </div>

                <div className="flex items-center justify-between text-sm">
                  <span className="inline-flex items-center gap-1.5 text-gray-400">
                    <Users className="w-4 h-4 text-th-500" />
                    {g.members} {g.members === 1 ? "member" : "members"}
                  </span>
                  <span className="text-gray-500 text-xs font-mono">{commas(g.experience)} XP</span>
                </div>

                <div className="mt-3 pt-3 border-t border-gray-800 flex items-center justify-between">
                  <span className="text-xs text-gray-500 uppercase tracking-wider">Bank</span>
                  <span className="text-sm font-bold text-green-400">{money(g.bank)}</span>
                </div>
              </Card>
            );
          })}
        </div>
      )}
    </div>
  );
}
