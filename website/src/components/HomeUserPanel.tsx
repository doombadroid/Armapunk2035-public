import Link from "next/link";
import {
  ShieldCheck, Crown, DollarSign, Landmark, Skull, Zap, Shield, Stethoscope,
  Trophy, Flame, ChevronRight, MessageCircle, Ticket as TicketIcon,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { getPlayerDetail, leaderboardRank } from "@/lib/queries";
import { listTickets } from "@/lib/web";
import { lbMetric, fmtLbValue } from "@/lib/leaderboards";
import { copRank } from "@/lib/ranks";
import { moneyAbbrev, abbrev, commas, nd, playtime, dateShort, relative } from "@/lib/format";
import { Avatar, Badge } from "@/components/ui";
import type { Session } from "@/lib/session";

const DISCORD_URL = process.env.NEXT_PUBLIC_DISCORD_URL || "https://discord.gg/";

// curated "Your Rankings" metrics (one leaderboardRank query each)
const RANK_METRICS: { key: string; icon: LucideIcon; color: string }[] = [
  { key: "wealth", icon: Landmark, color: "text-green-400" },
  { key: "new_drachma", icon: Skull, color: "text-red-400" },
  { key: "civ", icon: Zap, color: "text-amber-400" },
  { key: "cop", icon: Shield, color: "text-blue-400" },
  { key: "med", icon: Stethoscope, color: "text-green-400" },
  { key: "honor", icon: Trophy, color: "text-purple-400" },
  { key: "infamy", icon: Flame, color: "text-orange-400" },
  { key: "wanted", icon: Skull, color: "text-purple-400" },
];
const STATUS_COLOR: Record<string, "amber" | "blue" | "gray"> = { open: "amber", answered: "blue", closed: "gray" };

function Bar({ icon: Icon, label, value, pct, color }: { icon: LucideIcon; label: string; value: string; pct: number; color: string }) {
  return (
    <div className="flex items-center gap-2.5">
      <Icon className={`w-4 h-4 flex-shrink-0 ${color}`} />
      <div className="flex-1 min-w-0">
        <div className="flex items-baseline justify-between gap-2">
          <span className="text-xs text-gray-400 truncate">{label}</span>
          <span className={`text-xs font-bold tabular-nums flex-shrink-0 ${color}`}>{value}</span>
        </div>
        <div className="h-1.5 mt-1 bg-gray-800 rounded-full overflow-hidden">
          <div className={`h-full rounded-full ${color.replace("text-", "bg-")} transition-all duration-700`} style={{ width: `${Math.max(0, Math.min(100, pct))}%` }} />
        </div>
      </div>
    </div>
  );
}

export default async function HomeUserPanel({ session }: { session: Session }) {
  const [p, tickets, ...ranks] = await Promise.all([
    getPlayerDetail(session.uid),
    listTickets({ playerid: session.uid }),
    ...RANK_METRICS.map((m) => leaderboardRank(m.key, session.uid)),
  ]);

  const cop = copRank(session.copLevel);
  const linked = !!p?.discordId;

  const cash = Number(p?.cash ?? 0), bank = Number(p?.bank ?? 0), drachma = Number(p?.newDrachma ?? 0);
  const worth = Number(p?.wealth ?? cash + bank);   // ND is its own denomination -- never summed into $ net worth
  const moneyMax = Math.max(1, cash, bank);
  const civ = Number(p?.civExp ?? 0), copx = Number(p?.copExp ?? 0), medx = Number(p?.medExp ?? 0);
  const xpTotal = civ + copx + medx, xpMax = Math.max(1, civ, copx, medx);

  return (
    <>
      {/* welcome hero */}
      <section className="relative py-12 px-4 text-center overflow-hidden">
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[700px] h-[340px] bg-th-500/10 rounded-full blur-3xl pointer-events-none" />
        <div className="relative">
          <div className="flex justify-center mb-4">
            <Avatar name={session.name} src={session.avatar} size={20} />
          </div>
          <p className="text-th-500 text-xs font-bold uppercase tracking-[0.3em] mb-2">Welcome back</p>
          <h1 className="text-3xl sm:text-4xl md:text-5xl font-black text-white mb-4 leading-tight tracking-tight break-words px-2">{session.name}</h1>
          <div className="flex items-center justify-center gap-2 flex-wrap">
            {cop && <span className="flex items-center gap-1 text-xs bg-blue-900/30 text-blue-300 border border-blue-700/40 px-2.5 py-1 rounded-full font-bold"><ShieldCheck className="w-3 h-3" /> {cop}</span>}
            {session.adminLevel > 0 && <span className="flex items-center gap-1 text-xs bg-red-900/30 text-red-300 border border-red-700/40 px-2.5 py-1 rounded-full font-bold"><ShieldCheck className="w-3 h-3" /> Staff</span>}
            {p?.gangName && <Link href={`/gameserver/gang-detail?id=${p.gangId}`} className="flex items-center gap-1 text-xs bg-amber-900/30 text-amber-300 border border-amber-700/40 px-2.5 py-1 rounded-full font-bold hover:bg-amber-900/50 transition"><Crown className="w-3 h-3" /> {p.gangName.trim()}</Link>}
          </div>
        </div>
      </section>

      <section className="max-w-7xl mx-auto px-4 space-y-6 pb-4">
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* My Stats */}
          <div className="lg:col-span-2">
            <div className="bg-gray-900 border border-th-700/30 rounded-xl p-5 h-full">
              <h3 className="text-sm font-bold text-th-400 uppercase tracking-widest mb-4">My Stats</h3>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-6 mb-5">
                <div>
                  <p className="text-xs text-gray-500 uppercase tracking-wider mb-1">Finances</p>
                  <p className="text-2xl font-black tabular-nums mb-0.5 text-green-400">{moneyAbbrev(worth)}</p>
                  <p className="text-[11px] text-gray-600 mb-3">Net Worth</p>
                  <div className="space-y-3">
                    <Bar icon={DollarSign} label="Cash" value={moneyAbbrev(cash)} pct={(cash / moneyMax) * 100} color="text-green-400" />
                    <Bar icon={Landmark} label="Bank" value={moneyAbbrev(bank)} pct={(bank / moneyMax) * 100} color="text-blue-400" />
                    <Bar icon={Skull} label="New Drachma" value={nd(drachma)} pct={drachma > 0 ? 100 : 0} color="text-red-400" />
                  </div>
                </div>
                <div>
                  <p className="text-xs text-gray-500 uppercase tracking-wider mb-1">Experience</p>
                  <p className="text-2xl font-black tabular-nums mb-0.5 text-amber-400">{abbrev(xpTotal)}</p>
                  <p className="text-[11px] text-gray-600 mb-3">Total Experience</p>
                  <div className="space-y-3">
                    <Bar icon={Zap} label="Civilian" value={abbrev(civ)} pct={(civ / xpMax) * 100} color="text-amber-400" />
                    <Bar icon={Shield} label="Police" value={abbrev(copx)} pct={(copx / xpMax) * 100} color="text-blue-400" />
                    <Bar icon={Stethoscope} label="Medic" value={abbrev(medx)} pct={(medx / xpMax) * 100} color="text-green-400" />
                  </div>
                </div>
              </div>
              <div>
                {[
                  ["Gang", p?.gangName ? <Link href={`/gameserver/gang-detail?id=${p.gangId}`} className="text-th-400 hover:text-th-300 transition">{p.gangName.trim()}</Link> : <span className="text-gray-500">None</span>],
                  ["Vehicles", commas(p?.vehicleCount ?? 0)],
                  ["Houses", commas(p?.houseCount ?? 0)],
                  ["Playtime", playtime((p?.civTime ?? 0) + (p?.copTime ?? 0) + (p?.medTime ?? 0))],
                  ["Last Seen", p?.lastSeen ? dateShort(p.lastSeen) : "—"],
                ].map(([k, v], i) => (
                  <div key={i} className="flex justify-between items-center py-2 border-b border-gray-800 last:border-0">
                    <span className="text-xs text-gray-500 uppercase tracking-wider">{k}</span>
                    <span className="text-sm text-gray-200">{v}</span>
                  </div>
                ))}
              </div>
            </div>
          </div>

          {/* Recent Tickets + Discord CTA */}
          <div className="bg-gray-900 border border-th-700/30 rounded-xl p-5 flex flex-col h-full">
            <div className="flex items-center justify-between mb-2 flex-shrink-0">
              <h3 className="text-sm font-bold text-th-400 uppercase tracking-widest flex items-center gap-2"><TicketIcon className="w-4 h-4" /> Recent Tickets</h3>
              <Link href="/support-tickets" className="text-xs text-th-500 hover:text-th-400 flex items-center gap-0.5 transition flex-shrink-0">View all <ChevronRight className="w-3 h-3" /></Link>
            </div>
            <div className="flex-1 min-h-0">
              {tickets.length === 0 ? (
                <p className="text-xs text-gray-600 py-4">No tickets yet. <Link href="/support-tickets/new" className="text-th-500 hover:text-th-400">Open one</Link>.</p>
              ) : (
                <ul className="divide-y divide-gray-800/60 -mx-5">
                  {tickets.slice(0, 5).map((t) => (
                    <li key={t.id}>
                      <Link href={`/support-tickets/${t.id}`} className="flex items-start gap-2.5 px-5 py-2.5 hover:bg-gray-800/40 transition">
                        <TicketIcon className="w-4 h-4 text-th-400 flex-shrink-0 mt-0.5" />
                        <div className="flex-1 min-w-0">
                          <p className="text-sm text-gray-200 truncate">#{t.id} · {t.subject}</p>
                          <div className="flex items-center gap-1.5 mt-1 flex-wrap">
                            <Badge color={STATUS_COLOR[t.status] ?? "gray"}>{t.status}</Badge>
                            <span className="text-[10px] text-gray-600 ml-auto whitespace-nowrap">{relative(t.updated_at)}</span>
                          </div>
                        </div>
                      </Link>
                    </li>
                  ))}
                </ul>
              )}
            </div>
            {!linked && (
              <div className="pt-2 flex-shrink-0">
                <div className="bg-indigo-950/30 border border-indigo-700/40 rounded-lg overflow-hidden">
                  <div className="flex items-center gap-2 px-4 py-3 border-b border-indigo-700/40 bg-indigo-900/30">
                    <MessageCircle className="w-4 h-4 flex-shrink-0 text-indigo-400" />
                    <span className="text-xs font-bold uppercase tracking-wider text-indigo-300">Link Your Discord</span>
                  </div>
                  <div className="px-4 py-4 space-y-3">
                    <ul className="space-y-1.5 text-sm text-gray-300">
                      <li className="flex gap-2"><span className="text-indigo-400">•</span><span>Get an instant Discord DM when staff reply to your ticket</span></li>
                      <li className="flex gap-2"><span className="text-indigo-400">•</span><span>Reply to your tickets straight from Discord — just DM LoonyBot</span></li>
                    </ul>
                    <a href={DISCORD_URL} target="_blank" rel="noopener noreferrer" className="inline-block text-xs font-semibold text-indigo-400 hover:text-indigo-300 transition">
                      Join our Discord &amp; use <span className="font-mono">!link</span> to connect →
                    </a>
                  </div>
                </div>
              </div>
            )}
          </div>
        </div>

        {/* Your Rankings */}
        <div>
          <h2 className="text-sm font-bold text-gray-400 uppercase tracking-widest mb-3">Your Rankings</h2>
          <div className="flex gap-4 overflow-x-auto pb-2">
            {RANK_METRICS.map((rm, i) => {
              const r = ranks[i]; const m = lbMetric(rm.key); const Icon = rm.icon;
              return (
                <Link key={rm.key} href={`/leaderboard?metric=${rm.key}`}
                  className="flex-shrink-0 w-40 block bg-gray-900 border border-th-700/30 hover:border-th-600/50 rounded-xl p-4 transition-all hover:bg-gray-800/60">
                  <div className="flex items-center gap-2 mb-2 min-w-0">
                    <Icon className={`w-4 h-4 flex-shrink-0 ${rm.color}`} />
                    <span className="text-xs font-bold text-gray-400 uppercase tracking-wide truncate">{m.label}</span>
                  </div>
                  <p className="text-lg font-black text-gray-100 tabular-nums mb-1.5 truncate">{r ? fmtLbValue(m, r.value) : "—"}</p>
                  {r ? <p className="text-xs truncate"><span className="text-th-400 font-semibold">Rank #{commas(r.rank)}</span></p>
                     : <p className="text-xs text-gray-600">Unranked</p>}
                </Link>
              );
            })}
          </div>
        </div>
      </section>
    </>
  );
}
