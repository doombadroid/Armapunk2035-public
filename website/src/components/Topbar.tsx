"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { Search, ChevronDown, LogOut, User, Palette, Coffee, Menu } from "lucide-react";
import SearchPalette from "./SearchPalette";
import type { Session } from "@/lib/session";

const THEMES = ["amber", "blue", "emerald", "rose", "violet"];

export default function Topbar({ session, onMenu }: { session: Session | null; onMenu?: () => void }) {
  const [paletteOpen, setPaletteOpen] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);
  const [themeOpen, setThemeOpen] = useState(false);
  const [theme, setTheme] = useState("amber");

  useEffect(() => {
    const saved = localStorage.getItem("lb-theme") || "amber";
    setTheme(saved);
    document.documentElement.setAttribute("data-theme", saved);
  }, []);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "k") {
        e.preventDefault();
        setPaletteOpen(true);
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);

  const pickTheme = (t: string) => {
    setTheme(t);
    localStorage.setItem("lb-theme", t);
    document.documentElement.setAttribute("data-theme", t);
    setThemeOpen(false);
  };

  const discord = process.env.NEXT_PUBLIC_DISCORD_URL || "https://discord.gg/";
  const donate = process.env.NEXT_PUBLIC_DONATE_URL || "https://ko-fi.com/doomba";

  return (
    <>
      <div className="fixed top-0 left-0 right-0 z-[60] h-14 bg-gray-900 border-b border-gray-800 flex items-center px-3 sm:px-4 gap-2 sm:gap-3">
        {/* mobile menu */}
        <button
          onClick={onMenu}
          aria-label="Open menu"
          className="md:hidden p-2 -ml-1 rounded-lg text-gray-300 hover:bg-gray-800 transition shrink-0"
        >
          <Menu className="w-5 h-5" />
        </button>

        <button
          onClick={() => setPaletteOpen(true)}
          aria-label="Search"
          className="flex items-center gap-2 px-3 py-2 min-w-0 flex-1 md:flex-none md:w-72 bg-gray-800 hover:bg-gray-700 border border-gray-700 hover:border-gray-500 rounded-lg transition text-sm group"
        >
          <Search className="w-4 h-4 shrink-0 text-gray-500 group-hover:text-gray-300 transition" />
          <span className="flex-1 text-left text-gray-500 group-hover:text-gray-400 transition truncate">
            Search…
          </span>
          <kbd className="hidden sm:inline-flex text-xs font-mono bg-gray-700 border border-gray-600 px-1.5 py-0.5 rounded text-gray-400 leading-none shrink-0">
            Ctrl K
          </kbd>
        </button>

        <div className="ml-auto flex items-center gap-1.5 sm:gap-3 shrink-0">
          {/* theme switcher — click to open (was hover; it closed before you could pick) */}
          <div className="relative">
            <button
              onClick={() => setThemeOpen((o) => !o)}
              title="Theme"
              className={`p-2 rounded-lg transition ${themeOpen ? "bg-gray-800 text-th-400" : "text-gray-400 hover:bg-gray-800 hover:text-th-400"}`}
            >
              <Palette className="w-4 h-4" />
            </button>
            {themeOpen && (
              <>
                <div className="fixed inset-0 z-10" onClick={() => setThemeOpen(false)} />
                <div className="absolute right-0 top-full mt-1 z-20 flex flex-col gap-1 p-2 bg-gray-900 border border-gray-700 rounded-lg shadow-xl">
                  {THEMES.map((t) => (
                    <button
                      key={t}
                      onClick={() => pickTheme(t)}
                      className="flex items-center gap-2 px-2 py-1 rounded hover:bg-gray-800 transition text-left"
                    >
                      <span data-theme={t} className={`w-4 h-4 rounded-full bg-th-500 border-2 ${theme === t ? "border-white" : "border-gray-600"}`} />
                      <span className={`text-xs capitalize ${theme === t ? "text-th-300 font-semibold" : "text-gray-400"}`}>{t}</span>
                    </button>
                  ))}
                </div>
              </>
            )}
          </div>

          <a
            href={discord}
            target="_blank"
            rel="noopener noreferrer"
            className="hidden sm:flex items-center gap-2 px-3 py-1.5 bg-indigo-600/20 hover:bg-indigo-600/30 border border-indigo-500/30 rounded-lg transition text-indigo-300 text-sm font-semibold"
          >
            <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 24 24" aria-hidden="true">
              <path d="M20.317 4.492c-1.53-.69-3.17-1.2-4.885-1.49a.075.075 0 0 0-.079.036c-.21.369-.444.85-.608 1.23a18.566 18.566 0 0 0-5.487 0 12.36 12.36 0 0 0-.617-1.23A.077.077 0 0 0 8.562 3c-1.714.29-3.354.8-4.885 1.491a.07.07 0 0 0-.032.027C.533 9.093-.32 13.555.099 17.961a.08.08 0 0 0 .031.055 20.03 20.03 0 0 0 5.993 2.98.078.078 0 0 0 .084-.026 14.09 14.09 0 0 0 1.226-1.963.076.076 0 0 0-.041-.106 13.107 13.107 0 0 1-1.872-.892.077.077 0 0 1-.008-.128 10.2 10.2 0 0 0 .372-.292.074.074 0 0 1 .078-.01c3.927 1.764 8.18 1.764 12.061 0a.074.074 0 0 1 .078.01c.12.098.246.198.373.292a.077.077 0 0 1-.006.127 12.299 12.299 0 0 1-1.873.892.077.077 0 0 0-.041.106c.36.698.772 1.363 1.225 1.964a.076.076 0 0 0 .084.028 19.839 19.839 0 0 0 6.002-2.981.076.076 0 0 0 .032-.054c.5-5.094-.838-9.52-3.549-13.442a.06.06 0 0 0-.031-.03zM8.02 15.278c-1.182 0-2.157-1.069-2.157-2.38 0-1.312.956-2.38 2.157-2.38 1.21 0 2.176 1.077 2.157 2.38 0 1.311-.956 2.38-2.157 2.38zm7.975 0c-1.183 0-2.157-1.069-2.157-2.38 0-1.312.955-2.38 2.157-2.38 1.21 0 2.176 1.077 2.157 2.38 0 1.311-.946 2.38-2.157 2.38z" />
            </svg>
            Discord
          </a>

          <a
            href={donate}
            target="_blank"
            rel="noopener noreferrer"
            className="hidden sm:flex items-center gap-2 px-3 py-1.5 bg-rose-600/20 hover:bg-rose-600/30 border border-rose-500/30 rounded-lg transition text-rose-300 text-sm font-semibold"
          >
            <Coffee className="w-4 h-4" />
            Donate
          </a>

          {session ? (
            <div className="relative">
              <button
                onClick={() => setMenuOpen((o) => !o)}
                className="flex items-center gap-2 px-3 py-1.5 rounded-lg hover:bg-gray-800 transition"
              >
                <div className="w-8 h-8 rounded-full border border-th-600/50 bg-th-600 flex items-center justify-center overflow-hidden">
                  {session.avatar ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img src={session.avatar} alt={session.name} className="w-full h-full object-cover" />
                  ) : (
                    <span className="text-xs font-bold text-white">
                      {session.name.slice(0, 2).toUpperCase()}
                    </span>
                  )}
                </div>
                <span className="hidden sm:block text-sm font-semibold text-th-400 max-w-[120px] truncate">
                  {session.name}
                </span>
                <ChevronDown className="hidden sm:block w-3.5 h-3.5 text-gray-400" />
              </button>
              {menuOpen && (
                <div className="absolute right-0 top-full mt-1 w-44 bg-gray-900 border border-gray-700 rounded-lg shadow-xl py-1 z-10">
                  <Link
                    href={`/player-detail?playerid=${session.uid}`}
                    onClick={() => setMenuOpen(false)}
                    className="flex items-center gap-2 px-3 py-2 text-sm text-gray-300 hover:bg-gray-800"
                  >
                    <User className="w-4 h-4" /> My Profile
                  </Link>
                  <a
                    href="/api/auth/logout"
                    className="flex items-center gap-2 px-3 py-2 text-sm text-gray-300 hover:bg-gray-800"
                  >
                    <LogOut className="w-4 h-4" /> Logout
                  </a>
                </div>
              )}
            </div>
          ) : (
            <a
              href="/api/auth/login"
              className="flex items-center gap-2 px-3 py-1.5 bg-th-600/20 hover:bg-th-600/30 border border-th-500/30 rounded-lg transition text-th-300 text-sm font-semibold whitespace-nowrap"
            >
              Sign in<span className="hidden sm:inline">&nbsp;with Steam</span>
            </a>
          )}
        </div>
      </div>

      <SearchPalette open={paletteOpen} onClose={() => setPaletteOpen(false)} />
    </>
  );
}
