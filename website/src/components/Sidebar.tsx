"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  Home, Library, BarChart3, Users, Map, Ticket, Vote, BookOpen,
  Shield, Stethoscope, Crown, Target, PanelLeftClose, PanelLeftOpen, ShieldCheck, ScrollText, Ban, Wifi, Tag, X, ServerCog, Gamepad2,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";

interface NavItem { href: string; label: string; icon: LucideIcon; children?: { href: string; label: string }[] }

const NAV: NavItem[] = [
  { href: "/", label: "Home", icon: Home },
  { href: "/wiki", label: "Wiki", icon: Library },
  { href: "/leaderboard", label: "Leaderboard", icon: BarChart3 },
  { href: "/players", label: "Players", icon: Users },
  { href: "/gameserver/gangs", label: "Gang Lookup", icon: Users },
  { href: "/gang-territories", label: "Gang Territories", icon: Map },
  { href: "/homes-for-sale", label: "Homes for Sale", icon: Tag },
  { href: "/governor", label: "Governor", icon: Crown },
  { href: "/bounties", label: "Bounty Board", icon: Target },
  { href: "/support-tickets", label: "Support Tickets", icon: Ticket },
  { href: "/voting", label: "Feature Voting", icon: Vote },
  { href: "/changelogs", label: "Changelogs", icon: BookOpen },
  { href: "/maxsec", label: "MaxSec", icon: Shield, children: [{ href: "/maxsec/apply", label: "Apply to MaxSec" }] },
  { href: "/trauma-team", label: "Trauma Team", icon: Stethoscope },
];

const SITE = (process.env.NEXT_PUBLIC_SITE_NAME || "Armapunk 2035").toUpperCase();

export default function Sidebar({
  staff, collapsed, onToggleCollapse, mobileOpen, onClose,
}: {
  staff?: { whitelist: boolean; logs: boolean; bans: boolean; vpn: boolean; server: boolean; pixel?: boolean };
  collapsed: boolean;
  onToggleCollapse: () => void;
  mobileOpen: boolean;
  onClose: () => void;
}) {
  const pathname = usePathname();

  const nav: NavItem[] = [
    ...NAV,
    ...(staff?.pixel ? [{ href: "/pixel", label: "Armapunk Pixel", icon: Gamepad2 }] : []),
    ...(staff?.server ? [{ href: "/server", label: "Server", icon: ServerCog }] : []),
    ...(staff?.whitelist ? [{ href: "/whitelist", label: "Whitelist", icon: ShieldCheck }] : []),
    ...(staff?.bans ? [{ href: "/bans", label: "Active Bans", icon: Ban }] : []),
    ...(staff?.vpn ? [{ href: "/vpn-whitelist", label: "VPN Exemptions", icon: Wifi }] : []),
    ...(staff?.logs ? [{ href: "/logs", label: "Player Logs", icon: ScrollText }] : []),
  ];

  // collapsed only applies on desktop; the mobile drawer always shows full labels.
  const showLabels = !collapsed;

  return (
    <>
      {/* mobile backdrop */}
      <div
        onClick={onClose}
        aria-hidden
        className={`fixed inset-0 top-14 z-40 bg-black/60 backdrop-blur-sm md:hidden transition-opacity duration-200 ${
          mobileOpen ? "opacity-100" : "pointer-events-none opacity-0"
        }`}
      />

      <aside
        className={[
          "fixed top-14 left-0 z-50 flex flex-col bg-gray-900 border-r border-th-700/30",
          "h-[calc(100dvh-3.5rem)] transition-transform duration-300 ease-out",
          mobileOpen ? "translate-x-0" : "-translate-x-full",
          "md:translate-x-0",
          collapsed ? "w-16" : "w-64 md:w-56",
        ].join(" ")}
      >
        {/* header: brand + control */}
        <div className={`flex items-center h-14 px-3 border-b border-th-700/30 shrink-0 ${collapsed ? "justify-center" : "justify-between"}`}>
          {showLabels && (
            <Link href="/" onClick={onClose} className="brand-font text-lg text-white truncate px-1">
              {SITE}
            </Link>
          )}
          {/* desktop collapse */}
          <button
            title={collapsed ? "Expand" : "Collapse"}
            onClick={onToggleCollapse}
            className="hidden md:flex p-2 hover:bg-gray-800 rounded-lg transition text-th-400"
          >
            {collapsed ? <PanelLeftOpen className="w-4 h-4" /> : <PanelLeftClose className="w-4 h-4" />}
          </button>
          {/* mobile close */}
          <button
            title="Close menu"
            onClick={onClose}
            className="md:hidden p-2 hover:bg-gray-800 rounded-lg transition text-gray-400"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        <nav className="flex-1 overflow-y-auto py-2">
          <ul className="space-y-0.5 px-2">
            {nav.map(({ href, label, icon: Icon, children }) => {
              const active = href === "/" ? pathname === "/" : pathname.startsWith(href);
              return (
                <li key={href}>
                  <Link
                    href={href}
                    onClick={onClose}
                    title={collapsed ? label : undefined}
                    aria-current={active ? "page" : undefined}
                    className={[
                      "flex items-center gap-3 rounded-lg text-sm transition-colors min-h-[2.5rem]",
                      collapsed ? "justify-center px-0 py-2.5" : "px-3 py-2.5",
                      active
                        ? "bg-th-600/20 text-th-300 font-semibold"
                        : "text-gray-300 hover:bg-gray-800 hover:text-gray-100",
                    ].join(" ")}
                  >
                    <Icon className="w-5 h-5 shrink-0" />
                    {showLabels && <span className="font-medium whitespace-nowrap truncate">{label}</span>}
                  </Link>
                  {children && showLabels && (
                    <ul className="mt-0.5 mb-0.5 ml-5 pl-3 border-l border-gray-800 space-y-0.5">
                      {children.map((ch) => {
                        const chActive = pathname === ch.href || pathname.startsWith(ch.href + "/");
                        return (
                          <li key={ch.href}>
                            <Link
                              href={ch.href}
                              onClick={onClose}
                              aria-current={chActive ? "page" : undefined}
                              className={[
                                "flex items-center rounded-lg text-xs px-3 py-2 transition-colors min-h-[2rem]",
                                chActive
                                  ? "bg-th-600/20 text-th-300 font-semibold"
                                  : "text-gray-400 hover:bg-gray-800 hover:text-gray-100",
                              ].join(" ")}
                            >
                              <span className="whitespace-nowrap truncate">{ch.label}</span>
                            </Link>
                          </li>
                        );
                      })}
                    </ul>
                  )}
                </li>
              );
            })}
          </ul>
        </nav>
      </aside>
    </>
  );
}
