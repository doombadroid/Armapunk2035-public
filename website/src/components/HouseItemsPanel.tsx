"use client";

import { useMemo, useState } from "react";
import { Home, Search, Plus, Trash2, Package, AlertTriangle } from "lucide-react";
import { HOUSE_VIRT_ITEMS, PHYS_ITEMS } from "@/lib/houseItems";
import { placeHouseItems } from "@/lib/actions";

type InvView = { items: [string, number][]; total: number };
type HouseView = {
  oid: string; id: number; label: string;
  vcap: number; phys_cap: number; virtual: InvView; physical: InvView;
};
type Staged = { classname: string; name: string; qty: number };

const NAME = new Map(HOUSE_VIRT_ITEMS.map((i) => [i.classname, i.name]));

export default function HouseItemsPanel({ houses, ownerOnline }: { houses: HouseView[]; ownerOnline: boolean }) {
  const [oid, setOid] = useState(houses[0]?.oid ?? "");
  const [type, setType] = useState<"virtual" | "physical">("virtual");
  const [staged, setStaged] = useState<Staged[]>([]);
  const [search, setSearch] = useState("");
  const [physClass, setPhysClass] = useState("");
  const [physQty, setPhysQty] = useState(1);

  const house = houses.find((h) => h.oid === oid) ?? houses[0];
  const inv = type === "physical" ? house?.physical : house?.virtual;
  const cap = type === "physical" ? house?.phys_cap : house?.vcap;

  const matches = useMemo(() => {
    const list = type === "physical" ? PHYS_ITEMS : HOUSE_VIRT_ITEMS;
    const s = search.trim().toLowerCase();
    if (!s) return list.slice(0, 8);
    return list.filter((i) =>
      i.name.toLowerCase().includes(s) || i.classname.toLowerCase().includes(s)).slice(0, 14);
  }, [search, type]);

  function reset() { setStaged([]); setSearch(""); setPhysClass(""); setPhysQty(1); }
  function switchType(t: "virtual" | "physical") { setType(t); reset(); }
  function switchHouse(o: string) { setOid(o); reset(); }

  function addStage(classname: string, name: string, qty: number) {
    if (!classname || qty <= 0) return;
    setStaged((cur) => {
      const i = cur.findIndex((x) => x.classname === classname);
      if (i >= 0) { const c = [...cur]; c[i] = { ...c[i], qty: c[i].qty + qty }; return c; }
      return [...cur, { classname, name: name || classname, qty }];
    });
  }
  const setQty = (cls: string, qty: number) =>
    setStaged((c) => c.map((x) => x.classname === cls ? { ...x, qty: Math.max(1, qty) } : x));
  const remove = (cls: string) => setStaged((c) => c.filter((x) => x.classname !== cls));

  if (houses.length === 0) {
    return <p className="text-sm text-gray-500">This player owns no houses.</p>;
  }

  return (
    <div className="space-y-4">
      {ownerOnline && (
        <div className="flex items-start gap-2 rounded-lg border border-amber-600/40 bg-amber-900/20 px-3 py-2 text-xs text-amber-300">
          <AlertTriangle className="w-4 h-4 shrink-0 mt-0.5" />
          <span>Owner is online. If they have this house&apos;s storage open, closing it will overwrite this edit — have them close it first, or edit while they&apos;re away. Changes appear the next time the storage is opened.</span>
        </div>
      )}

      {/* house picker */}
      {houses.length > 1 && (
        <div className="flex flex-wrap gap-2">
          {houses.map((h) => (
            <button key={h.oid} onClick={() => switchHouse(h.oid)}
              className={`inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold border transition ${
                h.oid === oid ? "bg-th-600/20 border-th-700/40 text-th-300" : "bg-gray-800 border-gray-700 text-gray-400 hover:text-gray-200"}`}>
              <Home className="w-3.5 h-3.5" /> {h.label} <span className="text-gray-600">#{h.id}</span>
            </button>
          ))}
        </div>
      )}

      {/* type tabs + capacity */}
      <div className="flex items-center justify-between gap-3 flex-wrap">
        <div className="inline-flex rounded-lg border border-gray-700 overflow-hidden">
          {(["virtual", "physical"] as const).map((t) => (
            <button key={t} onClick={() => switchType(t)}
              className={`px-3 py-1.5 text-xs font-bold capitalize transition ${type === t ? "bg-th-600 text-white" : "bg-gray-800 text-gray-400 hover:text-gray-200"}`}>{t}</button>
          ))}
        </div>
        <span className="text-xs text-gray-500">
          Used <span className={inv && cap && inv.total > cap ? "text-amber-400 font-bold" : "text-gray-300 font-bold"}>{inv?.total ?? 0}</span> / {cap ?? 0}
          {inv && cap && inv.total > cap ? " (over cap — safe)" : ""}
        </span>
      </div>

      {/* current contents */}
      {inv && inv.items.length > 0 && (
        <details className="text-xs">
          <summary className="cursor-pointer text-gray-500 hover:text-gray-300">Current contents ({inv.items.length})</summary>
          <div className="mt-2 flex flex-wrap gap-1.5">
            {inv.items.map(([c, q]) => (
              <span key={c} className="px-2 py-0.5 rounded bg-gray-800 border border-gray-700 text-gray-400">
                {NAME.get(c) ?? c} <span className="text-gray-600">×{q}</span>
              </span>
            ))}
          </div>
        </details>
      )}

      {/* add items — searchable picker (matches display name OR classname) for both tabs */}
      <div>
        <div className="relative">
          <Search className="absolute left-2.5 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500" />
          <input value={search} onChange={(e) => setSearch(e.target.value)}
            placeholder={type === "physical" ? "Search weapons, gear, mags… (name or classname)" : "Search virtual items…"}
            className="w-full pl-9 pr-3 py-2 bg-gray-800 border border-gray-700 rounded-lg text-sm text-gray-100 placeholder-gray-500 focus:outline-none focus:border-th-500" />
        </div>
        <div className="mt-2 flex flex-wrap gap-1.5">
          {matches.map((i) => (
            <button key={i.classname} onClick={() => addStage(i.classname, i.name, 1)} title={i.classname}
              className="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg bg-gray-800 border border-gray-700 text-xs text-gray-300 hover:border-th-600 hover:text-white transition">
              <Plus className="w-3 h-3" /> {i.name}
            </button>
          ))}
          {matches.length === 0 && <span className="text-xs text-gray-600">No matches — use the exact-classname box below.</span>}
        </div>

        {type === "physical" && (
          <div className="mt-3 flex gap-2 items-end flex-wrap border-t border-gray-800 pt-3">
            <label className="flex-1 min-w-[12rem]">
              <span className="text-xs text-gray-500">Not listed? Enter exact classname</span>
              <input value={physClass} onChange={(e) => setPhysClass(e.target.value.replace(/[^A-Za-z0-9_]/g, ""))}
                placeholder="e.g. arifle_MX_khk_F"
                className="mt-1 w-full px-3 py-2 bg-gray-800 border border-gray-700 rounded-lg text-sm text-gray-100 placeholder-gray-600 focus:outline-none focus:border-th-500 font-mono" />
            </label>
            <label>
              <span className="text-xs text-gray-500">Qty</span>
              <input type="number" min={1} value={physQty} onChange={(e) => setPhysQty(Math.max(1, Number(e.target.value) || 1))}
                className="mt-1 w-20 px-2 py-2 bg-gray-800 border border-gray-700 rounded-lg text-sm text-gray-100 focus:outline-none focus:border-th-500" />
            </label>
            <button onClick={() => { addStage(physClass, physClass, physQty); setPhysClass(""); setPhysQty(1); }}
              disabled={!physClass}
              className="px-3 py-2 rounded-lg bg-th-600/20 border border-th-700/40 text-th-300 text-sm font-bold hover:bg-th-600/30 disabled:opacity-40 transition">Add</button>
          </div>
        )}
      </div>

      {/* staged list + submit */}
      {staged.length > 0 && (
        <form action={placeHouseItems} className="rounded-lg border border-gray-700 bg-gray-900/50 p-3 space-y-2">
          <input type="hidden" name="oid" value={oid} />
          <input type="hidden" name="invtype" value={type} />
          <input type="hidden" name="items" value={JSON.stringify(staged.map((x) => ({ classname: x.classname, qty: x.qty })))} />
          <p className="text-xs font-bold text-gray-400 uppercase tracking-wider">To place — {type} · {house?.label}</p>
          {staged.map((x) => (
            <div key={x.classname} className="flex items-center gap-2 text-sm">
              <span className="flex-1 truncate text-gray-200">{x.name}{x.name !== x.classname ? <span className="text-gray-600 font-mono ml-1">{x.classname}</span> : null}</span>
              <input type="number" min={1} value={x.qty} onChange={(e) => setQty(x.classname, Number(e.target.value) || 1)}
                className="w-20 px-2 py-1 bg-gray-800 border border-gray-700 rounded text-sm text-gray-100 focus:outline-none focus:border-th-500" />
              <button type="button" onClick={() => remove(x.classname)} className="text-gray-500 hover:text-red-400"><Trash2 className="w-4 h-4" /></button>
            </div>
          ))}
          <button type="submit" className="w-full mt-1 inline-flex items-center justify-center gap-2 px-4 py-2 bg-th-600 hover:bg-th-700 text-white text-sm font-bold rounded-lg transition">
            <Package className="w-4 h-4" /> Place {staged.reduce((n, x) => n + x.qty, 0)} item(s) in house
          </button>
        </form>
      )}
    </div>
  );
}
