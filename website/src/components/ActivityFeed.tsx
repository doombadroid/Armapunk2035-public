import { Badge, PlayerLink } from "./ui";
import { tagMeta } from "@/lib/logtags";
import { relative } from "@/lib/format";
import type { ActivityRow } from "@/lib/types";

function clean(msg: string): string {
  // strip the @CTX telemetry tail and collapse whitespace
  const cut = msg.split("@CTX")[0].trim();
  return cut.length > 160 ? cut.slice(0, 157) + "…" : cut;
}

export default function ActivityFeed({
  rows, showPlayer = true,
}: { rows: ActivityRow[]; showPlayer?: boolean }) {
  if (!rows.length) {
    return <div className="px-2 py-6 text-center text-gray-500 text-sm italic">No recent activity.</div>;
  }
  return (
    <ul className="divide-y divide-gray-800">
      {rows.map((r) => {
        const meta = tagMeta(r.tag);
        return (
          <li key={r.id} className="flex items-start gap-3 py-2.5">
            <Badge color={meta.color} className="mt-0.5 shrink-0">{meta.label}</Badge>
            <div className="min-w-0 flex-1">
              <div className="text-sm text-gray-300 break-words">
                {showPlayer && (
                  <>
                    <PlayerLink uid={r.playerid} name={r.name} />{" "}
                  </>
                )}
                <span className="text-gray-400">{clean(r.message)}</span>
              </div>
              <div className="text-xs text-gray-600 mt-0.5">{relative(r.ts)}</div>
            </div>
          </li>
        );
      })}
    </ul>
  );
}
