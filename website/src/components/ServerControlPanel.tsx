"use client";

import { useEffect, useState } from "react";
import { Lock, Unlock, RotateCcw, Power, Package, AlertTriangle, X } from "lucide-react";
import { setServerLock, queueServerRestart, cancelServerRestart } from "@/lib/actions";

type Props = {
  isOwner: boolean;
  state: {
    locked: boolean;
    lockBy: string | null;
    cmd: string | null;        // 'soft' | 'hard' | 'update' | null
    cmdStatus: string | null;  // 'queued' | 'warning' | ...
    cmdBy: string | null;
    etaMs: number | null;      // epoch ms of the scheduled restart, or null
  };
};

const SECS = [
  { v: 0, label: "Now (no warning)" },
  { v: 60, label: "60 seconds" },
  { v: 300, label: "5 minutes" },
];

function useCountdown(etaMs: number | null): number | null {
  const [remaining, setRemaining] = useState<number | null>(null);
  useEffect(() => {
    if (!etaMs) { setRemaining(null); return; }
    const tick = () => setRemaining(Math.max(0, Math.round((etaMs - Date.now()) / 1000)));
    tick();
    const id = setInterval(tick, 1000);
    return () => clearInterval(id);
  }, [etaMs]);
  return remaining;
}

function fmt(s: number): string {
  const m = Math.floor(s / 60), r = s % 60;
  return m > 0 ? `${m}m ${r}s` : `${r}s`;
}

export default function ServerControlPanel({ isOwner, state }: Props) {
  const [secs, setSecs] = useState(60);
  const [confirm, setConfirm] = useState("");
  const armed = confirm.trim().toUpperCase() === "RESTART";
  const pending = state.cmd != null && ["queued", "warning", "saving"].includes(state.cmdStatus ?? "");
  const remaining = useCountdown(pending ? state.etaMs : null);

  const cmdLabel = state.cmd === "update" ? "Update PBO + restart"
    : state.cmd === "soft" ? "Soft restart"
    : state.cmd === "hard" ? "Hard restart" : "";

  return (
    <div className="space-y-6">
      {/* pending restart banner */}
      {pending && (
        <div className="rounded-xl border border-amber-600/50 bg-amber-900/20 p-4 flex items-center gap-4">
          <AlertTriangle className="w-6 h-6 text-amber-400 shrink-0" />
          <div className="flex-1 min-w-0">
            <p className="text-amber-200 font-bold">{cmdLabel} in progress</p>
            <p className="text-xs text-amber-300/80 mt-0.5">
              {remaining != null ? `Restarting in ${fmt(remaining)}` : "Warning players…"}
              {state.cmdBy ? ` · queued by ${state.cmdBy}` : ""}
            </p>
          </div>
          <form action={cancelServerRestart}>
            <button className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-gray-800 hover:bg-gray-700 text-gray-200 text-sm font-bold rounded-lg transition">
              <X className="w-4 h-4" /> Cancel
            </button>
          </form>
        </div>
      )}

      {/* lock */}
      <section className="rounded-xl border border-gray-800 bg-gray-900/60 p-5">
        <div className="flex items-center justify-between gap-4 flex-wrap">
          <div>
            <h3 className="font-bold text-gray-100 flex items-center gap-2">
              {state.locked ? <Lock className="w-4 h-4 text-red-400" /> : <Unlock className="w-4 h-4 text-green-400" />}
              Server Lock
            </h3>
            <p className="text-xs text-gray-500 mt-1">
              {state.locked
                ? <span className="text-red-300">Locked — new players cannot join.{state.lockBy ? ` (by ${state.lockBy})` : ""}</span>
                : "Open — players can join normally. Locking blocks new joins; current players stay connected."}
            </p>
          </div>
          <form action={setServerLock}>
            <input type="hidden" name="lock" value={state.locked ? "0" : "1"} />
            <button className={`inline-flex items-center gap-2 px-4 py-2 text-sm font-bold rounded-lg transition ${
              state.locked
                ? "bg-green-700 hover:bg-green-600 text-white"
                : "bg-red-700 hover:bg-red-600 text-white"}`}>
              {state.locked ? <><Unlock className="w-4 h-4" /> Unlock Server</> : <><Lock className="w-4 h-4" /> Lock Server</>}
            </button>
          </form>
        </div>
      </section>

      {/* reboot */}
      <section className="rounded-xl border border-gray-800 bg-gray-900/60 p-5 space-y-4">
        <div>
          <h3 className="font-bold text-gray-100 flex items-center gap-2"><RotateCcw className="w-4 h-4 text-th-400" /> Restart Server</h3>
          <p className="text-xs text-gray-500 mt-1">Players are graceful-saved (vehicles, trunks, progress) before every restart.</p>
        </div>

        <div className="grid sm:grid-cols-2 gap-4">
          <label className="block">
            <span className="text-xs font-bold text-gray-400 uppercase tracking-wider">Warning countdown</span>
            <select value={secs} onChange={(e) => setSecs(Number(e.target.value))}
              className="mt-1.5 w-full px-3 py-2 bg-gray-800 border border-gray-700 rounded-lg text-sm text-gray-100 focus:outline-none focus:border-th-500">
              {SECS.map((o) => <option key={o.v} value={o.v}>{o.label}</option>)}
            </select>
          </label>
          <label className="block">
            <span className="text-xs font-bold text-gray-400 uppercase tracking-wider">Type <span className="text-th-400 font-mono">RESTART</span> to confirm</span>
            <input value={confirm} onChange={(e) => setConfirm(e.target.value)} placeholder="RESTART" autoComplete="off"
              className="mt-1.5 w-full px-3 py-2 bg-gray-800 border border-gray-700 rounded-lg text-sm text-gray-100 placeholder-gray-600 focus:outline-none focus:border-th-500" />
          </label>
        </div>

        <div className="flex gap-3 flex-wrap pt-1">
          <RebootButton mode="soft" secs={secs} confirm={confirm} disabled={!armed || pending}
            className="bg-th-600 hover:bg-th-700" icon={<RotateCcw className="w-4 h-4" />} label="Soft Restart" />
          <RebootButton mode="hard" secs={secs} confirm={confirm} disabled={!armed || pending}
            className="bg-orange-700 hover:bg-orange-600" icon={<Power className="w-4 h-4" />} label="Hard Restart" />
          {isOwner && (
            <RebootButton mode="update" secs={secs} confirm={confirm} disabled={!armed || pending}
              className="bg-purple-700 hover:bg-purple-600" icon={<Package className="w-4 h-4" />} label="Update PBO + Restart" />
          )}
        </div>
        <div className="text-xs text-gray-600 space-y-0.5 pt-1">
          <p><b className="text-gray-400">Soft</b> — warn, save, relaunch the deployed build. <b className="text-gray-400">Hard</b> — same, faster/less ceremony.</p>
          {isOwner && <p><b className="text-purple-300">Update PBO</b> — repack + deploy the staged code, then restart. Owner only.</p>}
        </div>
      </section>
    </div>
  );
}

function RebootButton({ mode, secs, confirm, disabled, className, icon, label }: {
  mode: string; secs: number; confirm: string; disabled: boolean; className: string; icon: React.ReactNode; label: string;
}) {
  return (
    <form action={queueServerRestart}>
      <input type="hidden" name="mode" value={mode} />
      <input type="hidden" name="secs" value={secs} />
      <input type="hidden" name="confirm" value={confirm} />
      <button disabled={disabled}
        className={`inline-flex items-center gap-2 px-4 py-2.5 text-white text-sm font-bold rounded-lg transition disabled:opacity-40 disabled:cursor-not-allowed ${className}`}>
        {icon} {label}
      </button>
    </form>
  );
}
