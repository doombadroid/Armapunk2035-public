import { notFound } from "next/navigation";
import Link from "next/link";
import {
  Home as HomeIcon, Car, Mail, Activity as ActivityIcon, Shield, Star,
  Ban, Crosshair, ChevronRight,
} from "lucide-react";
import { Card, SectionCard, StatRow, Badge, Avatar, PageHeader, Empty } from "@/components/ui";
import Collapsible from "@/components/Collapsible";
import CopyButton from "@/components/CopyButton";
import ActivityFeed from "@/components/ActivityFeed";
import {
  getPlayerDetail, getPlayerVehicles, getPlayerHouses, getPlayerActivity, getMailbox,
  isPlayerOnline, getAdminLog, getPlayerHousesAdmin,
} from "@/lib/queries";
import { fetchSteamProfile } from "@/lib/steam";
import { getSession } from "@/lib/session";
import { getActorPowers } from "@/lib/whitelist";
import { getBanStatus } from "@/lib/bans";
import BanControl from "@/components/BanControl";
import PlayerAdminPanel from "@/components/PlayerAdminPanel";
import HouseItemsPanel from "@/components/HouseItemsPanel";
import { decodeHouseInv } from "@/lib/houseInv";
import { ADMIN_WL_LEVEL, FACTIONS, maxGrant } from "@/lib/factions";
import { copRank, medicRank, gangRank, ADMIN_LEVELS } from "@/lib/ranks";
import { commas, money, nd, playtime, dateShort } from "@/lib/format";

export async function generateMetadata({
  searchParams,
}: { searchParams: Promise<{ playerid?: string }> }) {
  const { playerid } = await searchParams;
  if (!playerid) return { title: "Player" };
  const p = await getPlayerDetail(playerid);
  return { title: p ? `${p.name} · Player Detail` : "Player" };
}

const SIDE_COLORS: Record<string, string> = { civ: "text-th-500", cop: "text-blue-500", med: "text-emerald-500" };

export default async function PlayerDetailPage({
  searchParams,
}: { searchParams: Promise<{ playerid?: string }> }) {
  const { playerid } = await searchParams;
  if (!playerid) notFound();

  const p = await getPlayerDetail(playerid);
  if (!p) notFound();

  const session = await getSession();
  const [vehicles, houses, activity, mailbox, profile, powers, banStatus] = await Promise.all([
    getPlayerVehicles(p.uid),
    getPlayerHouses(p.uid),
    getPlayerActivity(p.uid, 40),
    getMailbox(p.uid),
    fetchSteamProfile(p.uid),
    session ? getActorPowers(session.uid) : Promise.resolve(null),
    getBanStatus(p.uid),
  ]);
  const isStaff = !!powers && (powers.isOwner || powers.adminlevel >= 1);
  const isAdmin = !!powers && (powers.isOwner || powers.adminlevel >= ADMIN_WL_LEVEL);
  // Mailbox + activity are private / meta-gameable: only the player themself or staff.
  const canSeePrivate = isStaff || (!!session && session.uid === p.uid);
  const banCurrent = banStatus
    ? { reason: banStatus.reason, by: banStatus.by, until: banStatus.until ? banStatus.until.toISOString() : null, clankr: banStatus.clankr }
    : null;

  const cop = p.copLevel > 0 ? copRank(p.copLevel) : null;
  const medic = p.medicLevel > 0 ? medicRank(p.medicLevel) : null;

  // admin edit panel: economy editors (adminlevel>=3) and/or faction-rank managers
  const canEcon = !!powers && (powers.isOwner || powers.adminlevel >= 3);
  const canManageAny = !!powers && (
    maxGrant(FACTIONS.police, powers) >= 0 || maxGrant(FACTIONS.medic, powers) >= 0 || maxGrant(FACTIONS.staff, powers) >= 0
  );
  const showAdmin = canEcon || canManageAny;
  const [online, adminLog] = showAdmin
    ? await Promise.all([isPlayerOnline(p.uid), getAdminLog(p.uid, 15)])
    : [false, []];

  // Admin+ house-item tool: load each owned house's stored inventory (decoded).
  const houseData = canEcon
    ? (await getPlayerHousesAdmin(p.uid)).map((h) => {
        const v = decodeHouseInv(h.vinv) ?? [[], 0], pn = decodeHouseInv(h.pinv) ?? [[], 0];
        return {
          oid: h.oid, id: h.id, label: h.classname || "House",
          vcap: h.vcap, phys_cap: h.phys_cap,
          virtual: { items: v[0], total: v[1] },
          physical: { items: pn[0], total: pn[1] },
        };
      })
    : [];

  return (
    <div>
      <PageHeader title="" back={{ href: "/players", label: "Back to Players" }} />

      {/* header card */}
      <Card className="p-6 mb-6">
        <div className="flex items-center gap-4">
          <Avatar name={p.name} size={14} src={profile.avatar} />
          <div className="min-w-0">
            <div className="flex items-center gap-2 flex-wrap">
              <h1 className="text-2xl sm:text-3xl font-black text-th-400 truncate">{p.name}</h1>
              {p.adminLevel > 0 && (
                <Badge color="red"><Shield className="w-3 h-3" /> {ADMIN_LEVELS[p.adminLevel] ?? `Admin ${p.adminLevel}`}</Badge>
              )}
              {p.betaTester && <Badge color="violet"><Star className="w-3 h-3" /> Beta</Badge>}
              {p.banned && <Badge color="red"><Ban className="w-3 h-3" /> Banned</Badge>}
            </div>
            <div className="flex items-center gap-2 mt-1">
              <p className="text-gray-500 text-xs font-mono">{p.uid}</p>
              <CopyButton value={p.uid} label="Copied Steam ID" />
              {p.discordId && <Badge color="blue">Discord Linked</Badge>}
            </div>
            {p.aliases.length > 1 && (
              <p className="text-xs text-gray-600 mt-1 truncate">
                aka {p.aliases.filter((a) => a !== p.name).slice(0, 5).join(", ")}
              </p>
            )}
          </div>
        </div>

        {/* role badges */}
        <div className="flex flex-wrap gap-2 mt-4 pt-4 border-t border-gray-800">
          {p.gangName && (
            <Badge color="green">
              <span className="text-gray-400 font-normal">Gang:&nbsp;</span>
              {p.gangName.trim()} · {gangRank(p.gangRank)}
            </Badge>
          )}
          {cop && <Badge color="blue"><span className="text-gray-400 font-normal">Cop:&nbsp;</span>{cop}{p.isMaxTac ? " · MaxTac" : ""}</Badge>}
          {medic && <Badge color="emerald"><span className="text-gray-400 font-normal">Trauma Team:&nbsp;</span>{medic}</Badge>}
          {p.isFirefighter && <Badge color="orange">Firefighter</Badge>}
          {p.bountyAmount > 0 && <Badge color="red"><Crosshair className="w-3 h-3" /> Bounty {money(p.bountyAmount)}</Badge>}
        </div>
      </Card>

      {/* public ban banner — reason + duration, shown to the player and anyone viewing */}
      {banStatus && (
        <div className="mb-6 rounded-xl border border-red-700/50 bg-red-900/20 px-5 py-4">
          <div className="flex items-center gap-2 text-red-300 font-bold text-sm mb-1"><Ban className="w-4 h-4" /> This account is banned</div>
          <p className="text-sm text-gray-300 break-words">{banStatus.reason || "No reason provided."}</p>
          <p className="text-xs text-gray-500 mt-1.5">
            {banStatus.until ? `Expires ${dateShort(banStatus.until)}` : "Permanent ban"}
            {banStatus.by ? ` · issued by ${banStatus.by}` : ""}
            {banStatus.clankr ? " · CLANKR" : ""}
          </p>
        </div>
      )}

      {/* staff ban control */}
      {isStaff && (
        <div className="mb-6">
          <BanControl uid={p.uid} isAdmin={isAdmin} canBan={isStaff} current={banCurrent} />
        </div>
      )}

      {/* admin edit panel — money / ranks / vehicles */}
      {showAdmin && powers && (
        <div className="mb-6">
          <PlayerAdminPanel p={p} vehicles={vehicles} powers={powers} online={online} log={adminLog} />
        </div>
      )}

      {/* Admin+ — place items into the player's house storage */}
      {canEcon && (
        <div className="mb-6">
          <SectionCard title="House Storage: Place Items">
            <HouseItemsPanel houses={houseData} ownerOnline={online} />
          </SectionCard>
        </div>
      )}

      {/* stat grid */}
      <div className="grid gap-6 mb-6" style={{ gridTemplateColumns: "repeat(auto-fit, minmax(240px, 1fr))" }}>
        <SectionCard title="Wallet">
          <StatRow label="Cash" value={money(p.cash)} />
          <StatRow label="Bank" value={money(p.bank)} />
          <StatRow label="New Drachma" value={nd(p.newDrachma)} />
          {p.wealth > 0 && <StatRow label="Wealth" value={money(p.wealth)} />}
        </SectionCard>

        <SectionCard title="Account">
          <StatRow label="Joined" value={dateShort(p.joined)} />
          <StatRow label="Last Seen" value={dateShort(p.lastSeen)} />
          <StatRow label="Gang" value={
            p.gangId ? (
              <Link href={`/gameserver/gang-detail?id=${p.gangId}`} className="text-th-400 hover:text-th-300 inline-flex items-center gap-1">
                {p.gangName?.trim()} <ChevronRight className="w-3 h-3" />
              </Link>
            ) : "—"
          } />
          <StatRow label="Vehicles" value={p.vehicleCount} />
          <StatRow label="Houses" value={p.houseCount} />
        </SectionCard>

        <SectionCard title="Experience & Playtime">
          <StatRow label="Civilian XP" value={<b>{commas(p.civExp)}</b>} />
          <StatRow label="Civilian Playtime" value={<b>{playtime(p.civTime)}</b>} />
          <StatRow label="Police XP" value={<b>{commas(p.copExp)}</b>} />
          <StatRow label="Police Playtime" value={<b>{playtime(p.copTime)}</b>} />
          <StatRow label="Trauma Team XP" value={<b>{commas(p.medExp)}</b>} />
          <StatRow label="Trauma Team Playtime" value={<b>{playtime(p.medTime)}</b>} />
          {p.infamyExp > 0 && <StatRow label="Infamy XP" value={<b>{commas(p.infamyExp)}</b>} />}
          {p.honorExp > 0 && <StatRow label="Honor XP" value={<b>{commas(p.honorExp)}</b>} />}
        </SectionCard>
      </div>

      {/* houses + vehicles */}
      <div className="grid gap-6 mb-6" style={{ gridTemplateColumns: "repeat(auto-fit, minmax(280px, 1fr))" }}>
        <Collapsible title="Houses" icon={<HomeIcon className="w-4 h-4 text-th-400" />} count={houses.length}>
          {houses.length === 0 ? (
            <Empty>No houses owned.</Empty>
          ) : (
            <ul className="divide-y divide-gray-800">
              {houses.map((h) => (
                <li key={h.id} className="flex items-center justify-between px-5 py-3 text-sm">
                  <span className="text-gray-300">{h.classname || "House"} <span className="text-gray-600">#{h.id}</span></span>
                  <span className="flex items-center gap-1.5">
                    {h.greenhouse ? <Badge color="green">Greenhouse</Badge> : null}
                    {h.barrel ? <Badge color="amber">Barrel</Badge> : null}
                    <span className="text-xs text-gray-500">cap {h.vcap}</span>
                  </span>
                </li>
              ))}
            </ul>
          )}
        </Collapsible>

        <Collapsible
          title="Vehicle Garage"
          icon={<Car className="w-4 h-4 text-th-400" />}
          count={vehicles.length}
          right={
            <span className="flex items-center gap-3 text-xs text-gray-500">
              <span><b className={SIDE_COLORS.civ}>{p.vehiclesBySide.civ}</b> Civ</span>
              <span><b className={SIDE_COLORS.cop}>{p.vehiclesBySide.cop}</b> Cop</span>
              <span><b className={SIDE_COLORS.med}>{p.vehiclesBySide.med}</b> TT</span>
            </span>
          }
        >
          {vehicles.length === 0 ? (
            <Empty>No vehicles.</Empty>
          ) : (
            <ul className="divide-y divide-gray-800 max-h-96 overflow-y-auto">
              {vehicles.map((v) => (
                <li key={v.id} className="flex items-center justify-between px-5 py-2.5 text-sm">
                  <span className="text-gray-300 truncate">{v.classname}</span>
                  <span className="flex items-center gap-2 shrink-0">
                    <Badge color={v.side === "cop" ? "blue" : v.side === "med" ? "emerald" : "th"}>{v.side}</Badge>
                    <span className="text-xs text-gray-600 font-mono">{v.customplate || v.plate}</span>
                  </span>
                </li>
              ))}
            </ul>
          )}
        </Collapsible>
      </div>

      {/* mailbox + activity — private / meta-gameable: self or staff only */}
      {canSeePrivate && (
      <div className="grid gap-6" style={{ gridTemplateColumns: "repeat(auto-fit, minmax(280px, 1fr))" }}>
        <Collapsible title="Mailbox" icon={<Mail className="w-4 h-4 text-th-400" />} count={mailbox.length}>
          {mailbox.length === 0 ? (
            <Empty>No mailbox items.</Empty>
          ) : (
            <ul className="divide-y divide-gray-800 max-h-96 overflow-y-auto">
              {mailbox.map((m, i) => (
                <li key={i} className="px-5 py-2.5 text-sm text-gray-300 break-words font-mono text-xs">
                  {JSON.stringify(m)}
                </li>
              ))}
            </ul>
          )}
        </Collapsible>

        <Collapsible title="Recent Activity" icon={<ActivityIcon className="w-4 h-4 text-th-400" />} count={activity.length} defaultOpen>
          <div className="px-5 py-2 max-h-96 overflow-y-auto">
            <ActivityFeed rows={activity} showPlayer={false} />
          </div>
        </Collapsible>
      </div>
      )}
    </div>
  );
}
