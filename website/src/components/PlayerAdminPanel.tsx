import { Wrench, DollarSign, Shield, Stethoscope, Crown, Car, Plus, Trash2, AlertTriangle, History } from "lucide-react";
import { SectionCard, Badge } from "@/components/ui";
import { FACTIONS, maxGrant, type Faction, type ActorPowers } from "@/lib/factions";
import type { VehicleRow, PlayerDetail } from "@/lib/types";
import type { AdminLogRow } from "@/lib/queries";
import { setFactionRank, setFactionSub, setPlayerMoney, addPlayerVehicle, removePlayerVehicle } from "@/lib/actions";
import { relative } from "@/lib/format";

const NUM = "bg-gray-800 border border-gray-700 rounded px-2 py-1 text-sm text-gray-100 focus:outline-none focus:border-th-500";

function RankSet({ f, uid, current, mg }: { f: Faction; uid: string; current: number; mg: number }) {
  const opts = Array.from({ length: mg + 1 }, (_, i) => i);
  return (
    <form action={setFactionRank} className="flex items-center gap-2 flex-wrap">
      <input type="hidden" name="faction" value={f.key} />
      <input type="hidden" name="target" value={uid} />
      <select name="new_rank" defaultValue={current >= 1 && current <= mg ? current : 0} className={`${NUM} max-w-[11rem]`}>
        {opts.map((r) => <option key={r} value={r}>{r === 0 ? "Remove (Civilian)" : `${r} · ${f.ranks[r]}`}</option>)}
      </select>
      <button className="px-3 py-1 rounded bg-th-600/20 border border-th-700/40 text-th-300 text-xs font-bold hover:bg-th-600/30 transition">Set</button>
    </form>
  );
}

function SubToggle({ f, uid, sub, label, on }: { f: Faction; uid: string; sub: string; label: string; on: boolean }) {
  return (
    <form action={setFactionSub}>
      <input type="hidden" name="faction" value={f.key} />
      <input type="hidden" name="target" value={uid} />
      <input type="hidden" name="sub" value={sub} />
      <input type="hidden" name="value" value={on ? 0 : 1} />
      <button className={`px-2 py-1 rounded text-xs font-bold border transition ${on ? "bg-purple-600/20 border-purple-600/40 text-purple-300" : "bg-gray-800 border-gray-700 text-gray-500 hover:text-gray-300"}`}>
        {on ? "✓ " : ""}{label}
      </button>
    </form>
  );
}

function MoneyRow({ uid, field, label, value, step = 1 }: { uid: string; field: string; label: string; value: number; step?: number }) {
  return (
    <form action={setPlayerMoney} className="flex items-center gap-2">
      <input type="hidden" name="target" value={uid} />
      <input type="hidden" name="field" value={field} />
      <span className="text-xs text-gray-400 w-24 shrink-0">{label}</span>
      <input name="amount" type="number" min={0} step={step} defaultValue={value} className={`${NUM} flex-1 min-w-0 tabular-nums`} />
      <button className="px-3 py-1 rounded bg-th-600/20 border border-th-700/40 text-th-300 text-xs font-bold hover:bg-th-600/30 transition">Set</button>
    </form>
  );
}

export default function PlayerAdminPanel({
  p, vehicles, powers, online, log,
}: { p: PlayerDetail; vehicles: VehicleRow[]; powers: ActorPowers; online: boolean; log: AdminLogRow[] }) {
  const canEcon = powers.isOwner || powers.adminlevel >= 3;
  const mgPolice = maxGrant(FACTIONS.police, powers);
  const mgMedic = maxGrant(FACTIONS.medic, powers);
  const mgStaff = maxGrant(FACTIONS.staff, powers); // owner-only
  const anyRank = mgPolice >= 0 || mgMedic >= 0 || mgStaff >= 0;
  if (!canEcon && !anyRank) return null;

  return (
    <SectionCard title="Admin Controls" icon={<Wrench className="w-4 h-4" />} right={<Badge color="red">Staff</Badge>}>
      <div className="grid gap-5 md:grid-cols-2 pt-1">
        {/* money */}
        {canEcon && (
          <div className="space-y-2">
            <p className="text-xs font-bold text-th-400 uppercase tracking-wider flex items-center gap-1.5"><DollarSign className="w-3.5 h-3.5" /> Money</p>
            {online && (
              <div className="flex items-start gap-2 text-xs text-amber-300 bg-amber-900/20 border border-amber-700/40 rounded-lg px-3 py-2">
                <AlertTriangle className="w-3.5 h-3.5 shrink-0 mt-0.5" />
                <span>Player is <b>online</b> — the game may overwrite this on its next save. Kick them first for it to stick.</span>
              </div>
            )}
            <MoneyRow uid={p.uid} field="cash" label="Cash" value={p.cash} />
            <MoneyRow uid={p.uid} field="bank" label="Bank" value={p.bank} />
            <MoneyRow uid={p.uid} field="nd" label="New Drachma" value={p.newDrachma} step={0.0001} />
          </div>
        )}

        {/* ranks */}
        {anyRank && (
          <div className="space-y-3">
            <p className="text-xs font-bold text-th-400 uppercase tracking-wider">Ranks</p>
            {mgPolice >= 0 && (
              <div className="space-y-1.5">
                <span className="text-xs text-gray-400 flex items-center gap-1.5"><Shield className="w-3.5 h-3.5 text-blue-400" /> MaxSec (Police)</span>
                <RankSet f={FACTIONS.police} uid={p.uid} current={p.copLevel} mg={mgPolice} />
                <div className="flex gap-1.5">
                  {FACTIONS.police.subs.map((s) => (
                    <SubToggle key={s.key} f={FACTIONS.police} uid={p.uid} sub={s.key} label={s.label}
                      on={s.key === "maxtac" ? p.isMaxTac : s.key === "scd" ? p.isSCD : false} />
                  ))}
                </div>
              </div>
            )}
            {mgMedic >= 0 && (
              <div className="space-y-1.5">
                <span className="text-xs text-gray-400 flex items-center gap-1.5"><Stethoscope className="w-3.5 h-3.5 text-emerald-400" /> Trauma Team</span>
                <RankSet f={FACTIONS.medic} uid={p.uid} current={p.medicLevel} mg={mgMedic} />
              </div>
            )}
            {mgStaff >= 0 && (
              <div className="space-y-1.5">
                <span className="text-xs text-gray-400 flex items-center gap-1.5"><Crown className="w-3.5 h-3.5 text-amber-400" /> Server Staff (owner)</span>
                <RankSet f={FACTIONS.staff} uid={p.uid} current={p.adminLevel} mg={mgStaff} />
              </div>
            )}
          </div>
        )}

        {/* vehicles */}
        {canEcon && (
          <div className="space-y-2 md:col-span-2">
            <p className="text-xs font-bold text-th-400 uppercase tracking-wider flex items-center gap-1.5"><Car className="w-3.5 h-3.5" /> Grant a vehicle</p>
            <form action={addPlayerVehicle} className="flex items-end gap-2 flex-wrap">
              <input type="hidden" name="target" value={p.uid} />
              <select name="side" defaultValue="civ" className={NUM}>
                <option value="civ">Civ</option><option value="cop">Cop</option><option value="med">TT</option>
              </select>
              <select name="vtype" defaultValue="Car" className={NUM}>
                <option value="Car">Car</option><option value="Air">Air</option><option value="Ship">Ship</option><option value="Sea">Sea</option>
              </select>
              <input name="classname" required placeholder="Classname e.g. B_MRAP_01_F" className={`${NUM} flex-1 min-w-[14rem] font-mono`} />
              <button className="px-3 py-1.5 rounded bg-th-600 hover:bg-th-700 text-white text-xs font-bold inline-flex items-center gap-1"><Plus className="w-3.5 h-3.5" /> Add</button>
            </form>
            {vehicles.length > 0 && (
              <ul className="divide-y divide-gray-800 border border-gray-800 rounded-lg max-h-56 overflow-y-auto mt-2">
                {vehicles.map((v) => (
                  <li key={v.id} className="flex items-center justify-between px-3 py-1.5 text-xs">
                    <span className="flex items-center gap-2 min-w-0">
                      <Badge color={v.side === "cop" ? "blue" : v.side === "med" ? "emerald" : "th"}>{v.side}</Badge>
                      <span className="font-mono text-gray-300 truncate">{v.classname}</span>
                      <span className="text-gray-600">{v.customplate || v.plate}</span>
                    </span>
                    <form action={removePlayerVehicle}>
                      <input type="hidden" name="vehicle_id" value={v.id} />
                      <input type="hidden" name="target" value={p.uid} />
                      <button title="Remove vehicle" className="p-1 text-gray-500 hover:text-red-300 transition"><Trash2 className="w-3.5 h-3.5" /></button>
                    </form>
                  </li>
                ))}
              </ul>
            )}
          </div>
        )}

        {/* recent admin edits */}
        {canEcon && log.length > 0 && (
          <div className="md:col-span-2 pt-2 border-t border-gray-800">
            <p className="text-xs font-bold text-gray-500 uppercase tracking-wider flex items-center gap-1.5 mb-2"><History className="w-3.5 h-3.5" /> Recent admin edits</p>
            <ul className="space-y-1">
              {log.map((l) => (
                <li key={l.id} className="text-xs text-gray-500">
                  <span className="text-gray-400 font-semibold">{l.actor_name}</span> · {l.action} · {l.detail} <span className="text-gray-600">· {relative(l.ts)}</span>
                </li>
              ))}
            </ul>
          </div>
        )}
      </div>
    </SectionCard>
  );
}
