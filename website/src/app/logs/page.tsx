import { notFound, redirect } from "next/navigation";
import Link from "next/link";
import { ScrollText, Search } from "lucide-react";
import { Card, SectionCard, Badge, PlayerLink, PageHeader, Empty } from "@/components/ui";
import { getSession } from "@/lib/session";
import { getActorPowers } from "@/lib/whitelist";
import { isAdminPlus } from "@/lib/factions";
import { globalActivity, getPlayerActivity, searchPlayers } from "@/lib/queries";
import { getClankrAlerts, clankrStats, severityColor } from "@/lib/clankr";
import { tagMeta } from "@/lib/logtags";
import { dateLong, relative } from "@/lib/format";
import { ShieldAlert } from "lucide-react";

export const dynamic = "force-dynamic";
export const metadata = { title: "Player Logs" };

export default async function LogsPage({
  searchParams,
}: { searchParams: Promise<{ q?: string; playerid?: string }> }) {
  const session = await getSession();
  if (!session) redirect("/login");

  const powers = await getActorPowers(session.uid);
  if (!isAdminPlus(powers)) notFound(); // admin 4+ / owner only

  const sp = await searchParams;
  const q = (sp.q ?? "").trim();
  const playerid = (sp.playerid ?? "").trim();

  const [matches, rows, clankr, cStats] = await Promise.all([
    q ? searchPlayers(q, 12) : Promise.resolve([]),
    playerid ? getPlayerActivity(playerid, 200) : globalActivity(120),
    getClankrAlerts(playerid || undefined, 60),
    clankrStats(),
  ]);

  return (
    <div>
      <PageHeader title="Player Logs" />
      <Card className="p-3 mb-5">
        <div className="flex items-center gap-2 text-xs text-gray-500">
          <Badge color="red">Admin {powers.adminlevel}+ only</Badge>
          Raw server activity log. Visible to staff only.
        </div>
      </Card>

      {/* CLANKR anti-cheat */}
      <div className="mb-6">
        <SectionCard
          title="CLANKR Anti-Cheat"
          icon={<ShieldAlert className="w-4 h-4" />}
          right={<span className="text-xs text-gray-500">7d: {cStats.high} high · {cStats.med} med · {cStats.low} low</span>}
        >
          {clankr.length === 0 ? (
            <Empty>No CLANKR alerts{playerid ? " for this player" : " yet"}.</Empty>
          ) : (
            <ul className="divide-y divide-gray-800 max-h-[28rem] overflow-y-auto">
              {clankr.map((a) => (
                <li key={a.id} className="py-2.5 flex items-start gap-2">
                  <Badge color={severityColor(a.severity)} className="mt-0.5 shrink-0">{a.severity}</Badge>
                  <div className="min-w-0">
                    <div className="text-sm text-gray-200">
                      <span className="font-bold text-th-400">{a.rule}</span> —{" "}
                      <PlayerLink uid={a.playerid} name={a.name} className="text-sm" />
                    </div>
                    {a.detail && <div className="text-xs text-gray-400 break-words">{a.detail}</div>}
                    {a.snippet && <div className="text-xs text-gray-600 font-mono break-words mt-0.5">{a.snippet}</div>}
                    <div className="text-xs text-gray-600 mt-0.5">{relative(a.ts)}</div>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </SectionCard>
      </div>

      <div className="grid gap-6 lg:grid-cols-4">
        {/* player picker */}
        <div className="lg:col-span-1">
          <SectionCard title="Find Player" icon={<Search className="w-4 h-4" />}>
            <form method="get" className="space-y-2">
              <input
                name="q"
                defaultValue={q}
                placeholder="Name or Steam ID…"
                className="w-full bg-gray-800 border border-gray-700 rounded px-3 py-2 text-sm text-gray-100"
              />
              <button className="w-full px-3 py-2 rounded bg-th-600/20 border border-th-700/40 text-th-300 text-sm font-bold">Search</button>
            </form>
            <div className="mt-3 divide-y divide-gray-800">
              {matches.map((m) => (
                <Link key={m.uid} href={`/logs?playerid=${m.uid}`} className="block py-2 text-sm text-gray-300 hover:text-th-300">
                  {m.name}
                </Link>
              ))}
            </div>
            {playerid && (
              <Link href="/logs" className="mt-3 inline-block text-xs text-th-500 hover:text-th-400">← back to all activity</Link>
            )}
          </SectionCard>
        </div>

        {/* log stream */}
        <div className="lg:col-span-3">
          <SectionCard
            title={playerid ? "Player Activity" : "Live Server Activity"}
            icon={<ScrollText className="w-4 h-4" />}
            right={<span className="text-xs text-gray-500">{rows.length} rows</span>}
          >
            {rows.length === 0 ? <Empty>No log rows.</Empty> : (
              <ul className="divide-y divide-gray-800 max-h-[70vh] overflow-y-auto text-sm">
                {rows.map((r) => {
                  const meta = tagMeta(r.tag);
                  return (
                    <li key={r.id} className="py-2 flex items-start gap-2">
                      <Badge color={meta.color} className="mt-0.5 shrink-0">{r.tag.replace(/-/g, "")}</Badge>
                      <div className="min-w-0">
                        <div className="text-xs text-gray-600">
                          <PlayerLink uid={r.playerid} name={r.name} className="text-xs" /> · {dateLong(r.ts)}
                        </div>
                        <div className="text-gray-300 break-words text-xs font-mono">{r.message}</div>
                      </div>
                    </li>
                  );
                })}
              </ul>
            )}
          </SectionCard>
        </div>
      </div>
    </div>
  );
}
