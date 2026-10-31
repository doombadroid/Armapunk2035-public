"use client";

import { useState } from "react";
import Link from "next/link";
import { Banknote, ChevronDown, Search, Plus, Minus, Trash2, PackageSearch } from "lucide-react";
import { createCompRequest } from "@/lib/actions";
import { COMP_ITEMS } from "@/lib/compItems";

const FIELD = "w-full px-4 py-3 bg-gray-800 border border-gray-700 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-th-500";
const money = (n: number) => "$" + Math.round(n).toLocaleString("en-US");

export default function CompensationForm() {
  const [desc, setDesc] = useState("");
  const [open, setOpen] = useState(true);
  const [q, setQ] = useState("");
  const [sel, setSel] = useState<Record<string, number>>({});
  const [fileCount, setFileCount] = useState(0);

  const add = (c: string) => setSel((s) => ({ ...s, [c]: (s[c] ?? 0) + 1 }));
  const setQty = (c: string, n: number) => setSel((s) => { const x = { ...s }; if (n <= 0) delete x[c]; else x[c] = n; return x; });

  const term = q.trim().toLowerCase();
  const filtered = term ? COMP_ITEMS.filter((i) => i.name.toLowerCase().includes(term) || i.classname.toLowerCase().includes(term)) : COMP_ITEMS;
  const selItems = Object.entries(sel).map(([c, qty]) => ({ item: COMP_ITEMS.find((i) => i.classname === c), qty })).filter((x) => x.item);
  const total = selItems.reduce((s, x) => s + (x.item!.price * x.qty), 0);
  const itemsJson = JSON.stringify(selItems.map((x) => ({ c: x.item!.classname, q: x.qty })));

  return (
    <form action={createCompRequest} className="space-y-6">
      <input type="hidden" name="items" value={itemsJson} />

      <div>
        <label className="block text-sm font-bold text-gray-300 mb-2">Description <span className="text-th-400">*</span></label>
        <textarea name="description" required rows={6} maxLength={4000} value={desc} onChange={(e) => setDesc(e.target.value)}
          placeholder='Describe what happened and what you lost (e.g. "RDM&apos;d on the way to buyer, lost full loadout and vehicle")…'
          className={`${FIELD} resize-none`} />
        <p className="text-xs text-gray-500 mt-1">{desc.length} characters</p>
      </div>

      {/* item picker */}
      <div className="rounded-xl border border-gray-700 overflow-hidden bg-gray-900">
        <button type="button" onClick={() => setOpen((o) => !o)} className="w-full px-4 py-2.5 flex items-center gap-2 border-b border-gray-700 bg-gray-800/60 hover:bg-gray-800 transition text-left">
          <Banknote className="w-4 h-4 text-gray-400" />
          <span className="text-xs font-bold uppercase tracking-wider flex-1 text-gray-300">Items Requested</span>
          <span className="text-[10px] text-gray-500 mr-2">Optional</span>
          <ChevronDown className={`w-4 h-4 text-gray-500 transition-transform ${open ? "" : "-rotate-90"}`} />
        </button>
        {open && (
          <div className="px-4 py-4 space-y-3">
            <p className="text-xs text-gray-400">List the items you lost so staff can process faster. Prices sync with in-server values.</p>
            <div className="relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-gray-500 pointer-events-none" />
              <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Search items…"
                className="w-full pl-8 pr-3 py-1.5 bg-gray-800 border border-gray-700 rounded-lg text-white placeholder-gray-500 text-xs focus:outline-none focus:border-th-500" />
            </div>
            <div className="max-h-52 overflow-y-auto rounded-lg border border-gray-800 divide-y divide-gray-800">
              {filtered.slice(0, 250).map((i) => (
                <div key={i.classname} className="flex items-center justify-between px-3 py-2 hover:bg-gray-800/50">
                  <div className="min-w-0 mr-2"><p className="text-xs text-gray-200 truncate">{i.name}</p><p className="text-[10px] text-gray-500 truncate">{i.classname}</p></div>
                  <span className="text-xs text-gray-400 mr-3 shrink-0 tabular-nums">{money(i.price)}</span>
                  <button type="button" onClick={() => add(i.classname)} className="px-2 py-1 bg-gray-700 hover:bg-th-600 text-gray-300 hover:text-white text-xs rounded transition shrink-0">+ Add</button>
                </div>
              ))}
              {filtered.length === 0 && <div className="px-3 py-4 text-center text-xs text-gray-600">No items match.</div>}
            </div>
            {selItems.length === 0 ? (
              <div className="flex items-center gap-2 py-2 text-xs text-gray-600 italic"><PackageSearch className="w-4 h-4" /> No items added yet — use the catalog above.</div>
            ) : (
              <div className="space-y-1.5">
                {selItems.map(({ item, qty }) => (
                  <div key={item!.classname} className="flex items-center gap-2 text-xs bg-gray-800/50 rounded px-2 py-1.5">
                    <span className="flex-1 min-w-0 truncate text-gray-200">{item!.name}</span>
                    <button type="button" onClick={() => setQty(item!.classname, qty - 1)} className="p-1 text-gray-400 hover:text-white"><Minus className="w-3 h-3" /></button>
                    <span className="w-6 text-center tabular-nums text-gray-200">{qty}</span>
                    <button type="button" onClick={() => setQty(item!.classname, qty + 1)} className="p-1 text-gray-400 hover:text-white"><Plus className="w-3 h-3" /></button>
                    <span className="w-16 text-right tabular-nums text-gray-400">{money(item!.price * qty)}</span>
                    <button type="button" onClick={() => setQty(item!.classname, 0)} className="p-1 text-gray-500 hover:text-red-300"><Trash2 className="w-3 h-3" /></button>
                  </div>
                ))}
                <div className="flex justify-between text-xs font-bold text-gray-200 px-2 pt-1.5 border-t border-gray-800"><span>Total</span><span className="tabular-nums text-th-300">{money(total)}</span></div>
              </div>
            )}
          </div>
        )}
      </div>

      {/* attachments */}
      <div>
        <label className="block text-sm font-bold text-gray-300 mb-2">Attachments <span className="text-gray-500 font-normal">(optional)</span></label>
        <label className="inline-block px-4 py-2 bg-gray-700 hover:bg-gray-600 text-gray-300 text-sm font-medium rounded-lg cursor-pointer transition">
          + Attach Images
          <input name="images" type="file" accept=".jpg,.jpeg,.png" multiple className="hidden" onChange={(e) => setFileCount(Math.min(e.target.files?.length ?? 0, 5))} />
        </label>
        <span className="ml-3 text-xs text-gray-500">{fileCount > 0 ? `${fileCount} selected · ` : ""}Up to 5 images · JPG/PNG · 5MB each</span>
      </div>

      <div className="flex gap-3 pt-2">
        <button type="submit" className="flex-1 px-6 py-3 bg-th-600 hover:bg-th-700 text-white font-bold rounded-lg transition">Submit Request</button>
        <Link href="/support-tickets/new" className="px-6 py-3 bg-gray-800 hover:bg-gray-700 text-gray-300 font-bold rounded-lg transition">Change Category</Link>
      </div>
    </form>
  );
}
