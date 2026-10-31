import { Wrench } from "lucide-react";
import { SectionCard, Badge } from "@/components/ui";
import { setGangFunds } from "@/lib/actions";

const NUM = "bg-gray-800 border border-gray-700 rounded px-2 py-1 text-sm text-gray-100 focus:outline-none focus:border-th-500";

function FundRow({ gangId, field, label, value }: { gangId: number; field: string; label: string; value: number }) {
  return (
    <form action={setGangFunds} className="flex items-center gap-2">
      <input type="hidden" name="gang_id" value={gangId} />
      <input type="hidden" name="field" value={field} />
      <span className="text-xs text-gray-400 w-24 shrink-0">{label}</span>
      <input name="amount" type="number" min={0} step={1} defaultValue={value} className={`${NUM} flex-1 min-w-0 tabular-nums`} />
      <button className="px-3 py-1 rounded bg-th-600/20 border border-th-700/40 text-th-300 text-xs font-bold hover:bg-th-600/30 transition">Set</button>
    </form>
  );
}

export default function GangAdminPanel({ gangId, bank, experience }: { gangId: number; bank: number; experience: number }) {
  return (
    <SectionCard title="Admin Controls" icon={<Wrench className="w-4 h-4" />} right={<Badge color="red">Staff</Badge>}>
      <div className="space-y-2 pt-1 max-w-md">
        <FundRow gangId={gangId} field="bank" label="Bank" value={bank} />
        <FundRow gangId={gangId} field="xp" label="Experience" value={experience} />
      </div>
    </SectionCard>
  );
}
