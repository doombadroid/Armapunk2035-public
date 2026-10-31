import Link from "next/link";
import { Vote, Plus, LogIn, Clock, MessageCircle, ArrowRight, ImagePlus } from "lucide-react";
import { Card, Badge, Empty } from "@/components/ui";
import Markdown from "@/components/Markdown";
import VoteControls from "@/components/VoteControls";
import { listFeatures, type Feature, type FeatureStatus } from "@/lib/web";
import { submitFeature, createPoll } from "@/lib/actions";
import { getSession } from "@/lib/session";
import { dateShort } from "@/lib/format";

export const dynamic = "force-dynamic";
export const metadata = { title: "Community Voting" };

const INPUT = "bg-gray-800 border border-gray-700 rounded px-3 py-2 text-sm w-full text-gray-200 placeholder:text-gray-600 focus:outline-none focus:border-th-600 transition";
const STATUS_COLOR: Record<FeatureStatus, string> = { open: "gray", planned: "blue", done: "green", declined: "red" };
const STATUS_LABEL: Record<FeatureStatus, string> = { open: "Open", planned: "Implementing", done: "Implemented", declined: "Declined" };

function closesLabel(d: Date | string | null): string | null {
  if (!d) return null;
  const t = new Date(d).getTime() - Date.now();
  if (t <= 0) return "Voting closed";
  const days = Math.floor(t / 86_400_000);
  const hrs = Math.floor((t % 86_400_000) / 3_600_000);
  return `Closes in ${days > 0 ? `${days}d ` : ""}${hrs}h`;
}
const pct = (f: Feature) => (f.up + f.down > 0 ? Math.round((f.up / (f.up + f.down)) * 100) : 0);

export default async function VotingPage() {
  const session = await getSession();
  const features = await listFeatures(session?.uid);
  const isEditor = !!session && (session.adminLevel >= 3 || session.isOwner);
  const loggedIn = !!session;

  const active = features.filter((f) => f.status === "open");
  const past = features.filter((f) => f.status !== "open");

  return (
    <div>
      <div className="flex items-center gap-3 mb-2">
        <div className="w-10 h-10 rounded-xl bg-th-600/20 border border-th-700/40 flex items-center justify-center shrink-0">
          <Vote className="w-5 h-5 text-th-400" />
        </div>
        <div>
          <h1 className="text-2xl sm:text-3xl font-black text-th-400">Community Voting</h1>
          <p className="text-gray-400 text-sm">Vote on proposed features &amp; content — or suggest your own.</p>
        </div>
      </div>

      {/* compose */}
      {loggedIn ? (
        <div className="grid gap-3 sm:grid-cols-2 my-6">
          <details className="bg-gray-900 border border-th-700/30 rounded-xl p-4 group">
            <summary className="cursor-pointer text-sm font-bold text-th-400 uppercase tracking-widest flex items-center gap-2 list-none">
              <Plus className="w-4 h-4" /> Suggest a feature
            </summary>
            <form action={submitFeature} className="space-y-3 mt-3">
              <input name="title" required maxLength={160} placeholder="Short, clear title" className={INPUT} />
              <textarea name="body" rows={3} maxLength={4000} placeholder="Describe the idea (markdown supported)…" className={INPUT} />
              <button className="px-4 py-2 rounded-lg bg-th-600 hover:bg-th-500 text-white font-bold text-sm transition">Submit suggestion</button>
            </form>
          </details>

          {isEditor && (
            <details className="bg-gray-900 border border-amber-700/30 rounded-xl p-4">
              <summary className="cursor-pointer text-sm font-bold text-amber-400 uppercase tracking-widest flex items-center gap-2 list-none">
                <ImagePlus className="w-4 h-4" /> Create a poll (staff)
              </summary>
              <form action={createPoll} className="space-y-3 mt-3">
                <input name="title" required maxLength={160} placeholder="Poll title" className={INPUT} />
                <textarea name="body" rows={3} maxLength={4000} placeholder="Proposal details (markdown)…" className={INPUT} />
                <div className="flex gap-2 flex-wrap">
                  <label className="text-xs text-gray-400 flex items-center gap-2">
                    Closes in
                    <input name="closes_days" type="number" min={0} max={60} defaultValue={7} className="w-16 bg-gray-800 border border-gray-700 rounded px-2 py-1 text-sm text-gray-200" /> days
                  </label>
                </div>
                <input name="image" type="file" accept="image/png,image/jpeg,image/webp,image/gif" className="block w-full text-xs text-gray-400 file:mr-3 file:py-1.5 file:px-3 file:rounded file:border-0 file:bg-gray-700 file:text-gray-200 file:text-xs hover:file:bg-gray-600" />
                <button className="px-4 py-2 rounded-lg bg-amber-600 hover:bg-amber-500 text-white font-bold text-sm transition">Publish poll</button>
              </form>
            </details>
          )}
        </div>
      ) : (
        <Card className="p-5 my-6 flex items-center justify-between gap-4 flex-wrap">
          <p className="text-sm text-gray-400">Sign in to suggest features and vote on the ideas you want.</p>
          <a href="/api/auth/login" className="inline-flex items-center gap-2 px-5 py-2 rounded-lg bg-th-600 hover:bg-th-500 text-white font-bold text-sm transition shrink-0">
            <LogIn className="w-4 h-4" /> Sign in with Steam
          </a>
        </Card>
      )}

      {/* active */}
      {active.length === 0 ? (
        <Card className="p-0"><Empty>No active votes right now.</Empty></Card>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
          {active.map((f) => {
            const closes = closesLabel(f.closes_at);
            return (
              <Card key={f.id} className="overflow-hidden flex flex-col">
                {f.image_url && (
                  <Link href={`/voting/${f.id}`} className="block bg-black h-40 overflow-hidden">
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img src={f.image_url} alt="" className="w-full h-full object-cover hover:scale-105 transition" />
                  </Link>
                )}
                <div className="p-4 flex flex-col flex-1">
                  <Link href={`/voting/${f.id}`} className="text-sm font-bold text-th-400 hover:text-th-300 line-clamp-2 mb-2">{f.title}</Link>
                  {f.body && (
                    <div className="text-xs text-gray-400 line-clamp-3 mb-3 flex-1 prose prose-sm prose-invert max-w-none prose-p:my-0"><Markdown>{f.body}</Markdown></div>
                  )}
                  {closes && (
                    <div className="flex items-center gap-1 text-xs px-2 py-1 rounded mb-3 w-fit bg-gray-800 text-gray-400 border border-gray-700">
                      <Clock className="w-3 h-3" /> {closes}
                    </div>
                  )}
                  <VoteControls featureId={f.id} up={f.up} down={f.down} myVote={f.myVote} loggedIn={loggedIn} />
                  <div className="flex items-center justify-between mt-3 text-xs text-gray-500">
                    <span className="inline-flex items-center gap-1"><MessageCircle className="w-3 h-3" /> {f.comments}</span>
                    <Link href={`/voting/${f.id}`} className="inline-flex items-center gap-1 text-th-400 hover:text-th-300 font-semibold">Read more <ArrowRight className="w-3 h-3" /></Link>
                  </div>
                </div>
              </Card>
            );
          })}
        </div>
      )}

      {/* past votes */}
      {past.length > 0 && (
        <div className="mt-12 border-t border-gray-800 pt-8">
          <h2 className="text-lg font-bold text-gray-200 mb-1">Past Votes <span className="text-sm text-gray-500 font-normal">({past.length})</span></h2>
          <p className="text-xs text-gray-600 mb-4">Items that have been closed with an outcome decision.</p>
          <div className="space-y-2">
            {past.map((f) => (
              <Link key={f.id} href={`/voting/${f.id}`} className="bg-gray-900/60 border border-gray-800 hover:border-gray-700 rounded-xl px-5 py-3.5 flex items-center gap-4 transition">
                <Badge color={STATUS_COLOR[f.status]}>{STATUS_LABEL[f.status]}</Badge>
                <span className="flex-1 min-w-0 text-sm font-medium text-gray-300 truncate">{f.title}</span>
                <div className="hidden sm:flex items-center gap-2 w-44 shrink-0">
                  <span className="text-xs text-green-400 font-bold w-8 text-right tabular-nums">{f.up}</span>
                  <div className="flex-1 bg-gray-800 rounded-full h-2 overflow-hidden">
                    <div className="bg-green-500 h-full rounded-full" style={{ width: `${pct(f)}%` }} />
                  </div>
                  <span className="text-xs text-gray-500 w-9 text-right tabular-nums">{pct(f)}%</span>
                </div>
                <span className="hidden md:flex items-center gap-1 text-xs text-gray-500 shrink-0"><MessageCircle className="w-3.5 h-3.5" /> {f.comments}</span>
                <span className="hidden lg:block text-xs text-gray-600 shrink-0">{dateShort(f.created_at)}</span>
              </Link>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
