import { BookOpen, Plus } from "lucide-react";
import { Card, Badge, Empty } from "@/components/ui";
import Markdown from "@/components/Markdown";
import { listChangelogs } from "@/lib/web";
import { postChangelog } from "@/lib/actions";
import { getSession } from "@/lib/session";
import { dateShort } from "@/lib/format";

export const metadata = { title: "Changelogs" };

const INPUT =
  "bg-gray-800 border border-gray-700 rounded px-3 py-2 text-sm w-full text-gray-200 placeholder:text-gray-600 focus:outline-none focus:border-th-600 transition";

export default async function ChangelogsPage() {
  const [logs, session] = await Promise.all([listChangelogs(), getSession()]);
  const isEditor = !!session && (session.adminLevel >= 3 || session.isOwner);

  return (
    <div>
      {/* header */}
      <div className="flex items-center gap-3 mb-6">
        <div className="w-10 h-10 rounded-xl bg-th-600/20 border border-th-700/40 flex items-center justify-center shrink-0">
          <BookOpen className="w-5 h-5 text-th-400" />
        </div>
        <h1 className="text-2xl font-black text-th-400">Changelogs</h1>
      </div>

      {isEditor && (
        <Card className="p-5 mb-6">
          <h2 className="text-sm font-bold text-th-400 uppercase tracking-widest mb-3 flex items-center gap-2">
            <Plus className="w-4 h-4" /> New changelog
          </h2>
          <form action={postChangelog} className="space-y-3">
            <div className="grid gap-3 sm:grid-cols-[10rem_1fr]">
              <input name="version" placeholder="Version (e.g. b0100)" className={INPUT} />
              <input name="title" required placeholder="Title" className={INPUT} />
            </div>
            <textarea name="body" rows={6} placeholder="Body (markdown supported)…" className={INPUT} />
            <button
              type="submit"
              className="px-5 py-2 rounded-lg bg-th-600 hover:bg-th-500 text-white font-bold text-sm transition"
            >
              Publish changelog
            </button>
          </form>
        </Card>
      )}

      {logs.length === 0 ? (
        <Card className="p-0"><Empty>No changelogs published yet.</Empty></Card>
      ) : (
        <div className="space-y-5">
          {logs.map((c) => (
            <Card key={c.id} className="p-6">
              <div className="flex items-center gap-3 flex-wrap mb-1.5">
                {c.version && <Badge color="th">{c.version}</Badge>}
                <h2 className="text-xl font-black text-th-400">{c.title}</h2>
              </div>
              <p className="text-xs text-gray-500 mb-4">
                {dateShort(c.created_at)}
                {c.author_name ? <span className="text-gray-600"> · {c.author_name}</span> : null}
              </p>
              <div className="text-sm">
                <Markdown>{c.body}</Markdown>
              </div>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
