"use client";

import Link from "next/link";
import { useRef, useState, useCallback } from "react";
import { Plus, Minus, Maximize, Home, MapPin } from "lucide-react";
import { money, houseTypeName, gridRef } from "@/lib/format";
import type { HouseSale } from "@/lib/queries";

// The satellite (public/malden-map.jpg) is the full Malden 2035 island: the 256-tier atlas from
// tools/bake_sat_atlas.py, 0..12800 m on both axes, so world->image is a plain scale. The CAL
// shape is kept (island fraction of the image + world bbox) so a cropped image can be calibrated
// again by editing four numbers.
const CAL = {
  ix0: 0, ix1: 100, iy0: 0, iy1: 100,          // island fraction of the image
  wx0: 0, wx1: 12800, wyS: 0, wyN: 12800,      // world bbox (Malden MAP_M = 12800)
};
// Towns for geographic context -- positions from the mission's own markers (spawns / stations).
const TOWNS: { n: string; x: number; y: number }[] = [
  { n: "La Trinité", x: 7264, y: 7931 }, { n: "Larche", x: 6027, y: 8640 },
  { n: "Chapoi", x: 5559, y: 4234 }, { n: "La Port", x: 8300, y: 3240 },
  { n: "La Pessagne", x: 3367, y: 6292 },
];
const pct = (x: number, y: number) => ({
  left: CAL.ix0 + ((x - CAL.wx0) / (CAL.wx1 - CAL.wx0)) * (CAL.ix1 - CAL.ix0),
  top: CAL.iy0 + ((CAL.wyN - y) / (CAL.wyN - CAL.wyS)) * (CAL.iy1 - CAL.iy0),
});
const clamp = (v: number, a: number, b: number) => Math.min(b, Math.max(a, v));

function tier(p: number) {
  return p >= 4_000_000 ? "rose" : p >= 2_000_000 ? "amber" : "emerald";
}
const DOT: Record<string, string> = {
  rose: "bg-rose-500 ring-rose-400/40", amber: "bg-amber-500 ring-amber-400/40", emerald: "bg-emerald-500 ring-emerald-400/40",
};

export default function HouseMap({ houses }: { houses: HouseSale[] }) {
  const [zoom, setZoom] = useState(1);
  const [pan, setPan] = useState({ x: 0, y: 0 });
  const [sel, setSel] = useState<number | null>(null);
  const box = useRef<HTMLDivElement>(null);
  const drag = useRef<{ on: boolean; x: number; y: number; moved: boolean }>({ on: false, x: 0, y: 0, moved: false });

  const zoomAt = useCallback((cx: number, cy: number, factor: number) => {
    setZoom((z) => {
      const nz = clamp(z * factor, 1, 9);
      setPan((p) => {
        const wx = (cx - p.x) / z, wy = (cy - p.y) / z;
        return { x: cx - wx * nz, y: cy - wy * nz };
      });
      return nz;
    });
  }, []);

  const onWheel = (e: React.WheelEvent) => {
    const r = box.current!.getBoundingClientRect();
    zoomAt(e.clientX - r.left, e.clientY - r.top, e.deltaY < 0 ? 1.2 : 1 / 1.2);
  };
  const onDown = (e: React.PointerEvent) => {
    drag.current = { on: true, x: e.clientX, y: e.clientY, moved: false };
    (e.target as HTMLElement).setPointerCapture?.(e.pointerId);
  };
  const onMove = (e: React.PointerEvent) => {
    if (!drag.current.on) return;
    const dx = e.clientX - drag.current.x, dy = e.clientY - drag.current.y;
    if (Math.abs(dx) + Math.abs(dy) > 3) drag.current.moved = true;
    drag.current.x = e.clientX; drag.current.y = e.clientY;
    setPan((p) => ({ x: p.x + dx, y: p.y + dy }));
  };
  const onUp = () => { drag.current.on = false; };
  const reset = () => { setZoom(1); setPan({ x: 0, y: 0 }); };
  const ctrZoom = (f: number) => { const r = box.current!.getBoundingClientRect(); zoomAt(r.width / 2, r.height / 2, f); };

  const selected = houses.find((h) => h.id === sel) ?? null;

  return (
    <div className="grid gap-4 lg:grid-cols-3">
      {/* map */}
      <div className="lg:col-span-2">
        <div
          ref={box}
          onWheel={onWheel}
          onPointerDown={onDown}
          onPointerMove={onMove}
          onPointerUp={onUp}
          onPointerLeave={onUp}
          className="relative aspect-square w-full overflow-hidden rounded-xl border border-th-700/30 bg-[#0b1a24] cursor-grab active:cursor-grabbing touch-none select-none"
        >
          {/* world layer (pan + zoom) */}
          <div className="absolute inset-0 origin-top-left" style={{ transform: `translate(${pan.x}px,${pan.y}px) scale(${zoom})` }}>
            {/* sea + the Malden satellite (public/malden-map.jpg, baked from the map atlas) */}
            <div className="absolute inset-0 bg-gradient-to-br from-[#0a2533] to-[#0a1a24]" />
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src="/malden-map.jpg" alt="" className="absolute inset-0 h-full w-full object-cover"
                 onError={(e) => { (e.currentTarget as HTMLImageElement).style.display = "none"; }} />
            {/* towns */}
            {TOWNS.map((t) => {
              const p = pct(t.x, t.y);
              return (
                <div key={t.n} className="absolute" style={{ left: `${p.left}%`, top: `${p.top}%` }}>
                  <div className="flex items-center gap-1 -translate-x-1/2 -translate-y-1/2" style={{ transform: `scale(${1 / zoom})`, transformOrigin: "center" }}>
                    <span className="h-1 w-1 rounded-full bg-gray-400/70" />
                    <span className="whitespace-nowrap text-[9px] font-semibold uppercase tracking-wide text-gray-400/80">{t.n}</span>
                  </div>
                </div>
              );
            })}
            {/* houses */}
            {houses.map((h) => {
              const p = pct(h.x, h.y);
              const t = tier(h.price);
              const on = h.id === sel;
              return (
                <button
                  key={h.id}
                  onClick={(e) => { e.stopPropagation(); if (!drag.current.moved) setSel(h.id); }}
                  className="absolute"
                  style={{ left: `${p.left}%`, top: `${p.top}%` }}
                  title={`${money(h.price)} — ${houseTypeName(h.classname)}`}
                >
                  <span
                    className={`block rounded-full ring-2 ${DOT[t]} ${on ? "h-3.5 w-3.5 ring-4 ring-white/70" : "h-2.5 w-2.5"} -translate-x-1/2 -translate-y-1/2 shadow`}
                    style={{ transform: `translate(-50%,-50%) scale(${1 / zoom})`, transformOrigin: "center" }}
                  />
                </button>
              );
            })}
          </div>

          {/* selected popup */}
          {selected && (
            <div className="absolute bottom-3 left-3 right-3 sm:right-auto sm:max-w-xs rounded-lg border border-th-700/40 bg-gray-900/95 backdrop-blur p-3 shadow-xl">
              <div className="flex items-start justify-between gap-2">
                <div className="flex items-center gap-2 text-th-300 font-bold text-sm"><Home className="w-4 h-4" /> {money(selected.price)}</div>
                <button onClick={() => setSel(null)} className="text-gray-500 hover:text-gray-300 text-xs">✕</button>
              </div>
              <p className="text-xs text-gray-300 mt-1">{houseTypeName(selected.classname)}</p>
              <p className="text-xs text-gray-500 mt-0.5">
                Seller: <Link href={`/player-detail?playerid=${selected.sellerUid}`} className="text-th-400 hover:text-th-300">{selected.sellerName || selected.sellerUid}</Link>
              </p>
              <p className="text-xs text-gray-600 mt-0.5 flex items-center gap-1"><MapPin className="w-3 h-3" /> Grid {gridRef(selected.x, selected.y)}</p>
            </div>
          )}

          {/* zoom controls */}
          <div className="absolute top-3 right-3 flex flex-col gap-1">
            <button onClick={() => ctrZoom(1.4)} className="grid h-8 w-8 place-items-center rounded-lg bg-gray-900/90 border border-gray-700 text-gray-300 hover:text-th-400"><Plus className="w-4 h-4" /></button>
            <button onClick={() => ctrZoom(1 / 1.4)} className="grid h-8 w-8 place-items-center rounded-lg bg-gray-900/90 border border-gray-700 text-gray-300 hover:text-th-400"><Minus className="w-4 h-4" /></button>
            <button onClick={reset} className="grid h-8 w-8 place-items-center rounded-lg bg-gray-900/90 border border-gray-700 text-gray-300 hover:text-th-400"><Maximize className="w-4 h-4" /></button>
          </div>
          <div className="absolute bottom-3 right-3 text-[10px] text-gray-500/80 bg-gray-900/70 rounded px-1.5 py-0.5 pointer-events-none sm:block hidden">drag to pan · scroll to zoom</div>
        </div>
      </div>

      {/* list */}
      <div className="rounded-xl border border-th-700/30 bg-gray-900 overflow-hidden flex flex-col max-h-[36rem]">
        <div className="px-4 py-3 border-b border-gray-800 text-sm font-bold text-th-400 uppercase tracking-widest">
          {houses.length} For Sale
        </div>
        <ul className="divide-y divide-gray-800 overflow-y-auto">
          {houses.map((h) => (
            <li key={h.id}>
              <button
                onClick={() => setSel(h.id)}
                className={`w-full text-left px-4 py-2.5 transition ${h.id === sel ? "bg-th-600/15" : "hover:bg-gray-800/50"}`}
              >
                <div className="flex items-center justify-between gap-2">
                  <span className="text-sm font-bold text-th-300 tabular-nums">{money(h.price)}</span>
                  <span className={`h-2 w-2 rounded-full ${DOT[tier(h.price)].split(" ")[0]}`} />
                </div>
                <p className="text-xs text-gray-300 truncate">{houseTypeName(h.classname)}</p>
                <p className="text-xs text-gray-600 truncate">{h.sellerName || h.sellerUid} · Grid {gridRef(h.x, h.y)}</p>
              </button>
            </li>
          ))}
          {houses.length === 0 && <li className="px-4 py-6 text-center text-gray-500 text-sm italic">No homes listed for sale.</li>}
        </ul>
      </div>
    </div>
  );
}
