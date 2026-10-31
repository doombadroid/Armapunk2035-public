"use client";

import { useEffect, useState } from "react";
import { Radio } from "lucide-react";

interface Row {
  id: number; ts: string; faction: string; actor_name: string; actor_role: string;
  target_name: string; old_rank: number; new_rank: number; action: string;
}

const ACTION_COLOR: Record<string, string> = {
  whitelist: "text-green-400", promote: "text-th-400",
  demote: "text-orange-400", remove: "text-red-400", set: "text-gray-400",
};

export default function LiveAuditLog({ initial }: { initial: Row[] }) {
  const [rows, setRows] = useState<Row[]>(initial);
  const [live, setLive] = useState(true);

  useEffect(() => {
    if (!live) return;
    let alive = true;
    const tick = async () => {
      try {
        const res = await fetch("/api/whitelist-log", { cache: "no-store" });
        if (res.ok) {
          const data = await res.json();
          if (alive) setRows(data.rows ?? []);
        }
      } catch {
        /* ignore */
      }
    };
    const iv = setInterval(tick, 5000);
    return () => { alive = false; clearInterval(iv); };
  }, [live]);

  return (
    <div>
      <div className="flex items-center justify-between mb-2">
        <span className="text-xs text-gray-500 uppercase tracking-wider flex items-center gap-1.5">
          <Radio className={`w-3.5 h-3.5 ${live ? "text-green-400 animate-pulse" : "text-gray-600"}`} />
          Live audit
        </span>
        <button onClick={() => setLive((l) => !l)} className="text-xs text-gray-500 hover:text-gray-300">
          {live ? "pause" : "resume"}
        </button>
      </div>
      {rows.length === 0 ? (
        <p className="text-sm text-gray-600 italic py-3">No whitelist actions yet.</p>
      ) : (
        <ul className="divide-y divide-gray-800 max-h-[28rem] overflow-y-auto">
          {rows.map((r) => (
            <li key={r.id} className="py-2 text-sm">
              <span className={`font-bold ${ACTION_COLOR[r.action] ?? "text-gray-400"}`}>{r.action}</span>{" "}
              <span className="text-gray-300">{r.target_name}</span>{" "}
              <span className="text-gray-500 text-xs">({r.old_rank}→{r.new_rank})</span>
              <span className="text-gray-600 text-xs"> · {r.faction}</span>
              <div className="text-xs text-gray-600">
                by {r.actor_name} <span className="text-gray-700">[{r.actor_role}]</span> · {new Date(r.ts).toLocaleString()}
              </div>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
