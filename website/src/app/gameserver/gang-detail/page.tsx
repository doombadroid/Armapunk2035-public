import { notFound } from "next/navigation";
import Link from "next/link";
import { Users, Car, Swords, Trophy, Coins, Star, Crown } from "lucide-react";
import { Card, SectionCard, Badge, Avatar, PlayerLink, PageHeader, Empty } from "@/components/ui";
import { getGangDetail } from "@/lib/queries";
import { getSession } from "@/lib/session";
import { getActorPowers } from "@/lib/whitelist";
import GangAdminPanel from "@/components/GangAdminPanel";
import { gangRank } from "@/lib/ranks";
import { commas, money } from "@/lib/format";

export const dynamic = "force-dynamic";

export async function generateMetadata({
  searchParams,
}: { searchParams: Promise<{ id?: string }> }) {
  const { id } = await searchParams;
  if (!id) return { title: "Gang" };
  const g = await getGangDetail(Number(id));
  return { title: g ? `${g.name.trim()} — Gang` : "Gang" };
}

export default async function GangDetailPage({
  searchParams,
}: { searchParams: Promise<{ id?: string }> }) {
  const { id } = await searchParams;
  if (!id) notFound();

  const g = await getGangDetail(Number(id));
  if (!g) notFound();

  const session = await getSession();
  const powers = session ? await getActorPowers(session.uid) : null;
  const canEcon = !!powers && (powers.isOwner || powers.adminlevel >= 3);

  return (
    <div>
      <PageHeader title="" back={{ href: "/gameserver/gangs", label: "Back to Gangs" }} />

      {/* header card */}
      <Card className="p-6 mb-6">
        <div className="flex items-center gap-4">
          <Avatar name={g.name.trim()} size={14} />
          <div className="min-w-0">
            <h1 className="text-3xl font-black text-th-400 truncate">{g.name.trim()}</h1>
            <p className="text-gray-500 text-xs font-mono mt-1">Gang #{g.id}</p>
          </div>
        </div>

        <div className="flex flex-wrap gap-2 mt-4 pt-4 border-t border-gray-800">
          <Badge color="th"><Star className="w-3 h-3" /> {commas(g.experience)} XP</Badge>
          <Badge color="green"><Coins className="w-3 h-3" /> {money(g.bank)}</Badge>
          <Badge color="blue"><Users className="w-3 h-3" /> {g.members.length} {g.members.length === 1 ? "Member" : "Members"}</Badge>
          <Badge color="sky"><Car className="w-3 h-3" /> {g.vehicleCount} {g.vehicleCount === 1 ? "Vehicle" : "Vehicles"}</Badge>
          {g.fortWins > 0 && <Badge color="amber"><Trophy className="w-3 h-3" /> {commas(g.fortWins)} Fort {g.fortWins === 1 ? "Win" : "Wins"}</Badge>}
        </div>
      </Card>

      {canEcon && (
        <div className="mb-6">
          <GangAdminPanel gangId={Number(g.id)} bank={Number(g.bank)} experience={Number(g.experience)} />
        </div>
      )}

      <div className="grid gap-6" style={{ gridTemplateColumns: "repeat(auto-fit, minmax(300px, 1fr))" }}>
        {/* members */}
        <SectionCard title="Members" icon={<Users className="w-4 h-4" />} right={<span className="text-xs text-gray-500">{g.members.length}</span>}>
          {g.members.length === 0 ? (
            <Empty>No members.</Empty>
          ) : (
            <ul className="divide-y divide-gray-800">
              {g.members.map((m) => (
                <li key={m.uid} className="flex items-center gap-3 py-2.5">
                  <Avatar name={m.name} size={8} />
                  <PlayerLink uid={m.uid} name={m.name} className="text-sm flex-1 truncate" />
                  <Badge color={m.rank === 1 ? "amber" : "gray"}>
                    {m.rank === 1 && <Crown className="w-3 h-3" />}
                    {gangRank(m.rank)}
                  </Badge>
                </li>
              ))}
            </ul>
          )}
        </SectionCard>

        {/* wars */}
        <SectionCard title="Gang Wars" icon={<Swords className="w-4 h-4" />} right={<span className="text-xs text-gray-500">{g.warIds.length}</span>}>
          {g.warIds.length === 0 ? (
            <Empty>No active wars.</Empty>
          ) : (
            <div className="flex flex-wrap gap-2">
              {g.warIds.map((wid) => (
                <Link key={wid} href={`/gameserver/gang-detail?id=${wid}`}>
                  <Badge color="red" className="hover:bg-red-900/50 transition cursor-pointer">
                    <Swords className="w-3 h-3" /> Gang #{wid}
                  </Badge>
                </Link>
              ))}
            </div>
          )}
        </SectionCard>
      </div>
    </div>
  );
}
