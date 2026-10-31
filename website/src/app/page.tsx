import Link from "next/link";
import {
  Users, DollarSign, Swords, HandCoins, Skull, Zap, Shield, Plus, Award,
  ChevronRight, Trophy, TrendingUp, Clock, Library, BarChart3, Ticket, Vote, BookOpen, Activity,
} from "lucide-react";
import { SectionCard, PlayerLink, Badge } from "@/components/ui";
import ActivityFeed from "@/components/ActivityFeed";
import HomeUserPanel from "@/components/HomeUserPanel";
import {
  serverTotals, leaderboard, getWantedList, listGangs, freshBlood, globalActivity, getServerStatus,
} from "@/lib/queries";
import { getSession } from "@/lib/session";
import { getActorPowers } from "@/lib/whitelist";
import { FEED_TAGS } from "@/lib/logtags";
import { commas, abbrev, moneyAbbrev, relative } from "@/lib/format";
import type { LeaderRow } from "@/lib/types";
import SteamSignIn from "@/components/SteamSignIn";

const SITE = process.env.NEXT_PUBLIC_SITE_NAME ?? "Armapunk 2035";

const TROPHY = ["#FFD700", "#C0C0C0", "#CD7F50"];
function RankMark({ i }: { i: number }) {
  if (i < 3) return <Trophy className="w-3.5 h-3.5" style={{ color: TROPHY[i] }} />;
  return <span className="font-black text-xs text-gray-600">{i + 1}</span>;
}

interface Row { uid: string; name: string; label: string }

function RankCard({
  title, icon, href, rows,
}: { title: string; icon: React.ReactNode; href: string; rows: Row[] }) {
  return (
    <div className="bg-gray-900 border border-gray-700/60 rounded-xl overflow-hidden flex flex-col">
      <div className="flex items-center justify-between px-4 py-3 border-b border-gray-800">
        <div className="flex items-center gap-2">
          {icon}
          <span className="font-bold text-sm text-gray-100 uppercase tracking-wide">{title}</span>
        </div>
        <Link href={href} className="text-xs text-th-500 hover:text-th-300 flex items-center gap-0.5 transition">
          Full ranking <ChevronRight className="w-3 h-3" />
        </Link>
      </div>
      <ul className="divide-y divide-gray-800/60 flex-1">
        {rows.length === 0 ? (
          <li className="px-4 py-4 text-xs text-gray-600 italic">No data.</li>
        ) : rows.map((r, i) => (
          <li key={r.uid} className="flex items-center gap-3 px-4 py-2.5 hover:bg-gray-800/40 transition">
            <span className="w-5 flex justify-center flex-shrink-0"><RankMark i={i} /></span>
            <div className="flex-1 min-w-0"><PlayerLink uid={r.uid} name={r.name} className="text-sm" /></div>
            <span className="text-xs font-semibold text-gray-400 tabular-nums flex-shrink-0">{r.label}</span>
          </li>
        ))}
      </ul>
    </div>
  );
}

function StatCard({ icon, value, label }: { icon: React.ReactNode; value: string; label: string }) {
  return (
    <div className="bg-gray-900/80 border border-gray-700/50 rounded-xl py-4 sm:py-5 px-2 sm:px-4">
      <div className="mx-auto mb-2 flex justify-center">{icon}</div>
      <p className="font-black text-xl sm:text-2xl text-th-400 tabular-nums">{value}</p>
      <p className="text-gray-500 text-[0.65rem] sm:text-xs mt-0.5 uppercase tracking-wide">{label}</p>
    </div>
  );
}

const EXPLORE = [
  { href: "/wiki", label: "Wiki", desc: "Guides & info for new players", Icon: Library },
  { href: "/leaderboard", label: "Leaderboard", desc: "Full rankings by category", Icon: BarChart3 },
  { href: "/gameserver/gangs", label: "Gang Lookup", desc: "Browse and search all gangs", Icon: Users },
  { href: "/support-tickets", label: "Support Tickets", desc: "Submit or track a ticket", Icon: Ticket },
  { href: "/voting", label: "Voting", desc: "Have your say on game changes", Icon: Vote },
  { href: "/changelogs", label: "Changelogs", desc: "Patch notes & updates", Icon: BookOpen },
];

const toRows = (rows: LeaderRow[], money = false): Row[] =>
  rows.map((r) => ({ uid: r.uid, name: r.name, label: money ? moneyAbbrev(r.value) : abbrev(r.value) }));

export default async function HomePage() {
  const session = await getSession();
  const [status, totals, wealth, civ, cop, med, honor, wanted, gangsAll, fresh, powers] = await Promise.all([
    getServerStatus(),
    serverTotals(),
    leaderboard("wealth", 5),
    leaderboard("civ", 5),
    leaderboard("cop", 5),
    leaderboard("med", 5),
    leaderboard("honor", 5),
    getWantedList(),
    listGangs(),
    freshBlood(6),
    session ? getActorPowers(session.uid) : Promise.resolve(null),
  ]);

  const isStaff = !!powers && (powers.isOwner || powers.adminlevel >= 1);
  const feed = isStaff ? await globalActivity(25, FEED_TAGS) : [];

  const gangs = [...gangsAll].sort((a, b) => Number(b.bank) - Number(a.bank)).slice(0, 5);
  const topBank = Math.max(1, ...gangs.map((g) => Number(g.bank)));
  const wantedRows: Row[] = wanted.slice(0, 5).map((w) => ({ uid: w.uid, name: w.name, label: moneyAbbrev(w.bounty) }));

  return (
    // The negative margins cancel NavShell's main padding for the logged-in view; logged out there is
    // no shell, and the same margins would pull the public header above the viewport.
    <div className={session ? "-mx-4 -my-6 sm:-my-8" : ""}>
      {/* personalized panel for logged-in users */}
      {session && <HomeUserPanel session={session} />}

      {/* generic hero (anonymous visitors) */}
      {!session && (
      <>
      {/* public front door: no shell when logged out, so the wordmark and the sign-in live here */}
      <header className="flex items-center justify-between h-14 px-4 border-b border-th-700/30">
        <span className="brand-font text-th-400 text-base">{SITE.toUpperCase()}</span>
        <SteamSignIn compact />
      </header>
      <section className="relative py-16 px-4 text-center overflow-hidden">
        <div className="absolute inset-0 pointer-events-none">
          <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[600px] h-[300px] bg-th-500/5 rounded-full blur-3xl" />
        </div>

        {/* Online players — top right (stacks above the hero on mobile) */}
        <div className="relative z-10 mb-8 flex justify-center lg:mb-0 lg:block lg:absolute lg:top-4 lg:right-4">
          <div className="inline-flex items-center gap-2.5 bg-green-900/20 border border-green-700/40 rounded-xl px-4 py-3">
            <span className="relative flex h-2.5 w-2.5">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-green-400 opacity-75" />
              <span className="relative inline-flex rounded-full h-2.5 w-2.5 bg-green-500" />
            </span>
            <span className="text-green-300 font-black tabular-nums text-xl leading-none">{status.online}</span>
            <span className="text-green-400/80 font-bold text-sm">Online Players</span>
          </div>
        </div>

        <div className="relative max-w-4xl mx-auto">
          <p className="text-th-600 text-xs font-bold uppercase tracking-[0.3em] mb-3">Malden 2035 Roleplay</p>
          <h1 className="text-3xl sm:text-4xl lg:text-5xl text-th-400 mb-4 leading-tight brand-font">{SITE.toUpperCase()}</h1>
          <p className="text-gray-400 text-base sm:text-lg mb-8 sm:mb-10 max-w-md mx-auto">Stats, rankings, gangs and the bounty board for the Malden 2035 server.</p>
          <div className="grid grid-cols-3 gap-2.5 sm:gap-4 max-w-2xl mx-auto">
            <StatCard icon={<Users className="w-5 h-5 text-th-500/70" />} value={commas(totals.players)} label="Players" />
            <StatCard icon={<DollarSign className="w-5 h-5 text-th-500/70" />} value={moneyAbbrev(totals.economy)} label="Economy" />
            <StatCard icon={<Swords className="w-5 h-5 text-th-500/70" />} value={commas(totals.gangs)} label="Gangs" />
          </div>
          <div className="mt-8 flex flex-col items-center gap-2">
            <SteamSignIn />
            <p className="text-gray-500 text-xs">Your profile, garage, houses and rankings need a Steam sign-in.</p>
          </div>
        </div>
      </section>
      </>
      )}

      {/* top rankings */}
      <section className="max-w-7xl mx-auto px-4 pb-10">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-sm font-bold text-gray-400 uppercase tracking-widest">Top Rankings</h2>
          <Link href="/leaderboard" className="text-xs text-th-500 hover:text-th-300 flex items-center gap-0.5 transition">
            All leaderboards <ChevronRight className="w-3 h-3" />
          </Link>
        </div>
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5">
          <RankCard title="Wealthiest" icon={<HandCoins className="w-4 h-4 text-green-400" />} href="/leaderboard?metric=wealth" rows={toRows(wealth, true)} />
          <RankCard title="Most Wanted" icon={<Skull className="w-4 h-4 text-red-400" />} href="/bounties" rows={wantedRows} />
          <RankCard title="Civ XP Legends" icon={<Zap className="w-4 h-4 text-th-400" />} href="/leaderboard?metric=civ" rows={toRows(civ)} />
          <RankCard title="Top Cops" icon={<Shield className="w-4 h-4 text-blue-400" />} href="/leaderboard?metric=cop" rows={toRows(cop)} />
          <RankCard title="Top Trauma Team" icon={<Plus className="w-4 h-4 text-emerald-400" />} href="/leaderboard?metric=med" rows={toRows(med)} />
          <RankCard title="Most Honored" icon={<Award className="w-4 h-4 text-purple-400" />} href="/leaderboard?metric=honor" rows={toRows(honor)} />
        </div>
      </section>

      {/* gang power rankings */}
      <section className="max-w-7xl mx-auto px-4 pb-10">
        <div className="bg-gray-900 border border-gray-700/60 rounded-xl overflow-hidden">
          <div className="flex items-center gap-2 px-4 py-3 border-b border-gray-800">
            <Swords className="w-4 h-4 text-th-500" />
            <span className="font-bold text-sm text-gray-100 uppercase tracking-wide">Gang Power Rankings</span>
          </div>
          <div className="px-4 py-1">
            {gangs.map((g, i) => (
              <div key={g.id} className="flex items-center gap-3 py-2.5 border-b border-gray-800/60 last:border-0">
                <span className="w-5 flex justify-center flex-shrink-0"><RankMark i={i} /></span>
                <div className="flex-1 min-w-0">
                  <div className="flex items-baseline gap-1.5 mb-1">
                    <Link href={`/gameserver/gang-detail?id=${g.id}`} className="text-sm font-semibold text-th-400 hover:text-th-300 truncate transition">{g.name.trim()}</Link>
                    <span className="flex items-center gap-1 text-xs flex-shrink-0 ml-auto text-blue-400">
                      <Users className="w-3 h-3" />{g.members}
                    </span>
                  </div>
                  <div className="flex items-center gap-2">
                    <div className="flex-1 h-1.5 bg-gray-800 rounded-full overflow-hidden">
                      <div className="h-full bg-th-500/70 rounded-full transition-all duration-700" style={{ width: `${(Number(g.bank) / topBank) * 100}%` }} />
                    </div>
                    <span className="text-xs font-semibold text-th-500 tabular-nums w-16 text-right flex-shrink-0">{moneyAbbrev(g.bank)}</span>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* explore + fresh blood */}
      <section className="max-w-7xl mx-auto px-4 pb-12">
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <div className="lg:col-span-2">
            <h2 className="text-xs font-bold text-gray-500 uppercase tracking-widest mb-3 flex items-center gap-2">
              <TrendingUp className="w-3.5 h-3.5" /> Explore
            </h2>
            <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
              {EXPLORE.map(({ href, label, desc, Icon }) => (
                <Link key={href} href={href} className="group bg-gray-900 border border-gray-700/60 hover:border-th-500/40 rounded-xl p-4 transition-all hover:bg-gray-800/60">
                  <Icon className="w-5 h-5 text-th-500/70 group-hover:text-th-400 mb-2 transition" />
                  <p className="font-bold text-sm text-gray-200 group-hover:text-th-400 transition mb-0.5">{label}</p>
                  <p className="text-xs text-gray-600">{desc}</p>
                </Link>
              ))}
            </div>
          </div>
          <div>
            <h2 className="text-xs font-bold text-gray-500 uppercase tracking-widest mb-3 flex items-center gap-2">
              <Clock className="w-3.5 h-3.5" /> Fresh blood
            </h2>
            <div className="bg-gray-900 border border-gray-700/60 rounded-xl overflow-hidden">
              <ul className="divide-y divide-gray-800/60">
                {fresh.map((p) => (
                  <li key={p.uid} className="flex items-center gap-3 px-4 py-2.5">
                    <div className="w-1.5 h-1.5 rounded-full bg-th-500/50 flex-shrink-0" />
                    <div className="flex-1 min-w-0"><PlayerLink uid={p.uid} name={p.name} className="text-sm" /></div>
                    <span className="text-gray-600 text-xs flex-shrink-0">{relative(p.firstSeen)}</span>
                  </li>
                ))}
              </ul>
            </div>
          </div>
        </div>
      </section>

      {/* staff-only activity (anti meta-game) */}
      {isStaff && (
        <section className="max-w-7xl mx-auto px-4 pb-12">
          <SectionCard title="Recent Activity" icon={<Activity className="w-4 h-4" />} right={<Badge color="red">Staff only</Badge>}>
            <div className="max-h-96 overflow-y-auto pr-1"><ActivityFeed rows={feed} /></div>
          </SectionCard>
        </section>
      )}

      <footer className="border-t border-gray-800 py-8 px-4">
        <div className="max-w-7xl mx-auto text-center text-gray-600 text-sm">{SITE} Community • Arma 3 Malden 2035</div>
      </footer>
    </div>
  );
}
