"use client";

import { useState } from "react";
import Topbar from "./Topbar";
import Sidebar from "./Sidebar";
import type { Session } from "@/lib/session";

export default function NavShell({
  session, staff, children,
}: {
  session: Session | null;
  staff?: { whitelist: boolean; logs: boolean; bans: boolean; vpn: boolean; server: boolean; pixel?: boolean };
  children: React.ReactNode;
}) {
  const [mobileOpen, setMobileOpen] = useState(false);
  const [collapsed, setCollapsed] = useState(false);

  return (
    <>
      <Topbar session={session} onMenu={() => setMobileOpen(true)} />
      <Sidebar
        staff={staff}
        collapsed={collapsed}
        onToggleCollapse={() => setCollapsed((c) => !c)}
        mobileOpen={mobileOpen}
        onClose={() => setMobileOpen(false)}
      />
      <main
        className={`pt-14 transition-[margin] duration-300 ease-out ${
          collapsed ? "md:ml-16" : "md:ml-56"
        }`}
      >
        <div className="max-w-6xl mx-auto px-4 py-6 sm:py-8">{children}</div>
      </main>
    </>
  );
}
