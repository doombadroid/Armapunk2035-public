"use client";

import { Ban, ShieldOff } from "lucide-react";
import { banPlayer, unbanPlayer } from "@/lib/actions";

interface CurrentBan { reason: string; by: string; until: string | null; clankr: boolean }

const MOD_DURATIONS = [
  ["1h", "1 hour"], ["3h", "3 hours"], ["12h", "12 hours"], ["1d", "1 day"], ["3d", "3 days"],
] as const;
const ADMIN_EXTRA = [
  ["7d", "7 days"], ["14d", "14 days"], ["30d", "30 days"], ["perma", "Permanent"],
] as const;

export default function BanControl({
  uid, isAdmin, canBan, current,
}: { uid: string; isAdmin: boolean; canBan: boolean; current: CurrentBan | null }) {
  const durations = isAdmin ? [...MOD_DURATIONS, ...ADMIN_EXTRA] : MOD_DURATIONS;

  if (current) {
    const untilLabel = current.until ? new Date(current.until).toLocaleString() : "Permanent";
    return (
      <div className="rounded-lg border border-red-700/40 bg-red-900/20 p-4">
        <div className="flex items-center gap-2 text-red-300 font-bold text-sm">
          <Ban className="w-4 h-4" /> BANNED {current.clankr && <span className="text-xs bg-red-800/50 px-1.5 py-0.5 rounded">CLANKR</span>}
        </div>
        <p className="text-sm text-gray-300 mt-1">{current.reason}</p>
        <p className="text-xs text-gray-500 mt-1">by {current.by} · expires {untilLabel}</p>
        {isAdmin && (
          <form
            action={unbanPlayer}
            onSubmit={(e) => { if (!confirm("Lift this ban? (BattleMetrics removal is manual.)")) e.preventDefault(); }}
            className="mt-3"
          >
            <input type="hidden" name="playerid" value={uid} />
            <button className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded bg-gray-800 hover:bg-gray-700 border border-gray-600 text-gray-200 text-xs font-bold">
              <ShieldOff className="w-3.5 h-3.5" /> Lift Ban
            </button>
          </form>
        )}
      </div>
    );
  }

  if (!canBan) return null;

  return (
    <form
      action={banPlayer}
      onSubmit={(e) => { if (!confirm("Issue this ban? Player will be kicked immediately.")) e.preventDefault(); }}
      className="rounded-lg border border-gray-700 bg-gray-800/40 p-4 space-y-2"
    >
      <div className="flex items-center gap-2 text-sm font-bold text-th-400">
        <Ban className="w-4 h-4" /> Issue Ban
      </div>
      <input type="hidden" name="playerid" value={uid} />
      <input
        name="reason"
        required
        placeholder="Reason…"
        className="w-full bg-gray-900 border border-gray-700 rounded px-3 py-2 text-sm text-gray-100"
      />
      <div className="flex items-center gap-2">
        <select name="duration" defaultValue="1d" className="flex-1 bg-gray-900 border border-gray-700 rounded px-2 py-2 text-sm text-gray-100">
          {durations.map(([k, label]) => (
            <option key={k} value={k}>{label}</option>
          ))}
        </select>
        <button className="px-4 py-2 rounded bg-red-600/30 border border-red-500/40 text-red-200 text-sm font-bold hover:bg-red-600/40">Ban</button>
      </div>
      {!isAdmin && <p className="text-xs text-gray-600">Mods can ban up to 3 days.</p>}
    </form>
  );
}
