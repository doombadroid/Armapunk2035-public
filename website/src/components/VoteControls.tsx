import { ChevronUp, ChevronDown } from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { castVote } from "@/lib/actions";

/** Horizontal up/down vote pills. Re-casting the same direction clears the vote. */
export default function VoteControls({
  featureId, up, down, myVote = 0, loggedIn,
}: { featureId: number; up: number; down: number; myVote?: number; loggedIn: boolean }) {
  const Btn = ({ dir, count, Icon, activeCls }: { dir: 1 | -1; count: number; Icon: LucideIcon; activeCls: string }) => {
    const active = myVote === dir;
    const cls = `w-full flex items-center justify-center gap-1 px-2 py-1.5 rounded text-xs transition border ${
      active ? activeCls : "bg-gray-800 text-gray-300 border-gray-700 hover:border-gray-500"
    }`;
    return loggedIn ? (
      <form action={castVote} className="flex-1">
        <input type="hidden" name="feature_id" value={featureId} />
        <input type="hidden" name="dir" value={dir} />
        <button className={cls}><Icon className="w-3.5 h-3.5" /><span className="font-semibold tabular-nums">{count}</span></button>
      </form>
    ) : (
      <a href="/api/auth/login" title="Sign in to vote" className={`${cls} flex-1`}>
        <Icon className="w-3.5 h-3.5" /><span className="font-semibold tabular-nums">{count}</span>
      </a>
    );
  };
  return (
    <div className="flex gap-2">
      <Btn dir={1} count={up} Icon={ChevronUp} activeCls="bg-green-600/20 text-green-300 border-green-500/50" />
      <Btn dir={-1} count={down} Icon={ChevronDown} activeCls="bg-red-600/20 text-red-300 border-red-500/50" />
    </div>
  );
}
