import { notFound, redirect } from "next/navigation";
import { Ban } from "lucide-react";
import { Card, SectionCard, Badge, Avatar, PlayerLink, PageHeader, Empty } from "@/components/ui";
import { getSession } from "@/lib/session";
import { getActorPowers } from "@/lib/whitelist";
import { getActiveBans } from "@/lib/bans";
import { dateShort, dateLong } from "@/lib/format";

export const dynamic = "force-dynamic";
export const metadata = { title: "Active Bans" };

export default async function BansPage() {
  const session = await getSession();
  if (!session) redirect("/login");
  const powers = await getActorPowers(session.uid);
  const isStaff = powers.isOwner || powers.adminlevel >= 1;
  if (!isStaff) notFound();

  const bans = await getActiveBans(300);
  const perma = bans.filter((b) => !b.until).length;

  return (
    <div>
      <PageHeader title="Active Bans" />
      <Card className="p-3 mb-5 flex items-center gap-3 text-xs text-gray-500">
        <Badge color="red">{bans.length} active</Badge>
        <span>{perma} permanent</span>
        <span>{bans.filter((b) => b.clankr).length} by CLANKR</span>
      </Card>

      <SectionCard title="Banned Players" icon={<Ban className="w-4 h-4" />}>
        {bans.length === 0 ? (
          <Empty>No active bans.</Empty>
        ) : (
          <ul className="divide-y divide-gray-800">
            {bans.map((b) => (
              <li key={b.id} className="flex items-start gap-3 py-3">
                <Avatar name={b.name ?? b.playerid} size={9} />
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-2 flex-wrap">
                    {b.name ? (
                      <PlayerLink uid={b.playerid} name={b.name} className="text-sm" />
                    ) : (
                      <span className="text-sm text-gray-400 font-mono">{b.playerid}</span>
                    )}
                    {b.clankr && <Badge color="red">CLANKR</Badge>}
                    {!b.until && <Badge color="orange">Permanent</Badge>}
                  </div>
                  <p className="text-sm text-gray-300 mt-0.5 break-words">{b.reason}</p>
                  <p className="text-xs text-gray-600 mt-0.5">
                    by {b.banned_by} · {dateShort(b.created)}
                    {b.until && <> · expires {dateLong(b.until)}</>}
                  </p>
                </div>
              </li>
            ))}
          </ul>
        )}
      </SectionCard>
    </div>
  );
}
