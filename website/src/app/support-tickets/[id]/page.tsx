import { notFound } from "next/navigation";
import { Lock, Send, MessageSquare, RotateCcw } from "lucide-react";
import { Card, Badge, PageHeader, PlayerLink, Avatar } from "@/components/ui";
import { getTicket } from "@/lib/web";
import { replyTicket, closeTicket, reopenTicket } from "@/lib/actions";
import { getSession } from "@/lib/session";
import { getActorPowers } from "@/lib/whitelist";
import { ticketCat } from "@/lib/ticketCategories";
import { dateLong, relative } from "@/lib/format";

const STATUS_COLOR: Record<string, string> = { open: "amber", answered: "blue", closed: "gray" };

const inputCls = "bg-gray-800 border border-gray-700 rounded px-3 py-2 text-sm text-gray-100 w-full";

// Split a message body into display text + attachment image URLs (guided-ticket forms
// append "[attachments]" then /api/images/tickets/<file> lines).
function splitBody(body: string): { text: string; images: string[] } {
  const images: string[] = [];
  const textLines: string[] = [];
  for (const l of body.split("\n")) {
    const t = l.trim();
    if (/^\/api\/images\/tickets\/[A-Za-z0-9._-]+$/.test(t)) images.push(t);
    else if (t === "[attachments]") continue;
    else textLines.push(l);
  }
  return { text: textLines.join("\n").trim(), images };
}

export async function generateMetadata({
  params,
}: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const data = await getTicket(Number(id));
  return { title: data ? `${data.ticket.subject} — Ticket #${data.ticket.id}` : "Ticket" };
}

export default async function TicketDetailPage({
  params,
}: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const data = await getTicket(Number(id));
  if (!data) notFound();

  const { ticket, messages } = data;

  // VIEW PERMISSION: opener or staff. Misconduct reports are ALSO visible to the
  // relevant faction command (MaxSec Lt+ / TT Warrant Officer+). Don't leak — 404 otherwise.
  const session = await getSession();
  const isStaff = !!session && (session.adminLevel > 0 || session.isOwner);
  let canView = !!session && (session.uid === ticket.playerid || isStaff);
  const cat = ticketCat(ticket.category);
  if (!canView && session && (cat.report === "apd" || cat.report === "ng")) {
    const powers = await getActorPowers(session.uid);
    if (cat.report === "apd" && powers.ranks.police >= 5) canView = true; // MaxSec Lieutenant+
    if (cat.report === "ng" && powers.ranks.medic >= 4) canView = true;    // TT Warrant Officer+
  }
  if (!canView) notFound();

  const isClosed = ticket.status === "closed";

  return (
    <div>
      <PageHeader title="" back={{ href: "/support-tickets", label: "Back to Tickets" }} />

      {/* header card */}
      <Card className="p-6 mb-6">
        <div className="flex items-start justify-between gap-3 flex-wrap">
          <div className="min-w-0">
            <h1 className="text-2xl font-black text-th-400 break-words">{ticket.subject}</h1>
            <div className="flex items-center gap-2 mt-2 flex-wrap text-xs text-gray-500">
              <span className="font-mono text-gray-600">#{ticket.id}</span>
              <span>·</span>
              <span>Opened by <PlayerLink uid={ticket.playerid} name={ticket.player_name} /></span>
              <span>·</span>
              <span>{dateLong(ticket.created_at)}</span>
            </div>
          </div>
          <div className="flex items-center gap-2 shrink-0">
            <Badge color={STATUS_COLOR[ticket.status] ?? "gray"}>{ticket.status}</Badge>
            <Badge color="th">{ticketCat(ticket.category).label}</Badge>
          </div>
        </div>
      </Card>

      {/* messages thread */}
      <div className="space-y-3 mb-6">
        {messages.map((m) => {
          const staffMsg = Number(m.is_staff) === 1;   // boolean under PostgreSQL, 0/1 under the old MySQL
          return (
            <div
              key={m.id}
              className={`flex gap-3 ${staffMsg ? "justify-start" : "justify-end flex-row-reverse"}`}
            >
              <Avatar name={m.author_name} size={9} />
              <div
                className={`max-w-[80%] rounded-xl border px-4 py-3 ${
                  staffMsg
                    ? "bg-th-900/30 border-th-700/40"
                    : "bg-gray-900 border-gray-800"
                }`}
              >
                <div className="flex items-center gap-2 mb-1">
                  <span className={`text-sm font-bold ${staffMsg ? "text-th-300" : "text-gray-200"}`}>
                    {m.author_name}
                  </span>
                  {staffMsg && <Badge color="th">Staff</Badge>}
                  <span className="text-xs text-gray-600">{relative(m.created_at)}</span>
                </div>
                {(() => {
                  const { text, images } = splitBody(m.body);
                  return (
                    <>
                      {text && <p className="text-sm text-gray-300 whitespace-pre-wrap break-words">{text}</p>}
                      {images.length > 0 && (
                        <div className="grid grid-cols-2 sm:grid-cols-3 gap-2 mt-2">
                          {images.map((u, i) => (
                            <a key={i} href={u} target="_blank" rel="noopener noreferrer" className="block bg-black rounded-lg overflow-hidden border border-gray-800">
                              {/* eslint-disable-next-line @next/next/no-img-element */}
                              <img src={u} alt="attachment" className="w-full h-28 object-cover hover:opacity-90 transition" />
                            </a>
                          ))}
                        </div>
                      )}
                    </>
                  );
                })()}
              </div>
            </div>
          );
        })}
      </div>

      {/* reply / close, or closed notice */}
      {isClosed ? (
        <Card className="p-4 flex items-center justify-between gap-3 flex-wrap text-sm text-gray-400">
          <span className="flex items-center gap-2">
            <Lock className="w-4 h-4 text-gray-500" /> This ticket is closed.
          </span>
          <form action={reopenTicket}>
            <input type="hidden" name="ticket_id" value={ticket.id} />
            <button
              type="submit"
              className="inline-flex items-center gap-1.5 text-xs text-th-300 hover:text-th-200 border border-th-700/50 hover:border-th-600/70 bg-th-700/20 hover:bg-th-700/40 transition rounded px-3 py-1.5 font-semibold"
            >
              <RotateCcw className="w-3 h-3" /> Reopen ticket
            </button>
          </form>
        </Card>
      ) : (
        <Card className="p-5">
          <h3 className="text-sm font-bold text-th-400 uppercase tracking-widest flex items-center gap-2 mb-4">
            <MessageSquare className="w-4 h-4" /> Reply
          </h3>
          <form action={replyTicket} className="space-y-3">
            <input type="hidden" name="ticket_id" value={ticket.id} />
            <textarea
              name="body"
              required
              rows={4}
              maxLength={4000}
              placeholder="Write a reply…"
              className={inputCls}
            />
            <div className="flex justify-end">
              <button
                type="submit"
                className="inline-flex items-center gap-2 bg-th-700/40 border border-th-600/50 text-th-200 hover:bg-th-700/60 transition font-semibold text-sm rounded px-4 py-2"
              >
                <Send className="w-4 h-4" /> Send Reply
              </button>
            </div>
          </form>
          {/* sibling form (not nested — nested <form> is invalid HTML) */}
          <form action={closeTicket} className="mt-3 pt-3 border-t border-gray-800">
            <input type="hidden" name="ticket_id" value={ticket.id} />
            <button
              type="submit"
              className="inline-flex items-center gap-1.5 text-xs text-gray-500 hover:text-red-300 border border-gray-700 hover:border-red-700/50 transition rounded px-3 py-1.5"
            >
              <Lock className="w-3 h-3" /> Close ticket
            </button>
          </form>
        </Card>
      )}
    </div>
  );
}
