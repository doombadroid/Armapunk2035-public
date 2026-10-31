import Link from "next/link";
import { Ticket as TicketIcon, MessageSquare, Plus, Search } from "lucide-react";
import { Card, Badge, PageHeader, PlayerLink, Empty } from "@/components/ui";
import { listTickets } from "@/lib/web";
import { getSession } from "@/lib/session";
import { relative } from "@/lib/format";
import { ticketCat, TICKET_CATEGORIES } from "@/lib/ticketCategories";

export const dynamic = "force-dynamic";
export const metadata = { title: "Support Tickets" };

const STATUS_COLOR: Record<string, string> = { open: "amber", answered: "blue", closed: "gray" };
const STATUS_TABS = ["all", "open", "answered", "closed"] as const;

export default async function SupportTicketsPage({
  searchParams,
}: { searchParams: Promise<{ status?: string; q?: string; cat?: string }> }) {
  const session = await getSession();

  if (!session) {
    return (
      <div>
        <PageHeader title="Support Tickets" />
        <Card className="p-8 text-center">
          <TicketIcon className="w-10 h-10 text-th-500 mx-auto mb-3" />
          <h2 className="text-lg font-bold text-gray-200 mb-1">Sign in to get support</h2>
          <p className="text-sm text-gray-500 mb-5">Open and track support tickets by signing in with your Steam account.</p>
          <a href="/api/auth/login" className="inline-flex items-center gap-2 bg-th-700/40 border border-th-600/50 text-th-200 hover:bg-th-700/60 transition font-semibold text-sm rounded px-4 py-2">
            Sign in with Steam
          </a>
        </Card>
      </div>
    );
  }

  const sp = await searchParams;
  const isStaff = session.adminLevel > 0 || session.isOwner;
  const status = STATUS_TABS.includes((sp.status ?? "all") as typeof STATUS_TABS[number]) ? (sp.status ?? "all") : "all";
  const search = (sp.q ?? "").trim();
  const cat = isStaff ? (sp.cat ?? "").trim() : "";

  const tickets = isStaff
    ? await listTickets({ all: true, status, category: cat || undefined, search: search || undefined })
    : await listTickets({ playerid: session.uid, status, search: search || undefined });

  const withParam = (patch: Record<string, string>) => {
    const p = new URLSearchParams();
    const base = { status, q: search, cat };
    for (const [k, v] of Object.entries({ ...base, ...patch })) if (v && v !== "all") p.set(k, v);
    const s = p.toString();
    return `/support-tickets${s ? `?${s}` : ""}`;
  };

  return (
    <div>
      <div className="flex items-end justify-between gap-3 flex-wrap mb-5">
        <div>
          <h1 className="text-2xl sm:text-3xl font-black text-th-400">Support Tickets</h1>
          <p className="text-xs text-gray-500 mt-1 flex items-center gap-1.5">
            <TicketIcon className="w-3.5 h-3.5" /> {isStaff ? "All tickets" : "Your tickets"} · {tickets.length}
          </p>
        </div>
        <Link href="/support-tickets/new" className="px-4 py-2 bg-th-600 hover:bg-th-700 text-white text-sm font-semibold rounded-lg transition inline-flex items-center gap-1.5">
          <Plus className="w-4 h-4" /> New Ticket
        </Link>
      </div>

      {/* filters */}
      <div className="flex flex-wrap items-center gap-2 mb-5">
        {STATUS_TABS.map((s) => (
          <Link key={s} href={withParam({ status: s })}
            className={`px-3.5 py-1.5 rounded-full text-xs font-medium border transition capitalize ${
              status === s ? "bg-th-600 border-th-600 text-white" : "bg-transparent border-gray-700 text-gray-400 hover:border-th-600/60 hover:text-gray-200"
            }`}>{s}</Link>
        ))}
        <form method="get" className="flex items-center gap-2 ml-auto flex-wrap">
          <input type="hidden" name="status" value={status} />
          {isStaff && (
            <select name="cat" defaultValue={cat} className="bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-sm text-gray-200 focus:outline-none focus:border-th-500">
              <option value="">All categories</option>
              {TICKET_CATEGORIES.map((c) => <option key={c.key} value={c.key}>{c.label}</option>)}
            </select>
          )}
          <div className="relative">
            <Search className="absolute left-2.5 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-gray-500 pointer-events-none" />
            <input name="q" defaultValue={search} placeholder={isStaff ? "Search subject / Steam ID…" : "Search…"}
              className="w-52 pl-8 pr-3 py-2 bg-gray-800 border border-gray-700 rounded-lg text-sm text-gray-100 placeholder-gray-500 focus:outline-none focus:border-th-500" />
          </div>
        </form>
      </div>

      {tickets.length === 0 ? (
        <Card className="py-2"><Empty>No tickets match.</Empty></Card>
      ) : (
        <div className="space-y-3">
          {tickets.map((t) => (
            <Card key={t.id} className="relative p-4 hover:border-th-600/50 transition">
              <Link href={`/support-tickets/${t.id}`} aria-label={t.subject} className="absolute inset-0 z-0 rounded-xl" />
              <div className="flex items-start justify-between gap-3">
                <div className="min-w-0">
                  <div className="flex items-center gap-2 flex-wrap">
                    <span className="font-mono text-xs text-gray-600">#{t.id}</span>
                    <span className="font-bold text-gray-100 truncate">{t.subject}</span>
                    <Badge color={STATUS_COLOR[t.status] ?? "gray"}>{t.status}</Badge>
                    <Badge color="th">{ticketCat(t.category).label}</Badge>
                  </div>
                  <div className="flex items-center gap-3 mt-2 text-xs text-gray-500 flex-wrap">
                    {isStaff && <span className="relative z-10"><PlayerLink uid={t.playerid} name={t.player_name} /></span>}
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
  );
}
