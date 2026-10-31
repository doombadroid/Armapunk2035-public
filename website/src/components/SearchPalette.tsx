"use client";

import { useEffect, useRef, useState, useCallback } from "react";
import { useRouter } from "next/navigation";
import { Search, Loader2 } from "lucide-react";

interface Result {
  type: "player" | "gang";
  id: string;
  name: string;
  sub: string;
}

export default function SearchPalette({
  open, onClose,
}: { open: boolean; onClose: () => void }) {
  const [term, setTerm] = useState("");
  const [results, setResults] = useState<Result[]>([]);
  const [loading, setLoading] = useState(false);
  const [active, setActive] = useState(0);
  const inputRef = useRef<HTMLInputElement>(null);
  const router = useRouter();

  useEffect(() => {
    if (open) {
      setTerm("");
      setResults([]);
      setActive(0);
      setTimeout(() => inputRef.current?.focus(), 10);
    }
  }, [open]);

  useEffect(() => {
    if (!term.trim()) {
      setResults([]);
      return;
    }
    const ctrl = new AbortController();
    setLoading(true);
    const t = setTimeout(async () => {
      try {
        const res = await fetch(`/api/search?q=${encodeURIComponent(term)}`, {
          signal: ctrl.signal,
        });
        const data = await res.json();
        setResults(data.results ?? []);
        setActive(0);
      } catch {
        /* aborted */
      } finally {
        setLoading(false);
      }
    }, 180);
    return () => {
      ctrl.abort();
      clearTimeout(t);
    };
  }, [term]);

  const go = useCallback(
    (r: Result) => {
      onClose();
      router.push(
        r.type === "player"
          ? `/player-detail?playerid=${r.id}`
          : `/gameserver/gang-detail?id=${r.id}`
      );
    },
    [onClose, router]
  );

  if (!open) return null;

  return (
    <div
      className="fixed inset-0 z-[100] bg-black/60 backdrop-blur-sm flex items-start justify-center pt-[12vh] px-4"
      onClick={onClose}
    >
      <div
        className="w-full max-w-xl bg-gray-900 border border-th-700/40 rounded-xl shadow-2xl overflow-hidden"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center gap-3 px-4 border-b border-gray-800">
          <Search className="w-4 h-4 text-gray-500" />
          <input
            ref={inputRef}
            value={term}
            onChange={(e) => setTerm(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Escape") onClose();
              if (e.key === "ArrowDown") { e.preventDefault(); setActive((a) => Math.min(a + 1, results.length - 1)); }
              if (e.key === "ArrowUp") { e.preventDefault(); setActive((a) => Math.max(a - 1, 0)); }
              if (e.key === "Enter" && results[active]) go(results[active]);
            }}
            placeholder="Search players & gangs…"
            className="flex-1 bg-transparent py-3.5 text-sm text-gray-100 outline-none placeholder:text-gray-500"
          />
          {loading && <Loader2 className="w-4 h-4 text-gray-500 animate-spin" />}
        </div>
        <div className="max-h-80 overflow-y-auto">
          {results.length === 0 && term.trim() && !loading && (
            <div className="px-4 py-6 text-center text-gray-500 text-sm">No results.</div>
          )}
          {results.map((r, i) => (
            <button
              key={`${r.type}-${r.id}`}
              onClick={() => go(r)}
              onMouseEnter={() => setActive(i)}
              className={`w-full flex items-center justify-between px-4 py-2.5 text-left transition ${
                i === active ? "bg-th-600/20" : "hover:bg-gray-800/50"
              }`}
            >
              <span className="text-sm text-gray-100 font-medium truncate">{r.name}</span>
              <span className="text-xs text-gray-500 shrink-0 ml-3">{r.sub}</span>
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}
