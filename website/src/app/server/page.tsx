import { redirect } from "next/navigation";
import { ServerCog } from "lucide-react";
import { getSession } from "@/lib/session";
import { getActorPowers } from "@/lib/whitelist";
import { getServerControl, getServerLog } from "@/lib/queries";
import { SERVER_CTRL_LEVEL } from "@/lib/factions";
import { relative } from "@/lib/format";
import ServerControlPanel from "@/components/ServerControlPanel";

export const dynamic = "force-dynamic";
export const metadata = { title: "Server Control" };

const ACTION_LABEL: Record<string, string> = {
  server_lock: "Locked server", server_unlock: "Unlocked server",
  server_soft: "Soft restart", server_hard: "Hard restart",
  server_update: "Update PBO + restart", server_cancel: "Cancelled restart",
};

export default async function ServerPage() {
  const session = await getSession();
  if (!session) redirect("/login");
  const powers = await getActorPowers(session.uid);
  if (!(powers.isOwner || powers.adminlevel >= SERVER_CTRL_LEVEL)) redirect("/");

  const ctrl = await getServerControl();
  const log = await getServerLog(20);
  const etaMs = ctrl?.web_cmd_eta ? new Date(ctrl.web_cmd_eta).getTime() : null;

  return (
    <div className="max-w-3xl">
      <div className="flex items-center gap-3 mb-5">
        <div className="w-10 h-10 rounded-xl bg-th-600/20 border border-th-700/40 flex items-center justify-center shrink-0">
          <ServerCog className="w-5 h-5 text-th-400" />
        </div>
        <div>
          <h1 className="text-2xl font-black text-th-400">Server Control</h1>
          <p className="text-xs text-gray-500">
            Lock &amp; restart the game server{powers.isOwner ? " · deploy staged code (owner)" : ""} · Senior Admin+
          </p>
        </div>
      </div>

      <ServerControlPanel
        isOwner={powers.isOwner}
        state={{
          locked: !!ctrl && ctrl.svrlock === 1,
          lockBy: ctrl?.lock_by ?? null,
          cmd: ctrl?.web_cmd ?? null,
          cmdStatus: ctrl?.web_cmd_status ?? null,
          cmdBy: ctrl?.web_cmd_by ?? null,
          etaMs,
        }}
      />

      {/* audit */}
      <section className="mt-8">
        <h2 className="text-xs font-bold uppercase tracking-wider text-gray-500 mb-3">Recent server actions</h2>
        {log.length === 0 ? (
          <p className="text-sm text-gray-600">No server actions yet.</p>
        ) : (
          <ul className="rounded-xl border border-gray-800 divide-y divide-gray-800 overflow-hidden">
            {log.map((r) => (
              <li key={r.id} className="px-4 py-2.5 flex items-center gap-3 text-sm bg-gray-900/40">
                <span className="font-semibold text-gray-200 shrink-0">{ACTION_LABEL[r.action] ?? r.action}</span>
                <span className="text-gray-500 truncate flex-1">{r.detail}</span>
                <span className="text-xs text-gray-600 shrink-0">{r.actor_name} · {relative(r.ts)}</span>
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}
