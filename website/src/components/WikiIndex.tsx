"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import {
  Search, ChevronRight, Plus, Library,
  Scale, Shield, Stethoscope, Rocket, Landmark, Users, User, BookOpen,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";

const ICONS: Record<string, LucideIcon> = {
  Scale, Shield, Stethoscope, Rocket, Landmark, Users, User, BookOpen, Library,
};

export type WikiCard = { slug: string; title: string; description: string; updated: string };
export type WikiGroup = { category: string; subtitle: string; icon: string; anchor: string; pages: WikiCard[] };

export default function WikiIndex({ groups, isEditor }: { groups: WikiGroup[]; isEditor: boolean }) {
  const [q, setQ] = useState("");

  const filtered = useMemo(() => {
    const s = q.trim().toLowerCase();
    if (!s) return groups;
    return groups
      .map((g) => ({ ...g, pages: g.pages.filter((p) =>
        p.title.toLowerCase().includes(s) || p.description.toLowerCase().includes(s)) }))
      .filter((g) => g.pages.length > 0);
  }, [q, groups]);

  return (
    <div>
      {/* header */}
      <div className="mb-6 flex items-start justify-between gap-3 flex-wrap">
        <div>
          <div className="flex items-center gap-3 mb-1.5">
            <Library className="w-7 h-7 text-th-400" />
            <h1 className="text-3xl font-black text-gray-100">Wiki</h1>
          </div>
          <p className="text-gray-400 text-sm">Guides and information for players on Armapunk 2035.</p>
        </div>
        {isEditor && (
          <Link href="/wiki/new" className="inline-flex items-center gap-2 px-4 py-2 rounded-lg bg-th-600 hover:bg-th-500 text-white font-bold text-sm transition shrink-0">
            <Plus className="w-4 h-4" /> New page
          </Link>
        )}
      </div>

      {/* search + jump */}
      <div className="flex flex-col sm:flex-row gap-3 mb-8">
        <div className="relative flex-1">
          <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500 pointer-events-none" />
          <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Search the wiki..."
            className="w-full pl-10 pr-4 py-3 bg-gray-900 border border-gray-700 rounded-xl text-white placeholder-gray-500 focus:outline-none focus:border-th-600 transition" />
        </div>
        <select onChange={(e) => { const el = document.getElementById(e.target.value); if (el) el.scrollIntoView({ behavior: "smooth" }); e.target.selectedIndex = 0; }}
          className="sm:w-56 px-4 py-3 bg-gray-900 border border-gray-700 rounded-xl text-gray-400 text-sm focus:outline-none focus:border-th-600 transition">
          <option value="">Jump to section...</option>
          {groups.map((g) => <option key={g.anchor} value={g.anchor}>{g.category}</option>)}
        </select>
      </div>

      {filtered.length === 0 ? (
        <div className="rounded-xl border border-gray-800 bg-gray-900 p-10 text-center text-gray-500">
          {q ? "No pages match your search." : "No wiki pages yet."}
        </div>
      ) : (
        <div className="space-y-10">
          {filtered.map((g) => {
            const Icon = ICONS[g.icon] ?? BookOpen;
            return (
              <div key={g.anchor} id={g.anchor}>
                <div className="flex items-center gap-3 mb-4 scroll-mt-20">
                  <div className="p-2 rounded-lg bg-th-600/15 border border-th-700/40">
                    <Icon className="w-5 h-5 text-th-400" />
                  </div>
                  <div>
                    <h2 className="text-lg font-bold text-gray-100">{g.category}</h2>
                    {g.subtitle && <p className="text-xs text-gray-500">{g.subtitle}</p>}
                  </div>
                </div>
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
                  {g.pages.map((p) => (
                    <Link key={p.slug} href={`/wiki/${p.slug}`}
                      className="flex items-start gap-3 p-4 bg-gray-900 border border-gray-800 rounded-xl hover:border-th-700/40 hover:bg-gray-800/60 transition group">
                      <ChevronRight className="w-4 h-4 text-th-600 mt-0.5 flex-shrink-0 group-hover:text-th-400 transition" />
                      <div className="min-w-0">
                        <p className="font-semibold text-gray-200 group-hover:text-th-300 transition text-sm leading-snug">{p.title}</p>
                        {p.description && <p className="text-xs text-gray-500 mt-1 line-clamp-2">{p.description}</p>}
                        <p className="text-[10px] text-gray-700 mt-2">Updated {p.updated}</p>
                      </div>
                    </Link>
                  ))}
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
