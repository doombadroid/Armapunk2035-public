import { notFound, redirect } from "next/navigation";
import { ShieldOff, Wifi, Plus, Trash2 } from "lucide-react";
import { Card, SectionCard, Badge, PlayerLink, PageHeader, Empty } from "@/components/ui";
import { getSession } from "@/lib/session";
import { getActorPowers } from "@/lib/whitelist";
import { isAdminPlus } from "@/lib/factions";
import { listVpnExempt } from "@/lib/vpn";
import { bmEnabled } from "@/lib/bm";
import { addVpnExempt, removeVpnExempt } from "@/lib/actions";
import { dateShort } from "@/lib/format";

export const dynamic = "force-dynamic";
export const metadata = { title: "VPN Exemptions" };

export default async function VpnWhitelistPage() {
  const session = await getSession();
  if (!session) redirect("/login");
  const powers = await getActorPowers(session.uid);
  if (!isAdminPlus(powers)) notFound(); // admin 4+ / owner

  const [exempt, bmOn] = [await listVpnExempt(), bmEnabled()];

  return (
    <div>
      <PageHeader title="VPN Exemptions" />

      <Card className="p-4 mb-5">
        <div className="flex items-start gap-3">
          <Wifi className="w-5 h-5 text-th-400 mt-0.5 shrink-0" />
          <div className="text-sm text-gray-400">
            <p>
              BattleMetrics detects VPN/proxy connections and enforces them via a Trigger. Players added here get the
              {" "}<b className="text-gray-200">VPN Whitelisted</b> flag in BattleMetrics, which the Trigger skips.
            </p>
            <div className="mt-2 flex items-center gap-2 text-xs">
              {bmOn ? (
                <Badge color="green">BattleMetrics connected</Badge>
              ) : (
                <Badge color="red">BM token not set — exemptions won&apos;t apply</Badge>
              )}
              <Badge color="blue">Admin {powers.adminlevel || "owner"}+ only</Badge>
            </div>
          </div>
        </div>
      </Card>

      <div className="grid gap-6 lg:grid-cols-3">
        {/* add */}
        <div>
          <SectionCard title="Add Exemption" icon={<Plus className="w-4 h-4" />}>
            <form action={addVpnExempt} className="space-y-2">
              <input
                name="playerid"
                required
                inputMode="numeric"
                placeholder="Steam64 ID (17 digits)"
                className="w-full bg-gray-800 border border-gray-700 rounded px-3 py-2 text-sm text-gray-100"
              />
              <input
                name="note"
                placeholder="Reason / note (optional)"
                className="w-full bg-gray-800 border border-gray-700 rounded px-3 py-2 text-sm text-gray-100"
              />
              <button
                disabled={!bmOn}
                className="w-full px-3 py-2 rounded bg-th-600/20 border border-th-700/40 text-th-300 text-sm font-bold hover:bg-th-600/30 transition disabled:opacity-50"
              >
                Add to VPN whitelist
              </button>
              {!bmOn && <p className="text-xs text-gray-600">Set BM_TOKEN to enable.</p>}
            </form>
          </SectionCard>
        </div>

        {/* list */}
        <div className="lg:col-span-2">
          <SectionCard
            title="Exempt Players"
            icon={<ShieldOff className="w-4 h-4" />}
            right={<span className="text-xs text-gray-500">{exempt.length}</span>}
          >
            {exempt.length === 0 ? (
              <Empty>No VPN exemptions.</Empty>
            ) : (
              <ul className="divide-y divide-gray-800">
                {exempt.map((e) => (
                  <li key={e.id} className="flex items-center gap-3 py-2.5">
                    <div className="min-w-0 flex-1">
                      <PlayerLink uid={e.playerid} name={e.name || e.playerid} className="text-sm" />
                      {e.note && <p className="text-xs text-gray-500 truncate">{e.note}</p>}
                      <p className="text-xs text-gray-600">by {e.added_by} · {dateShort(e.created_at)}</p>
                    </div>
                    <form action={removeVpnExempt}>
                      <input type="hidden" name="playerid" value={e.playerid} />
                      <button
                        className="inline-flex items-center gap-1 px-2.5 py-1.5 rounded bg-gray-800 hover:bg-red-900/40 border border-gray-600 hover:border-red-700/50 text-gray-300 hover:text-red-300 text-xs font-bold transition"
                        title="Remove exemption"
                      >
                        <Trash2 className="w-3.5 h-3.5" /> Remove
                      </button>
                    </form>
                  </li>
                ))}
              </ul>
            )}
          </SectionCard>
        </div>
      </div>
    </div>
  );
}
