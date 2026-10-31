import Link from "next/link";
import { redirect } from "next/navigation";
import {
  ArrowLeft,
  CircleAlert, ShieldAlert, ShieldCheck, Stethoscope, Banknote, UserCog, Scale, UserX, Bug, UserPlus, CircleHelp,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { getSession } from "@/lib/session";
import { getBanStatus } from "@/lib/bans";
import { dateShort } from "@/lib/format";
import GuidedTicketForm from "@/components/GuidedTicketForm";
import CompensationForm from "@/components/CompensationForm";
import { TICKET_CATEGORIES, ticketCat, isValidCategory } from "@/lib/ticketCategories";

export const dynamic = "force-dynamic";
export const metadata = { title: "New Ticket" };

const ICONS: Record<string, LucideIcon> = {
  CircleAlert, ShieldAlert, ShieldCheck, Stethoscope, Banknote, UserCog, Scale, UserX, Bug, UserPlus, CircleHelp,
};

export default async function NewTicketPage({
  searchParams,
}: { searchParams: Promise<{ cat?: string }> }) {
  const session = await getSession();
  if (!session) redirect("/login");

  const sp = await searchParams;
  const cat = sp.cat && isValidCategory(sp.cat) ? sp.cat : "";

  // Faction applications go to their dedicated apply pages → maxsec_applications, never as a ticket.
  if (cat === "police-app") redirect("/maxsec/apply");
  if (cat === "ng-app") redirect("/trauma-team/apply");

  // step 2 — the compose form for a chosen category
  if (cat) {
    const c = ticketCat(cat);
    const Icon = ICONS[c.icon] ?? CircleHelp;
    const myBan = cat === "ban-appeal" ? await getBanStatus(session.uid) : null;
    return (
      <div className="max-w-2xl">
        <Link href="/support-tickets/new" className="mb-6 text-th-400 hover:text-th-300 transition flex items-center gap-2 text-sm">
          <ArrowLeft className="w-4 h-4" /> Change category
        </Link>
        <div className="flex items-start gap-3 mb-5">
          <div className="w-11 h-11 rounded-xl bg-th-600/20 border border-th-700/40 flex items-center justify-center shrink-0">
            <Icon className="w-6 h-6 text-th-400" />
          </div>
          <div>
            <h1 className="text-2xl font-black text-th-400">{c.label}</h1>
            <p className="text-xs text-gray-500 mt-0.5">{c.desc}</p>
          </div>
        </div>
        {cat === "ban-appeal" && (
          <div className="mb-5 rounded-xl border border-gray-700 overflow-hidden">
            <div className="px-4 py-2.5 border-b border-gray-700 bg-gray-800/60 text-xs font-bold uppercase tracking-wider text-gray-400">Your Ban Record</div>
            <div className="px-4 py-3 text-xs">
              {myBan ? (
                <div className="text-red-300">
                  <b>{myBan.reason || "Banned"}</b> — {myBan.until ? `expires ${dateShort(myBan.until)}` : "permanent"}
                  {myBan.by ? <span className="text-gray-500"> · by {myBan.by}</span> : null}
                </div>
              ) : (
                <div className="text-green-400">No active bans found on your account.</div>
              )}
            </div>
            <div className="px-4 py-2.5 border-t border-gray-700 bg-gray-800/40 text-xs text-gray-400">
              In your description, include why you believe the ban was unfair and any evidence.
            </div>
          </div>
        )}
        {c.form.special === "compensation"
          ? <CompensationForm />
          : <GuidedTicketForm category={cat} spec={c.form} />}
      </div>
    );
  }

  // step 1 — category grid
  return (
    <div>
      <Link href="/support-tickets" className="mb-6 text-th-400 hover:text-th-300 transition flex items-center gap-2 text-sm">
        <ArrowLeft className="w-4 h-4" /> Back to Tickets
      </Link>
      <h1 className="text-2xl sm:text-3xl font-black text-th-400 mb-1">Select a Category</h1>
      <p className="text-gray-400 text-sm mb-8">Choose the category that best fits your support request.</p>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {TICKET_CATEGORIES.filter((c) => !c.hidden).map((c) => {
          const Icon = ICONS[c.icon] ?? CircleHelp;
          return (
            <Link key={c.key} href={`/support-tickets/new?cat=${c.key}`}
              className="p-5 bg-gray-900 border border-th-700/30 rounded-xl hover:border-th-600 hover:bg-gray-800/60 transition text-left flex items-start gap-4">
              <Icon className="w-7 h-7 text-th-500 shrink-0 mt-0.5" />
              <div>
                <h3 className="font-bold text-gray-200">{c.label}</h3>
                <p className="text-xs text-gray-400 mt-1.5">{c.desc}</p>
              </div>
            </Link>
          );
        })}
      </div>
    </div>
  );
}
