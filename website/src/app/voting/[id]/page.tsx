import { notFound } from "next/navigation";
import { Clock, MessageCircle, Trash2, Send } from "lucide-react";
import { Card, Badge, PageHeader, Avatar, PlayerLink, Empty } from "@/components/ui";
import Markdown from "@/components/Markdown";
import VoteControls from "@/components/VoteControls";
import { getFeature, listFeatureComments, type FeatureStatus } from "@/lib/web";
import { addFeatureComment, setFeatureStatus, deleteFeature } from "@/lib/actions";
import { getSession } from "@/lib/session";
import { dateLong, relative } from "@/lib/format";

export const dynamic = "force-dynamic";

const STATUS_COLOR: Record<FeatureStatus, string> = { open: "gray", planned: "blue", done: "green", declined: "red" };
const STATUS_LABEL: Record<FeatureStatus, string> = { open: "Open", planned: "Implementing", done: "Implemented", declined: "Declined" };
const STATUSES: FeatureStatus[] = ["open", "planned", "done", "declined"];
const INPUT = "bg-gray-800 border border-gray-700 rounded px-3 py-2 text-sm w-full text-gray-100 focus:outline-none focus:border-th-600";

export async function generateMetadata({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const f = await getFeature(Number(id));
  return { title: f ? `${f.title} — Voting` : "Voting" };
}

function closesLabel(d: Date | string | null): string | null {
  if (!d) return null;
  const t = new Date(d).getTime() - Date.now();
  if (t <= 0) return "Voting closed";
  const days = Math.floor(t / 86_400_000);
  const hrs = Math.floor((t % 86_400_000) / 3_600_000);
  return `Closes in ${days > 0 ? `${days}d ` : ""}${hrs}h`;
}

export default async function VotingDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const session = await getSession();
  const f = await getFeature(Number(id), session?.uid);
  if (!f) notFound();

  const comments = await listFeatureComments(f.id);
  const isEditor = !!session && (session.adminLevel >= 3 || session.isOwner);
  const loggedIn = !!session;
  const total = f.up + f.down;
  const pct = total > 0 ? Math.round((f.up / total) * 100) : 0;
  const closes = closesLabel(f.closes_at);

  return (
    <div className="max-w-3xl">
      <PageHeader title="" back={{ href: "/voting", label: "Back to Voting" }} />

      <Card className="overflow-hidden mb-6">
        {f.image_url && (
          <div className="bg-black max-h-96 overflow-hidden flex items-center justify-center">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src={f.image_url} alt="" className="w-full object-contain max-h-96" />
          </div>
        )}
        <div className="p-6">
          <div className="flex items-center gap-2 flex-wrap mb-2">
            <Badge color={STATUS_COLOR[f.status]}>{STATUS_LABEL[f.status]}</Badge>
            {closes && (
              <span className="inline-flex items-center gap-1 text-xs text-gray-400"><Clock className="w-3 h-3" /> {closes}</span>
            )}
          </div>
          <h1 className="text-2xl font-black text-th-400 break-words">{f.title}</h1>
          <p className="text-xs text-gray-500 mt-1">
            {f.author_name || "Anonymous"} <span className="text-gray-600">· {dateLong(f.created_at)}</span>
          </p>

          {f.body && (
            <div className="prose prose-invert max-w-none text-sm mt-4"><Markdown>{f.body}</Markdown></div>
          )}

          {/* votes + tally */}
          <div className="mt-6 pt-5 border-t border-gray-800">
            <div className="max-w-xs"><VoteControls featureId={f.id} up={f.up} down={f.down} myVote={f.myVote} loggedIn={loggedIn} /></div>
            <div className="flex items-center gap-2 mt-3 text-xs">
              <span className="text-green-400 font-bold tabular-nums">{f.up}</span>
              <div className="flex-1 bg-gray-800 rounded-full h-2 overflow-hidden max-w-xs">
                <div className="bg-green-500 h-full rounded-full" style={{ width: `${pct}%` }} />
              </div>
              <span className="text-gray-500 tabular-nums">{pct}% in favor · {total} vote{total === 1 ? "" : "s"}</span>
            </div>
          </div>

          {/* editor controls */}
          {isEditor && (
            <div className="mt-5 pt-4 border-t border-gray-800 flex items-center gap-3 flex-wrap">
              <form action={setFeatureStatus} className="flex items-center gap-2">
                <input type="hidden" name="feature_id" value={f.id} />
                <span className="text-xs text-gray-500 uppercase tracking-wider">Outcome</span>
                <select name="status" defaultValue={f.status} className="bg-gray-800 border border-gray-700 rounded px-2 py-1 text-xs text-gray-200 focus:outline-none focus:border-th-600">
                  {STATUSES.map((s) => <option key={s} value={s}>{STATUS_LABEL[s]}</option>)}
                </select>
                <button className="px-3 py-1 rounded bg-gray-700 hover:bg-th-600 text-gray-200 hover:text-white text-xs font-bold transition">Set</button>
              </form>
              <form action={deleteFeature} className="ml-auto">
                <input type="hidden" name="feature_id" value={f.id} />
                <button className="inline-flex items-center gap-1.5 text-xs text-gray-500 hover:text-red-300 border border-gray-700 hover:border-red-700/50 transition rounded px-3 py-1.5">
                  <Trash2 className="w-3 h-3" /> Delete
                </button>
              </form>
            </div>
          )}
        </div>
      </Card>

      {/* comments */}
      <div className="mb-4 flex items-center gap-2">
        <MessageCircle className="w-4 h-4 text-th-400" />
        <h2 className="text-sm font-bold text-th-400 uppercase tracking-widest">Discussion ({comments.length})</h2>
      </div>

      {comments.length === 0 ? (
        <Card className="p-4 mb-4"><Empty>No comments yet.</Empty></Card>
      ) : (
        <div className="space-y-3 mb-4">
          {comments.map((c) => (
            <div key={c.id} className="flex gap-3">
              <Avatar name={c.author_name} size={8} />
              <div className="flex-1 min-w-0 bg-gray-900 border border-gray-800 rounded-xl px-4 py-3">
                <div className="flex items-center gap-2 mb-1">
                  <PlayerLink uid={c.author_id} name={c.author_name} className="text-sm font-bold" />
                  <span className="text-xs text-gray-600">{relative(c.created_at)}</span>
                </div>
                <p className="text-sm text-gray-300 whitespace-pre-wrap break-words">{c.body}</p>
              </div>
            </div>
          ))}
        </div>
      )}

      {loggedIn ? (
        <Card className="p-4">
          <form action={addFeatureComment} className="space-y-3">
            <input type="hidden" name="feature_id" value={f.id} />
            <textarea name="body" required rows={3} maxLength={4000} placeholder="Add to the discussion…" className={INPUT} />
            <div className="flex justify-end">
              <button className="inline-flex items-center gap-2 bg-th-600 hover:bg-th-700 text-white transition font-semibold text-sm rounded-lg px-4 py-2">
                <Send className="w-4 h-4" /> Comment
              </button>
            </div>
          </form>
        </Card>
      ) : (
        <Card className="p-4 text-center text-sm text-gray-400">
          <a href="/api/auth/login" className="text-th-400 hover:text-th-300 font-semibold">Sign in</a> to join the discussion.
        </Card>
      )}
    </div>
  );
}
