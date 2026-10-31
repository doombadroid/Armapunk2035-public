import Link from "next/link";
import { redirect } from "next/navigation";
import { ArrowLeft, ShieldCheck } from "lucide-react";
import { getSession } from "@/lib/session";
import { getBanStatus } from "@/lib/bans";
import { dateShort } from "@/lib/format";
import GuidedTicketForm from "@/components/GuidedTicketForm";
import { ticketCat } from "@/lib/ticketCategories";

export const dynamic = "force-dynamic";
export const metadata = { title: "Apply to MaxSec" };

export default async function MaxSecApplyPage() {
  const session = await getSession();
  if (!session) redirect("/login");

  const spec = ticketCat("police-app").form;
  const ban = await getBanStatus(session.uid);

  return (
    <div className="max-w-2xl">
      <Link href="/maxsec" className="mb-6 text-th-400 hover:text-th-300 transition flex items-center gap-2 text-sm">
        <ArrowLeft className="w-4 h-4" /> Back to MaxSec
      </Link>
      <div className="flex items-start gap-3 mb-5">
        <div className="w-11 h-11 rounded-xl bg-th-600/20 border border-th-700/40 flex items-center justify-center shrink-0">
          <ShieldCheck className="w-6 h-6 text-th-400" />
        </div>
        <div>
          <h1 className="text-2xl font-black text-th-400">Apply to MaxSec</h1>
          <p className="text-xs text-gray-500 mt-0.5">Your application is sent to MaxSec command for review in the Applications tab.</p>
        </div>
      </div>

      {ban && (
        <div className="mb-5 rounded-xl border border-red-700/50 bg-red-900/20 px-4 py-3 text-xs text-red-300">
          You have an active ban ({ban.reason || "banned"} — {ban.until ? `expires ${dateShort(ban.until)}` : "permanent"}).
          Applicants with active bans are not eligible; resolve it via a Ban Appeal first.
        </div>
      )}

      <GuidedTicketForm category="police-app" spec={spec} variant="maxsec" />
    </div>
  );
}
