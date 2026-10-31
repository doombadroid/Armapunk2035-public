"use client";

import { useState } from "react";
import Link from "next/link";
import { CircleAlert, ChevronDown, Check, Lock } from "lucide-react";
import { createGuidedTicket, createMaxSecApplication, createTTApplication } from "@/lib/actions";
import type { FieldSpec, FormSpec } from "@/lib/ticketCategories";

const FIELD = "w-full px-4 py-3 bg-gray-800 border border-gray-700 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-th-500";

function Field({ f, unlocked, count, onCount }: {
  f: FieldSpec; unlocked: boolean; count: number; onCount: (n: number) => void;
}) {
  const req = unlocked && f.required;
  return (
    <div>
      <label className="block text-sm font-bold text-gray-300 mb-2">
        {f.label} {f.required && <span className="text-th-400">*</span>}
      </label>
      {f.help && <p className="text-xs text-gray-500 mb-2">{f.help}</p>}
      {f.type === "textarea" ? (
        <>
          <textarea name={f.name} required={req} rows={f.rows ?? 6} maxLength={4000}
            placeholder={f.placeholder} onChange={(e) => onCount(e.target.value.length)}
            className={`${FIELD} resize-none`} />
          <p className="text-xs text-gray-500 mt-1">{count} characters</p>
        </>
      ) : f.type === "datetime" ? (
        <input name={f.name} type="datetime-local" required={req} className={`${FIELD} [color-scheme:dark]`} />
      ) : f.type === "yesno" || f.type === "radio" ? (
        <div className="flex gap-4 flex-wrap">
          {(f.type === "yesno" ? ["Yes", "No"] : f.options ?? []).map((opt, i) => (
            <label key={opt} className="flex items-center gap-2 cursor-pointer">
              <input type="radio" name={f.name} value={opt} required={req} defaultChecked={i === 0 && f.type === "radio"} className="w-4 h-4 accent-th-500" />
              <span className="text-gray-300">{opt}</span>
            </label>
          ))}
        </div>
      ) : (
        <input name={f.name} type="text" required={req} placeholder={f.placeholder} className={FIELD} />
      )}
    </div>
  );
}

export default function GuidedTicketForm({ category, spec, variant = "ticket" }: {
  category: string; spec: FormSpec; variant?: "ticket" | "maxsec" | "tt";
}) {
  const isApp = variant === "maxsec" || variant === "tt";
  const appAction = variant === "tt" ? createTTApplication : createMaxSecApplication;
  const backHref = variant === "tt" ? "/trauma-team" : "/maxsec";
  const hasGate = !!spec.gate;
  const [confirmed, setConfirmed] = useState(!hasGate);
  const [open, setOpen] = useState(true);
  const [counts, setCounts] = useState<Record<string, number>>({});
  const unlocked = !hasGate || confirmed;

  return (
    <form action={isApp ? appAction : createGuidedTicket} className="space-y-6">
      <input type="hidden" name="category" value={category} />

      {spec.gate && (
        <div className={`rounded-xl border overflow-hidden ${confirmed ? "border-green-600/40 bg-green-900/10" : "border-amber-600/40 bg-amber-900/20"}`}>
          <button type="button" onClick={() => setOpen((o) => !o)}
            className={`w-full px-4 py-2.5 flex items-center gap-2 border-b transition ${confirmed ? "border-green-600/40 bg-green-900/40 hover:bg-green-900/60" : "border-amber-600/40 bg-amber-900/40 hover:bg-amber-900/50"}`}>
            <CircleAlert className={`w-4 h-4 shrink-0 ${confirmed ? "text-green-400" : "text-amber-400"}`} />
            <span className={`text-xs font-bold uppercase tracking-wider flex-1 text-left ${confirmed ? "text-green-300" : "text-amber-300"}`}>{spec.gate.title}</span>
            {confirmed ? <Check className="w-4 h-4 text-green-400 shrink-0" /> : <ChevronDown className={`w-4 h-4 text-amber-400 shrink-0 transition-transform ${open ? "" : "-rotate-90"}`} />}
          </button>
          <div className={`transition-all duration-300 ease-in-out ${open ? "max-h-[1200px] opacity-100" : "max-h-0 opacity-0"} overflow-hidden`}>
            <div className="px-4 py-4 space-y-4">
              {spec.gate.intro && <h4 className="text-sm font-bold text-gray-200">{spec.gate.intro}</h4>}
              <ul className="text-xs text-gray-300 space-y-1.5 list-disc list-inside">
                {spec.gate.bullets.map((b, i) => <li key={i}>{b}</li>)}
              </ul>
              {spec.gate.info && (
                <div>
                  <h4 className="text-sm font-bold text-gray-200 mb-2">Important information</h4>
                  <ul className="text-xs text-gray-300 space-y-1.5 list-disc list-inside">
                    {spec.gate.info.map((b, i) => <li key={i}>{b}</li>)}
                  </ul>
                </div>
              )}
            </div>
            <div className={`px-4 py-3 border-t ${confirmed ? "border-green-600/40 bg-green-900/20" : "border-amber-600/40 bg-amber-900/30"}`}>
              <label className="flex items-start gap-3 cursor-pointer">
                <input type="checkbox" name="confirm" value="1" checked={confirmed}
                  onChange={(e) => { setConfirmed(e.target.checked); if (e.target.checked) setOpen(false); }}
                  className="mt-1 w-4 h-4 accent-th-500" />
                <span className="text-xs text-gray-400">{spec.gate.checkboxLabel}</span>
              </label>
            </div>
          </div>
        </div>
      )}

      {hasGate && !confirmed && (
        <div className="flex items-center gap-3 px-4 py-3 rounded-lg border border-gray-700 bg-gray-800/40 text-sm text-gray-500">
          <Lock className="w-4 h-4 shrink-0" /> <span>Confirm the requirements above to unlock the form.</span>
        </div>
      )}

      <div className={hasGate ? `transition-all duration-500 ease-in-out overflow-hidden ${confirmed ? "max-h-[4000px] opacity-100" : "max-h-0 opacity-0 pointer-events-none"}` : ""}>
        <div className={`space-y-4 ${hasGate ? "pt-4 border-t border-gray-700" : ""}`}>
          {spec.fields.map((f) => (
            <Field key={f.name} f={f} unlocked={unlocked}
              count={counts[f.name] ?? 0} onCount={(n) => setCounts((c) => ({ ...c, [f.name]: n }))} />
          ))}
        </div>
      </div>

      {/* attachments (support tickets only — maxsec_applications has no attachment store) */}
      {!isApp && (
        <div>
          <label className="block text-sm font-bold text-gray-300 mb-2">Attachments <span className="text-gray-500 font-normal">(optional)</span></label>
          <label className="inline-block px-4 py-2 bg-gray-700 hover:bg-gray-600 text-gray-300 text-sm font-medium rounded-lg cursor-pointer transition">
            + Attach Images
            <input name="images" type="file" accept=".jpg,.jpeg,.png" multiple className="hidden"
              onChange={(e) => setCounts((c) => ({ ...c, __files: Math.min(e.target.files?.length ?? 0, 5) }))} />
          </label>
          <span className="ml-3 text-xs text-gray-500">{(counts.__files ?? 0) > 0 ? `${counts.__files} selected · ` : ""}Up to 5 images · JPG/PNG · 5MB each</span>
        </div>
      )}

      <div className="flex gap-3 pt-2">
        <button type="submit" disabled={hasGate && !confirmed}
          className="flex-1 px-6 py-3 bg-th-600 hover:bg-th-700 disabled:opacity-50 disabled:cursor-not-allowed text-white font-bold rounded-lg transition">
          {isApp ? "Submit Application" : "Submit Ticket"}
        </button>
        <Link href={isApp ? backHref : "/support-tickets/new"} className="px-6 py-3 bg-gray-800 hover:bg-gray-700 text-gray-300 font-bold rounded-lg transition">
          {isApp ? "Cancel" : "Change Category"}
        </Link>
      </div>
    </form>
  );
}
