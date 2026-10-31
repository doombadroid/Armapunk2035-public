"use client";

import { useState } from "react";
import { MoreHorizontal } from "lucide-react";
import { cn } from "@/lib/utils";
import { Sheet, SheetContent, SheetHeader, SheetTitle } from "./ui/sheet";
import type { TabDef, TabId } from "./types";

// Reference tz: the phone bottom tab bar with its "More" sheet.
export function MobileTabBar({ tabs, activeTab, onSelect }: { tabs: TabDef[]; activeTab: TabId; onSelect: (id: TabId) => void }) {
  const [n, i] = useState(false),
    l = tabs.filter((e) => e.show),
    o = l.slice(0, 4),
    d = l.slice(4),
    c = d.some((e) => e.id === activeTab);
  return (
    <>
      <nav className={cn("fixed inset-x-0 bottom-0 z-40 flex items-stretch border-t border-border bg-card lg:hidden", "pb-[env(safe-area-inset-bottom)]")}>
        {o.map((e) => (
          <button
            key={e.id}
            type="button"
            onClick={() => onSelect(e.id)}
            className={cn(
              "flex flex-1 flex-col items-center justify-center gap-0.5 py-2 text-[10px] font-semibold transition",
              activeTab === e.id ? "text-primary-emphasis" : "text-muted-foreground",
            )}
          >
            {e.icon}
            <span className="max-w-full truncate px-1">{e.label}</span>
          </button>
        ))}
        {d.length > 0 && (
          <button
            type="button"
            onClick={() => i(true)}
            className={cn("flex flex-1 flex-col items-center justify-center gap-0.5 py-2 text-[10px] font-semibold transition", c ? "text-primary-emphasis" : "text-muted-foreground")}
          >
            <MoreHorizontal className="h-3.5 w-3.5" />
            More
          </button>
        )}
      </nav>
      <Sheet open={n} onOpenChange={i}>
        <SheetContent side="bottom" className="max-h-[70vh] overflow-y-auto">
          <SheetHeader>
            <SheetTitle>More</SheetTitle>
          </SheetHeader>
          <div className="grid grid-cols-3 gap-2 p-4 pt-0">
            {d.map((e) => (
              <button
                key={e.id}
                type="button"
                onClick={() => {
                  onSelect(e.id);
                  i(false);
                }}
                className={cn(
                  "flex flex-col items-center gap-1.5 rounded-lg border px-2 py-3 text-[11px] font-semibold transition",
                  activeTab === e.id ? "border-primary/50 bg-primary/10 text-primary-emphasis" : "border-border bg-surface text-foreground hover:bg-muted",
                )}
              >
                {e.icon}
                <span className="max-w-full truncate">{e.label}</span>
              </button>
            ))}
          </div>
        </SheetContent>
      </Sheet>
    </>
  );
}
