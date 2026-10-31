"use client";

import { useState } from "react";
import { FlaskConical, LayoutGrid, Pickaxe } from "lucide-react";
import { cn } from "@/lib/utils";
import { Empty, Panel } from "./primitives";
import { SiteCard, type SiteCardProps } from "./SiteCard";
import type { Site } from "./types";

type Filter = "all" | "work" | "process";

// Reference es: the Work tab (All / Work / Process filter + the site card grid).
export function WorkTab(props: Omit<SiteCardProps, "site"> & { sites: Site[]; busy: boolean }) {
  const { sites } = props,
    [r, n] = useState<Filter>("all"),
    i = sites.filter((e) => "all" === r || ("work" === r ? "gather" === e.mode : "process" === e.mode));
  return (
    <div className="space-y-3">
      <div className="rounded-lg border border-border bg-card p-1.5">
        <div className="grid grid-cols-3 gap-1" role="tablist" aria-label="Choose an activity">
          {(
            [
              {
                id: "all",
                label: "All",
                Icon: LayoutGrid,
              },
              {
                id: "work",
                label: "Work",
                Icon: Pickaxe,
              },
              {
                id: "process",
                label: "Process",
                Icon: FlaskConical,
              },
            ] as const
          ).map(({ id, label, Icon }) => (
            <button
              key={id}
              type="button"
              role="tab"
              aria-selected={r === id}
              onClick={() => n(id)}
              className={cn(
                "inline-flex min-h-11 items-center justify-center gap-1.5 rounded-md px-3 py-2 text-xs font-bold transition",
                r === id ? "bg-primary text-primary-foreground shadow-sm" : "text-muted-foreground hover:bg-surface hover:text-foreground",
              )}
            >
              <Icon className="h-3.5 w-3.5" />
              {label}
            </button>
          ))}
        </div>
      </div>
      <Panel
        title={"all" === r ? "Every activity" : "work" === r ? "Work sites" : "Processing sites"}
        icon={"process" === r ? <FlaskConical className="h-3.5 w-3.5 text-muted-foreground" /> : <Pickaxe className="h-3.5 w-3.5 text-muted-foreground" />}
        right={<span className="text-[10px] text-muted-foreground">Work collects · processing refines</span>}
      >
        {0 === i.length ? (
          <Empty>{"process" === r ? "No processors in this city. Try another city." : "Nothing here. Try another city."}</Empty>
        ) : (
          <div className="grid gap-2 sm:grid-cols-2 xl:grid-cols-3">
            {i.map((a) => (
              <SiteCard key={a.id} site={a} {...props} />
            ))}
          </div>
        )}
      </Panel>
    </div>
  );
}
