import { notFound, redirect } from "next/navigation";
import Link from "next/link";
import { ShieldCheck, Search, Crown } from "lucide-react";
import { Card, SectionCard, Badge, Avatar, PlayerLink, PageHeader, Empty } from "@/components/ui";
import LiveAuditLog from "@/components/LiveAuditLog";
import { getSession } from "@/lib/session";
import {
  FACTIONS, maxGrant, manageableFactions, isAdminPlus, type Faction, type ActorPowers,
} from "@/lib/factions";
import { getActorPowers, getFactionRoster, searchForFaction, getAuditLog, rankName } from "@/lib/whitelist";
import { setFactionRank, setFactionSub } from "@/lib/actions";

export const dynamic = "force-dynamic";
export const metadata = { title: "Faction Whitelist" };

function RankSet({ f, target, current, mg }: { f: Faction; target: string; current: number; mg: number }) {
  const opts = Array.from({ length: mg + 1 }, (_, i) => i);
  return (
    <form action={setFactionRank} className="flex items-center gap-2">
      <input type="hidden" name="faction" value={f.key} />
      <input type="hidden" name="target" value={target} />
      <select
        name="new_rank"
        defaultValue={current}
        className="bg-gray-800 border border-gray-700 rounded px-2 py-1 text-xs text-gray-100"
      >
        {opts.map((r) => (
          <option key={r} value={r}>
            {r === 0 ? "0: Civilian (remove)" : `${r}: ${f.ranks[r]}`}
          </option>
        ))}
      </select>
      <button
        type="submit"
        className="px-2.5 py-1 rounded bg-th-600/20 border border-th-700/40 text-th-300 text-xs font-bold hover:bg-th-600/30 transition"
      >
        Set
      </button>
    </form>
  );
}

function SubToggle({ f, uid, sub, label, on }: { f: Faction; uid: string; sub: string; label: string; on: boolean }) {
  return (
    <form action={setFactionSub}>
      <input type="hidden" name="faction" value={f.key} />
      <input type="hidden" name="target" value={uid} />
      <input type="hidden" name="sub" value={sub} />
      <input type="hidden" name="value" value={on ? 0 : 1} />
      <button
        title={on ? `Remove ${label}` : `Grant ${label}`}
        className={`px-2 py-1 rounded text-xs font-bold border transition ${
          on
            ? "bg-green-900/40 border-green-600/50 text-green-300"
            : "bg-gray-800 border-gray-700 text-gray-500 hover:text-gray-300 hover:border-gray-600"
        }`}
      >
        {on ? "✓ " : ""}{label}
      </button>
    </form>
  );
}

function ManageRow({
  f, uid, name, rank, mg, subs,
}: { f: Faction; uid: string; name: string; rank: number; mg: number; subs: Record<string, number> }) {
  const manageable = rank <= mg;
  return (
    <div className="flex items-center gap-3 px-4 py-2.5 flex-wrap">
      <Avatar name={name} size={8} />
      <div className="min-w-0 flex-1">
        <PlayerLink uid={uid} name={name} className="text-sm truncate" />
        <p className="text-xs text-gray-500">{rankName(f, rank)}</p>
      </div>
      {!manageable ? (
        <Badge color="gray">outranks you</Badge>
      ) : (
        <div className="flex items-center gap-1.5 flex-wrap justify-end">
          <RankSet f={f} target={uid} current={rank} mg={mg} />
          {f.subs.map((s) => (
            <SubToggle key={s.key} f={f} uid={uid} sub={s.key} label={s.label} on={!!subs[s.key]} />
          ))}
        </div>
      )}
    </div>
  );
}

export default async function WhitelistPage({
  searchParams,
}: { searchParams: Promise<{ faction?: string; q?: string }> }) {
  const session = await getSession();
  if (!session) redirect("/login");

  const powers: ActorPowers = await getActorPowers(session.uid);
  const admin = isAdminPlus(powers);
  const mf = manageableFactions(powers);
  if (mf.length === 0 && !admin) notFound(); // no whitelist access at all

  // only show tabs the viewer can actually manage (Server Staff = owner only).
  const visible: Faction[] = mf;

  const sp = await searchParams;
  const reqKey = sp.faction && FACTIONS[sp.faction] ? sp.faction : "";
  const activeKey = reqKey && visible.some((f) => f.key === reqKey) ? reqKey : visible[0].key;
  const f = FACTIONS[activeKey];
  const mg = maxGrant(f, powers);
  const term = (sp.q ?? "").trim();

  const [results, roster, audit] = await Promise.all([
    term ? searchForFaction(f, term, 25) : Promise.resolve([]),
    getFactionRoster(f),
    getAuditLog(admin ? null : mf.map((x) => x.key), 50),
  ]);

  const roleLabel = powers.isOwner ? "Owner" : admin ? `Admin L${powers.adminlevel}` : "Faction Lead";

  return (
    <div>
      <PageHeader title="Faction Whitelist" />

      <Card className="p-4 mb-5 flex items-center justify-between flex-wrap gap-2">
        <div className="flex items-center gap-2 text-sm text-gray-300">
          <ShieldCheck className="w-4 h-4 text-th-400" />
          You are <Badge color={powers.isOwner ? "amber" : admin ? "red" : "blue"}>{roleLabel}</Badge>
          {admin && <span className="text-xs text-gray-500">— may set any rank in any faction</span>}
        </div>
        <div className="text-xs text-gray-500">
          In <b className="text-th-400">{f.label}</b> you can grant up to{" "}
          <b className="text-gray-200">{mg >= 0 ? rankName(f, mg) : "—"}</b>
        </div>
      </Card>

      {/* faction tabs */}
      <div className="flex flex-wrap gap-1.5 mb-5">
        {visible.map((vf) =>
          vf.key === activeKey ? (
            <span key={vf.key} className="px-3 py-1.5 rounded-lg text-xs font-bold bg-th-600/20 border border-th-700/40 text-th-300">
              {vf.label}
            </span>
          ) : (
            <Link key={vf.key} href={`/whitelist?faction=${vf.key}`} className="px-3 py-1.5 rounded-lg text-xs font-bold bg-gray-900 border border-gray-800 text-gray-400 hover:text-gray-200 hover:border-gray-700 transition">
              {vf.label}
            </Link>
          )
        )}
      </div>

      <div className="grid gap-6 lg:grid-cols-3">
        <div className="lg:col-span-2 space-y-6">
          {/* search + assign */}
          <SectionCard title={`Whitelist a player into ${f.label}`} icon={<Search className="w-4 h-4" />}>
            <form method="get" className="flex items-center gap-2 mb-3">
              <input type="hidden" name="faction" value={f.key} />
              <input
                name="q"
                defaultValue={term}
                placeholder="Search by name or Steam ID…"
                className="flex-1 bg-gray-800 border border-gray-700 rounded px-3 py-2 text-sm text-gray-100"
              />
              <button className="px-4 py-2 rounded bg-th-600/20 border border-th-700/40 text-th-300 text-sm font-bold">Search</button>
            </form>
            {term && (
              results.length === 0 ? <Empty>No players matched.</Empty> : (
                <div className="divide-y divide-gray-800 border-t border-gray-800">
                  {results.map((r) => (
                    <ManageRow key={r.uid} f={f} uid={r.uid} name={r.name} rank={r.rank} mg={mg} subs={r.subs} />
                  ))}
                </div>
              )
            )}
          </SectionCard>

          {/* current roster */}
          <SectionCard title={`${f.label} Roster`} icon={<ShieldCheck className="w-4 h-4" />} right={<span className="text-xs text-gray-500">{roster.length}</span>}>
            {roster.length === 0 ? <Empty>No members yet.</Empty> : (
              <div className="divide-y divide-gray-800 border-t border-gray-800 max-h-[32rem] overflow-y-auto">
                {roster.map((m) => (
                  <ManageRow key={m.uid} f={f} uid={m.uid} name={m.name} rank={m.rank} mg={mg} subs={m.subs} />
                ))}
              </div>
            )}
          </SectionCard>
        </div>

        {/* audit log */}
        <div>
          <Card className="p-4">
            <div className="flex items-center gap-2 mb-1">
              {powers.isOwner && <Crown className="w-4 h-4 text-amber-400" />}
              <h3 className="text-sm font-bold text-th-400 uppercase tracking-widest">
                {admin ? "All Whitelist Activity" : "Your Faction Activity"}
              </h3>
            </div>
            <LiveAuditLog initial={audit as never} />
          </Card>
        </div>
      </div>
    </div>
  );
}
