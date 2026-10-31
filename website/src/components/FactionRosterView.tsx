import Link from "next/link";
import { Search, UserPlus, ShieldCheck, History, Ban, Trash2, ArrowRight } from "lucide-react";
import { Card, SectionCard, Badge, Avatar, PlayerLink, Empty } from "@/components/ui";
import CopyId from "@/components/CopyId";
import { getSession } from "@/lib/session";
import { FACTIONS, maxGrant, type Faction, type ActorPowers } from "@/lib/factions";
import {
  getActorPowers, getFactionRosterTable, searchForFaction, rankName, getAuditLog, getFactionBlacklist,
  type RosterTableRow, type FactionSearchHit, type AuditRow, type BlacklistRow,
} from "@/lib/whitelist";
import { setFactionRank, setFactionSub, addBlacklist, removeBlacklist } from "@/lib/actions";
import { commas, dateLong, relative } from "@/lib/format";

// per-faction accent for the rank pill (semantic, not themed)
const RANK_BADGE: Record<string, "blue" | "emerald"> = { police: "blue", medic: "emerald" };

function RankSet({ f, uid, current, mg }: { f: Faction; uid: string; current: number; mg: number }) {
  const opts = Array.from({ length: mg + 1 }, (_, i) => i);
  return (
    <form action={setFactionRank} className="flex items-center gap-1.5">
      <input type="hidden" name="faction" value={f.key} />
      <input type="hidden" name="target" value={uid} />
      <select
        name="new_rank"
        defaultValue={current >= 1 && current <= mg ? current : 0}
        className="bg-gray-800 border border-gray-700 rounded px-2 py-1 text-xs text-gray-100 max-w-[8.5rem]"
      >
        {opts.map((r) => (
          <option key={r} value={r}>{r === 0 ? "Remove" : `${r} · ${f.ranks[r]}`}</option>
        ))}
      </select>
      <button className="px-2 py-1 rounded bg-th-600/20 border border-th-700/40 text-th-300 text-xs font-bold hover:bg-th-600/30 transition">
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
        className={`px-1.5 py-0.5 rounded text-[11px] font-bold border transition ${
          on
            ? "bg-purple-600/20 border-purple-600/40 text-purple-300"
            : "bg-gray-800 border-gray-700 text-gray-500 hover:text-gray-300 hover:border-gray-600"
        }`}
      >
        {on ? "✓ " : ""}{label}
      </button>
    </form>
  );
}

export default async function FactionRosterView({
  faction, sp,
}: { faction: string; sp: { q?: string; rank?: string; addq?: string } }) {
  const f = FACTIONS[faction];
  const badge = RANK_BADGE[f.key] ?? "blue";

  const session = await getSession();
  const powers: ActorPowers | null = session ? await getActorPowers(session.uid) : null;
  const mg = powers ? maxGrant(f, powers) : -1;
  const canManage = mg >= 0;
  const myRank = powers?.ranks[f.key] ?? 0;

  const term = (sp.q ?? "").trim().toLowerCase();
  const rankFilter = sp.rank && sp.rank !== "all" ? Number(sp.rank) : null;
  const addTerm = (sp.addq ?? "").trim();

  const [all, addHits, audit, blacklist] = await Promise.all([
    getFactionRosterTable(f),
    canManage && addTerm ? searchForFaction(f, addTerm, 20) : Promise.resolve([] as FactionSearchHit[]),
    canManage ? getAuditLog([f.key], 30) : Promise.resolve([] as AuditRow[]),
    canManage ? getFactionBlacklist(f.key) : Promise.resolve([] as BlacklistRow[]),
  ]);

  const rows = all.filter((r) => {
    if (rankFilter != null && r.rank !== rankFilter) return false;
    if (term && !(`${r.name} ${r.uid} ${rankName(f, r.rank)}`.toLowerCase().includes(term))) return false;
    return true;
  });

  const rankOpts = Object.keys(f.ranks).map(Number).sort((a, b) => b - a);

  return (
    <div>
      {/* sub-header: counts + who you are */}
      <div className="flex items-center justify-between gap-3 flex-wrap mb-4">
        <p className="text-xs text-gray-500">
          {canManage && myRank > 0 && (
            <>Logged in as <span className="text-th-400 font-semibold">{rankName(f, myRank)}</span> · </>
          )}
          {all.length} on roster{rows.length !== all.length ? ` · ${rows.length} shown` : ""}
        </p>
        {canManage && (
          <Link
            href="?addq=#add"
            className="px-3 py-1.5 bg-th-600 hover:bg-th-700 text-white text-xs font-semibold rounded-lg transition inline-flex items-center gap-1.5"
          >
            <UserPlus className="w-3.5 h-3.5" /> Add / Manage Officer
          </Link>
        )}
      </div>

      {/* search + rank filter */}
      <form method="get" className="flex gap-2 flex-wrap mb-4">
        <div className="relative flex-1 min-w-[12rem]">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-gray-500 pointer-events-none" />
          <input
            name="q" defaultValue={sp.q ?? ""}
            placeholder="Search by name, Player ID, or rank…"
            className="w-full pl-8 pr-3 py-2 bg-gray-800 border border-th-700/30 rounded-lg text-sm text-gray-100 placeholder-gray-500 focus:outline-none focus:border-th-500 transition"
          />
        </div>
        <select name="rank" defaultValue={sp.rank ?? "all"} className="px-3 py-2 bg-gray-800 border border-th-700/30 rounded-lg text-sm text-gray-200 focus:outline-none focus:border-th-500">
          <option value="all">All Ranks</option>
          {rankOpts.map((r) => <option key={r} value={r}>{f.ranks[r]}</option>)}
        </select>
        <button className="px-4 py-2 bg-th-600 hover:bg-th-700 text-white text-sm font-semibold rounded-lg transition">Search</button>
      </form>

      {/* roster table */}
      {rows.length === 0 ? (
        <Card className="p-0"><Empty>No members match.</Empty></Card>
      ) : (
        <Card className="overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full text-xs">
              <thead className="bg-gray-950 border-b border-th-800/30">
                <tr className="text-th-400 font-semibold">
                  <th className="px-3 py-2.5 text-left">Rank</th>
                  <th className="px-3 py-2.5 text-left">Name</th>
                  <th className="px-3 py-2.5 text-left">Player ID</th>
                  {f.subs.length > 0 && <th className="px-3 py-2.5 text-center">Roles</th>}
                  <th className="px-3 py-2.5 text-right">{f.key === "police" ? "Cop" : "TT"} XP</th>
                  <th className="px-3 py-2.5 text-left hidden md:table-cell">Last Seen</th>
                  {canManage && <th className="px-3 py-2.5 text-right">Manage</th>}
                </tr>
              </thead>
              <tbody>
                {rows.map((r) => {
                  const editable = canManage && r.rank <= mg;
                  return (
                    <tr key={r.uid} className="border-b border-gray-800/60 hover:bg-gray-800/30 transition">
                      <td className="px-3 py-2.5">
                        <div className="flex items-center gap-1.5">
                          <Badge color={badge}>{rankName(f, r.rank)}</Badge>
                          {r.retired > 0 && <Badge color="gray">Retired</Badge>}
                        </div>
                      </td>
                      <td className="px-3 py-2.5">
                        <div className="flex items-center gap-2">
                          <Avatar name={r.name} size={7} />
                          <PlayerLink uid={r.uid} name={r.name} className="font-semibold" />
                        </div>
                      </td>
                      <td className="px-3 py-2.5">
                        <div className="flex items-center gap-1.5">
                          <span className="font-mono text-gray-400">{r.uid}</span>
                          <CopyId value={r.uid} />
                        </div>
                      </td>
                      {f.subs.length > 0 && (
                        <td className="px-3 py-2.5 text-center">
                          <div className="flex items-center justify-center gap-1">
                            {f.subs.filter((s) => r.subs[s.key]).map((s) => (
                              <span key={s.key} className="px-1.5 py-0.5 rounded text-[11px] font-bold bg-purple-600/20 text-purple-300">{s.label}</span>
                            ))}
                            {f.subs.every((s) => !r.subs[s.key]) && <span className="text-gray-600">—</span>}
                          </div>
                        </td>
                      )}
                      <td className="px-3 py-2.5 text-right text-gray-300 tabular-nums">{commas(r.exp)}</td>
                      <td className="px-3 py-2.5 text-gray-500 hidden md:table-cell whitespace-nowrap">{r.lastSeen ? dateLong(r.lastSeen) : "—"}</td>
                      {canManage && (
                        <td className="px-3 py-2.5">
                          {editable ? (
                            <div className="flex items-center gap-1.5 justify-end flex-wrap">
                              <RankSet f={f} uid={r.uid} current={r.rank} mg={mg} />
                              {f.subs.map((s) => (
                                <SubToggle key={s.key} f={f} uid={r.uid} sub={s.key} label={s.label} on={!!r.subs[s.key]} />
                              ))}
                            </div>
                          ) : (
                            <div className="text-right"><Badge color="gray">outranks you</Badge></div>
                          )}
                        </td>
                      )}
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </Card>
      )}

      {/* add / manage officer (whitelisters) */}
      {canManage && sp.addq !== undefined && (
        <div id="add" className="mt-6">
          <SectionCard
            title={`Add or re-rank a ${f.label} officer`}
            icon={<Search className="w-4 h-4" />}
            right={<span className="text-xs text-gray-500">grant up to {mg >= 0 ? rankName(f, mg) : "—"}</span>}
          >
            <form method="get" className="flex items-center gap-2 mb-3">
              <input type="hidden" name="q" value={sp.q ?? ""} />
              <input type="hidden" name="rank" value={sp.rank ?? "all"} />
              <input
                name="addq" defaultValue={addTerm}
                placeholder="Search ANY player by name or Steam ID…"
                className="flex-1 bg-gray-800 border border-gray-700 rounded px-3 py-2 text-sm text-gray-100"
              />
              <button className="px-4 py-2 rounded bg-th-600/20 border border-th-700/40 text-th-300 text-sm font-bold">Search</button>
            </form>
            {addTerm && (
              addHits.length === 0 ? <Empty>No players matched.</Empty> : (
                <div className="divide-y divide-gray-800 border-t border-gray-800">
                  {addHits.map((h) => {
                    const editable = h.rank <= mg;
                    return (
                      <div key={h.uid} className="flex items-center gap-3 px-1 py-2.5 flex-wrap">
                        <Avatar name={h.name} size={8} />
                        <div className="min-w-0 flex-1">
                          <PlayerLink uid={h.uid} name={h.name} className="text-sm truncate" />
                          <p className="text-xs text-gray-500">{rankName(f, h.rank)}</p>
                        </div>
                        {editable ? (
                          <div className="flex items-center gap-1.5 flex-wrap justify-end">
                            <RankSet f={f} uid={h.uid} current={h.rank} mg={mg} />
                            {f.subs.map((s) => (
                              <SubToggle key={s.key} f={f} uid={h.uid} sub={s.key} label={s.label} on={!!h.subs[s.key]} />
                            ))}
                          </div>
                        ) : <Badge color="gray">outranks you</Badge>}
                      </div>
                    );
                  })}
                </div>
              )
            )}
          </SectionCard>
        </div>
      )}

      {/* command/admin: promotion-demotion audit + blacklist */}
      {canManage && (
        <div className="grid gap-4 lg:grid-cols-2 mt-6">
          <SectionCard title="Recent Promotions & Demotions" icon={<History className="w-4 h-4" />}>
            {audit.length === 0 ? <Empty>No rank changes logged.</Empty> : (
              <ul className="divide-y divide-gray-800 max-h-80 overflow-y-auto text-xs">
                {audit.map((a) => (
                  <li key={a.id} className="py-2 flex items-center gap-2 flex-wrap">
                    <Badge color={a.action === "promote" || a.action === "whitelist" ? "green" : a.action === "remove" ? "red" : "amber"}>{a.action}</Badge>
                    <span className="text-gray-300 font-semibold">{a.target_name || a.target_id}</span>
                    <span className="text-gray-500 inline-flex items-center gap-1">
                      {rankName(f, a.old_rank)} <ArrowRight className="w-3 h-3" /> {rankName(f, a.new_rank)}
                    </span>
                    <span className="text-gray-600 ml-auto">by {a.actor_name} · {relative(a.ts)}</span>
                  </li>
                ))}
              </ul>
            )}
          </SectionCard>

          <SectionCard title={`${f.label} Blacklist`} icon={<Ban className="w-4 h-4" />} right={<span className="text-xs text-gray-500">{blacklist.length}</span>}>
            <form action={addBlacklist} className="flex gap-2 flex-wrap mb-3">
              <input type="hidden" name="faction" value={f.key} />
              <input name="target" required placeholder="Steam ID (17 digits)" className="flex-1 min-w-[10rem] bg-gray-800 border border-gray-700 rounded px-2 py-1 text-sm text-gray-100 font-mono" />
              <input name="reason" placeholder="Reason" className="flex-1 min-w-[8rem] bg-gray-800 border border-gray-700 rounded px-2 py-1 text-sm text-gray-100" />
              <button className="px-3 py-1 rounded bg-red-600/20 border border-red-700/40 text-red-300 text-xs font-bold hover:bg-red-600/30 transition">Blacklist</button>
            </form>
            {blacklist.length === 0 ? <Empty>No one blacklisted.</Empty> : (
              <ul className="divide-y divide-gray-800 max-h-72 overflow-y-auto text-xs">
                {blacklist.map((b) => (
                  <li key={b.id} className="py-2 flex items-center gap-2">
                    <div className="min-w-0 flex-1">
                      <PlayerLink uid={b.playerid} name={b.name || b.playerid} className="font-semibold" />
                      {b.reason && <span className="text-gray-500"> — {b.reason}</span>}
                      <p className="text-gray-600">by {b.added_by_name} · {relative(b.created_at)}</p>
                    </div>
                    <form action={removeBlacklist}>
                      <input type="hidden" name="id" value={b.id} />
                      <button title="Remove from blacklist" className="p-1 text-gray-500 hover:text-green-300 transition"><Trash2 className="w-3.5 h-3.5" /></button>
                    </form>
                  </li>
                ))}
              </ul>
            )}
          </SectionCard>
        </div>
      )}
    </div>
  );
}
