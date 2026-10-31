import Link from "next/link";
import { Stethoscope, ClipboardList, ShieldAlert, Search, MessageSquare, Plus } from "lucide-react";
import { Card, Badge, PlayerLink, Empty } from "@/components/ui";
import FactionRosterView from "@/components/FactionRosterView";
import { getTTApplications, type MaxSecApplication } from "@/lib/queries";
import { listTickets } from "@/lib/web";
import { getActorPowers } from "@/lib/whitelist";
import { dateShort, relative } from "@/lib/format";
import { getSession } from "@/lib/session";

export const dynamic = "force-dynamic";
export const metadata = { title: "Trauma Team" };

const APP_STATUS: Record<string, string> = { pending: "amber", accepted: "green", denied: "red" };
const TICKET_STATUS: Record<string, string> = { open: "amber", answered: "blue", closed: "gray" };
const REPORT_TABS = ["all", "open", "answered", "closed"] as const;

function Tab({ active, href, children }: { active: boolean; href: string; children: React.ReactNode }) {
  return (
    <Link href={href} className={
      active
        ? "px-4 py-2 rounded-lg text-sm font-bold bg-th-600/20 text-th-300 border border-th-700/40 transition"
        : "px-4 py-2 rounded-lg text-sm font-bold text-gray-400 hover:text-gray-200 border border-transparent transition"
    }>{children}</Link>
  );
}

function QA({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <p className="text-xs text-gray-500 uppercase tracking-wider mb-1">{label}</p>
      <p className="text-gray-300 whitespace-pre-wrap break-words bg-gray-800/40 rounded-lg px-3 py-2 border border-gray-800">{value?.trim() || "—"}</p>
    </div>
  );
}

function ApplicationCard({ a }: { a: MaxSecApplication }) {
  return (
    <Card className="p-5">
      <div className="flex items-start justify-between gap-3 mb-3">
        <div className="min-w-0">
          <div className="flex items-center gap-2 flex-wrap">
            {a.pid ? <PlayerLink uid={a.pid} name={a.ig_name} className="text-lg" /> : <span className="text-lg font-bold text-th-400">{a.ig_name}</span>}
            <Badge color={APP_STATUS[a.status] ?? "gray"}>{a.status}</Badge>
          </div>
          <p className="text-xs text-gray-500 mt-0.5">Discord: {a.discord_name || "—"} · {dateShort(a.created_at)}</p>
        </div>
      </div>
      <div className="space-y-3 text-sm">
        <QA label="Experience" value={a.cop_experience} />
        <QA label="Why join Trauma Team?" value={a.why} />
        <QA label="Disciplinary history" value={a.disciplinary} />
      </div>
      {a.reviewer_name && (
        <p className="mt-4 pt-3 border-t border-gray-800 text-xs text-gray-500">
          Reviewed by <span className="text-gray-400 font-semibold">{a.reviewer_name}</span>{a.decided_at ? ` · ${dateShort(a.decided_at)}` : ""}
        </p>
      )}
    </Card>
  );
}

export default async function TraumaTeamPage({
  searchParams,
}: { searchParams: Promise<{ tab?: string; q?: string; rank?: string; addq?: string; status?: string; submitted?: string; dup?: string }> }) {
  const sp = await searchParams;
  const session = await getSession();
  const isStaff = !!session && (session.adminLevel > 0 || session.isOwner);

  // authoritative TT command check (Warrant Officer+) for the reports queue
  const powers = session ? await getActorPowers(session.uid) : null;
  const isCommand = !!powers && powers.ranks.medic >= 4;
  const canReports = isStaff || isCommand;

  const active =
    sp.tab === "reports" && canReports ? "reports"
    : sp.tab === "applications" ? "applications"
    : "roster";

  const counts = { pending: 0, accepted: 0, denied: 0 };
  let apps: MaxSecApplication[] = [];
  if (active === "applications") {
    apps = await getTTApplications();
    counts.pending = apps.filter((a) => a.status === "pending").length;
    counts.accepted = apps.filter((a) => a.status === "accepted").length;
    counts.denied = apps.filter((a) => a.status === "denied").length;
  }
  const myApps = session ? apps.filter((a) => a.pid === session.uid) : [];

  const rStatus = REPORT_TABS.includes((sp.status ?? "all") as typeof REPORT_TABS[number]) ? (sp.status ?? "all") : "all";
  const rSearch = active === "reports" ? (sp.q ?? "").trim() : "";
  const reports = active === "reports"
    ? await listTickets({ category: "ng-report", status: rStatus, search: rSearch || undefined })
    : [];

  return (
    <div>
      {/* header */}
      <div className="flex items-center gap-3 mb-5">
        <div className="w-10 h-10 rounded-xl bg-th-600/20 border border-th-700/40 flex items-center justify-center shrink-0">
          <Stethoscope className="w-5 h-5 text-th-400" />
        </div>
        <div>
          <h1 className="text-2xl font-black text-th-400">Trauma Team</h1>
          <p className="text-xs text-gray-500">Roster, recruitment &amp; conduct</p>
        </div>
      </div>

      {/* tabs */}
      <div className="flex gap-2 mb-6 flex-wrap">
        <Tab active={active === "roster"} href="/trauma-team?tab=roster">Roster</Tab>
        <Tab active={active === "applications"} href="/trauma-team?tab=applications">Applications</Tab>
        {canReports && <Tab active={active === "reports"} href="/trauma-team?tab=reports">Reports</Tab>}
      </div>

      {active === "roster" ? (
        <FactionRosterView faction="medic" sp={sp} />
      ) : active === "reports" ? (
        <div>
          <div className="flex flex-wrap items-center gap-2 mb-5">
            {REPORT_TABS.map((s) => (
              <Link key={s} href={`/trauma-team?tab=reports${s !== "all" ? `&status=${s}` : ""}`}
                className={`px-3.5 py-1.5 rounded-full text-xs font-medium border transition capitalize ${
                  rStatus === s ? "bg-th-600 border-th-600 text-white" : "bg-transparent border-gray-700 text-gray-400 hover:border-th-600/60 hover:text-gray-200"
                }`}>{s}</Link>
            ))}
            <form method="get" className="flex items-center gap-2 ml-auto">
              <input type="hidden" name="tab" value="reports" />
              <input type="hidden" name="status" value={rStatus} />
              <div className="relative">
                <Search className="absolute left-2.5 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-gray-500 pointer-events-none" />
                <input name="q" defaultValue={rSearch} placeholder="Search subject / Steam ID…"
                  className="w-56 pl-8 pr-3 py-2 bg-gray-800 border border-gray-700 rounded-lg text-sm text-gray-100 placeholder-gray-500 focus:outline-none focus:border-th-500" />
              </div>
            </form>
          </div>
          {reports.length === 0 ? (
            <Card className="py-2"><Empty>No Trauma Team reports match.</Empty></Card>
          ) : (
            <div className="space-y-3">
              {reports.map((t) => (
                <Card key={t.id} className="relative p-4 hover:border-th-600/50 transition">
                  <Link href={`/support-tickets/${t.id}`} aria-label={t.subject} className="absolute inset-0 z-0 rounded-xl" />
                  <div className="flex items-start gap-3">
                    <ShieldAlert className="w-5 h-5 text-th-500 shrink-0 mt-0.5" />
                    <div className="min-w-0 flex-1">
                      <div className="flex items-center gap-2 flex-wrap">
                        <span className="font-mono text-xs text-gray-600">#{t.id}</span>
                        <span className="font-bold text-gray-100 truncate">{t.subject}</span>
                        <Badge color={TICKET_STATUS[t.status] ?? "gray"}>{t.status}</Badge>
                      </div>
                      <div className="flex items-center gap-3 mt-2 text-xs text-gray-500 flex-wrap">
                        <span className="relative z-10"><PlayerLink uid={t.playerid} name={t.player_name} /></span>
                        <span className="inline-flex items-center gap-1"><MessageSquare className="w-3 h-3" /> {t.messages ?? 0}</span>
                        <span>updated {relative(t.updated_at)}</span>
                      </div>
                    </div>
                  </div>
                </Card>
              ))}
            </div>
          )}
        </div>
      ) : (
        <div className="space-y-4">
          {/* Apply CTA */}
          <div className="flex items-center justify-between gap-3 flex-wrap">
            <p className="text-sm text-gray-400">Want to serve? Applications are reviewed by TT command.</p>
            <Link href="/trauma-team/apply" className="inline-flex items-center gap-2 px-4 py-2 bg-th-600 hover:bg-th-700 text-white text-sm font-bold rounded-lg transition shrink-0">
              <Stethoscope className="w-4 h-4" /> Apply to Trauma Team
            </Link>
          </div>
          {sp.submitted && (
            <div className="rounded-lg border border-green-700/50 bg-green-900/20 px-4 py-3 text-sm text-green-300 flex items-center gap-2">
              <Plus className="w-4 h-4 rotate-45" /> Application submitted — TT command will review it. Thanks!
            </div>
          )}
          {sp.dup && (
            <div className="rounded-lg border border-amber-700/50 bg-amber-900/20 px-4 py-3 text-sm text-amber-300">
              You already have a pending application. Please wait for it to be reviewed.
            </div>
          )}

          {!isStaff ? (
            myApps.length > 0 ? (
              <div className="space-y-4">
                <p className="text-sm font-bold text-gray-300">Your Applications</p>
                {myApps.map((a) => <ApplicationCard key={a.id} a={a} />)}
              </div>
            ) : (
              <Card className="p-8 text-center">
                <ClipboardList className="w-8 h-8 text-th-500/60 mx-auto mb-3" />
                <p className="text-gray-300 font-bold">Trauma Team applications are reviewed by TT command.</p>
                <p className="text-xs text-gray-500 mt-3">Use “Apply to Trauma Team” above to submit your application.</p>
              </Card>
            )
          ) : apps.length === 0 ? (
            <Card className="p-0"><Empty>No applications submitted yet.</Empty></Card>
          ) : (
            <div className="space-y-4">
              <div className="flex items-center gap-2 mb-1">
                <Badge color="amber">{counts.pending} pending</Badge>
                <Badge color="green">{counts.accepted} accepted</Badge>
                <Badge color="red">{counts.denied} denied</Badge>
              </div>
              {apps.map((a) => <ApplicationCard key={a.id} a={a} />)}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
