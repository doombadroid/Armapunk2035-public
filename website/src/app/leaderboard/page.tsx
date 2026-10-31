import Link from "next/link";
import {
  Trophy, Medal, Clock, User, ChevronRight,
  DollarSign, TrendingUp, Skull, Swords, Shield, Stethoscope, Gem, Dice5,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { Card, Avatar, PlayerLink, Empty } from "@/components/ui";
import LbMetricSelect from "@/components/LbMetricSelect";
import { leaderboard, leaderboardRank } from "@/lib/queries";
import { fetchSteamProfiles } from "@/lib/steam";
import { getSession } from "@/lib/session";
import { LB_CATEGORIES, lbMetric, fmtLbValue, DEFAULT_METRIC } from "@/lib/leaderboards";

export const dynamic = "force-dynamic";
export const metadata = { title: "Leaderboards" };

const CAT_ICON: Record<string, LucideIcon> = {
  DollarSign, TrendingUp, Skull, Swords, Shield, Stethoscope, Gem, Dice5,
};

// Top-3 medal styling — literal classes only (Tailwind v4 scans source; semantic
// gold/silver/bronze are intentionally NOT themed).
const MEDAL: Record<number, string> = {
  0: "text-amber-400",   // gold
  1: "text-slate-300",   // silver
  2: "text-amber-700",   // bronze
};

export default async function LeaderboardPage({
  searchParams,
}: { searchParams: Promise<{ metric?: string }> }) {
  const sp = await searchParams;
  const metric = lbMetric(sp.metric);
  const activeCat = LB_CATEGORIES.find((c) => c.metrics.some((m) => m.key === metric.key));

  const session = await getSession();
  const [rows, mine] = await Promise.all([
    leaderboard(metric.key, 100),
    session ? leaderboardRank(metric.key, session.uid) : Promise.resolve(null),
  ]);
  const avatars = await fetchSteamProfiles(rows.map((r) => r.uid));

  return (
    <div>
      {/* header */}
      <div className="flex items-end justify-between gap-3 flex-wrap mb-6">
        <div>
          <h1 className="text-3xl sm:text-4xl font-black text-th-400">Leaderboards</h1>
          <p className="text-xs text-gray-500 mt-1 flex items-center gap-1.5">
            <Clock className="w-3.5 h-3.5" /> All-time rankings · live from the game database
          </p>
        </div>
        {mine && (
          <div className="flex items-center gap-2 px-4 py-2 bg-gray-900 border border-gray-800 rounded-xl text-sm">
            <User className="w-4 h-4 text-th-400 shrink-0" />
            <span className="text-gray-300">
              Your rank: <span className="font-bold text-th-300">#{mine.rank}</span>
              <span className="text-gray-500"> · {fmtLbValue(metric, mine.value)}</span>
            </span>
          </div>
        )}
      </div>

      {/* mobile metric picker */}
      <div className="lg:hidden mb-4">
        <LbMetricSelect value={metric.key} />
      </div>

      <div className="flex gap-6 items-start">
        {/* desktop category rail */}
        <aside className="hidden lg:block w-56 shrink-0 sticky top-[70px] max-h-[calc(100vh-90px)] overflow-y-auto bg-gray-900 border border-gray-800 rounded-xl p-3">
          <nav className="space-y-3">
            {LB_CATEGORIES.map((c) => {
              const Icon = CAT_ICON[c.icon] ?? Trophy;
              const activeGroup = c.key === activeCat?.key;
              return (
                <div key={c.key}>
                  <div className={`flex items-center gap-1.5 px-3 py-1.5 text-xs font-bold uppercase tracking-wider ${activeGroup ? "text-th-400" : "text-gray-500"}`}>
                    <Icon className="w-3.5 h-3.5 shrink-0" /> {c.label}
                  </div>
                  <div className="ml-2 mt-0.5 space-y-px">
                    {c.metrics.map((m) => {
                      const active = m.key === metric.key;
                      return (
                        <Link
                          key={m.key}
                          href={`/leaderboard?metric=${m.key}`}
                          className={`block px-3 py-1.5 rounded-lg text-xs transition ${
                            active
                              ? "bg-th-600/20 text-th-300 font-semibold border border-th-600/30"
                              : "text-gray-400 hover:text-gray-200 hover:bg-gray-800/50"
                          }`}
                        >
                          {m.label}
                        </Link>
                      );
                    })}
                  </div>
                </div>
              );
            })}
          </nav>
        </aside>

        {/* board */}
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2 mb-3">
            {(() => { const Icon = CAT_ICON[activeCat?.icon ?? ""] ?? Trophy; return <Icon className="w-5 h-5 text-th-400" />; })()}
            <h2 className="text-lg font-bold text-gray-100">{metric.label}</h2>
            <span className="text-xs text-gray-600">· {activeCat?.label}</span>
          </div>

          {rows.length === 0 ? (
            <Card className="p-2"><Empty>No ranked players for this metric yet.</Empty></Card>
          ) : (
            <Card className="divide-y divide-gray-800">
              {rows.map((r, i) => {
                const isSelf = session?.uid === r.uid;
                return (
                  <div
                    key={r.uid}
                    className={`flex items-center gap-3 px-4 py-2.5 ${isSelf ? "bg-th-600/10" : ""}`}
                  >
                    <span className="w-8 flex justify-center shrink-0">
                      {i < 3 ? (
                        <Trophy className={`w-5 h-5 ${MEDAL[i]}`} />
                      ) : (
                        <span className="text-sm font-black tabular-nums text-gray-600">{i + 1}</span>
                      )}
                    </span>
                    <Avatar name={r.name} size={9} src={avatars.get(r.uid)?.avatar} />
                    <div className="min-w-0 flex-1">
                      <div className="flex items-center gap-1.5">
                        <PlayerLink uid={r.uid} name={r.name} className="text-sm truncate" />
                        {isSelf && <span className="text-[10px] font-bold text-th-400 shrink-0">YOU</span>}
                      </div>
                      {r.gangName && <p className="text-xs text-gray-500 truncate">{r.gangName.trim()}</p>}
                    </div>
                    <span className="text-sm font-mono font-bold text-gray-200 shrink-0 tabular-nums">
                      {fmtLbValue(metric, r.value)}
                    </span>
                  </div>
                );
              })}
            </Card>
          )}
          <p className="text-xs text-gray-600 mt-3 flex items-center gap-1">
            <ChevronRight className="w-3 h-3" /> Showing top {rows.length}. Metrics pull straight from the live game stats.
          </p>
        </div>
      </div>
    </div>
  );
}
