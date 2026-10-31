"use client";

import { useEffect, useMemo, useState } from "react";
import { Loader2, Lock, Search, Shield, Users } from "lucide-react";
import { GangBonusChips, GangMemberRow, GangXpBar } from "./GangBits";
import { Badge } from "./ui/badge";
import { Button } from "./ui/button";
import DateValue from "./ui/date-value";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "./ui/dialog";
import { Input } from "./ui/input";
import Pagination from "./ui/pagination";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "./ui/table";
import type { GangProfile, GangRow } from "./types";

// Reference: the inline hook inside e6 fetching GET /api/pixel/gang?id=.
function useGangProfile(id: string | null): { profile: GangProfile | null; error: string | null } {
  const [t, a] = useState<GangProfile | null>(null),
    [r, n] = useState<string | null>(null);
  useEffect(() => {
    /* eslint-disable react-hooks/set-state-in-effect -- reference: the profile and error reset when the id changes */
    a(null);
    n(null);
    /* eslint-enable react-hooks/set-state-in-effect */
    if (!id) return;
    let t = true;
    (async () => {
      try {
        const s = await fetch(`/api/pixel/gang?id=${encodeURIComponent(id)}`, {
          credentials: "same-origin",
        });
        if (!t) return;
        if (!s.ok) {
          const e: { error?: string } | null = await s.json().catch(() => null);
          if (t) n(e?.error ?? "Could not load that gang.");
          return;
        }
        const r: { gang: GangProfile } = await s.json();
        if (t) a(r.gang);
      } catch {
        if (t) n("Could not load that gang.");
      }
    })();
    return () => {
      t = false;
    };
  }, [id]);
  return {
    profile: t,
    error: r,
  };
}

// Reference e6: the gang profile dialog.
function GangProfileDialog({
  row,
  canJoin,
  disabled,
  onJoin,
  onClose,
}: {
  row: GangRow | null;
  canJoin: boolean;
  disabled: boolean;
  onJoin: (row: GangRow) => void;
  onClose: () => void;
}) {
  const { profile: l, error: o } = useGangProfile(row?.id ?? null);
  if (!row) return null;
  const c = row.members >= row.cap;
  return (
    <Dialog
      open={true}
      onOpenChange={(e) => {
        if (!e) onClose();
      }}
    >
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle className="flex min-w-0 items-center gap-2">
            <span className="truncate">
              <span className="font-mono text-primary-emphasis">[{row.tag}]</span>
              {" "}
              {row.name}
            </span>
            {row.private && (
              <Badge variant="amber" className="shrink-0 gap-1 px-1 py-0 text-[9px]">
                <Lock className="h-2.5 w-2.5" />
                {" Private"}
              </Badge>
            )}
          </DialogTitle>
          <DialogDescription>
            {"Led by "}
            {row.leaderName}
            {" · "}
            {row.members}/{row.cap}
            {" members"}
            {l && (
              <>
                {" · founded "}
                <DateValue value={l.createdAt} />
              </>
            )}
          </DialogDescription>
        </DialogHeader>
        {o ? (
          <p className="py-4 text-center text-xs text-destructive">{o}</p>
        ) : l ? (
          <div className="space-y-3">
            <GangXpBar level={l.level} xp={l.xp} xpInto={l.xpInto} xpNeeded={l.xpNeeded} />
            <div className="flex flex-wrap gap-1.5">
              <GangBonusChips yieldBonus={l.yieldBonus} xpBonus={l.xpBonus} />
            </div>
            <div>
              <h4 className="mb-2 flex items-center gap-1.5 text-xs font-semibold text-foreground">
                <Users className="h-3.5 w-3.5" />
                {" Members ("}
                {l.members.length}/{l.cap})
              </h4>
              <ul className="max-h-64 space-y-1 overflow-y-auto overscroll-contain">
                {l.members.map((e) => (
                  <GangMemberRow key={e.steamId} m={e} />
                ))}
              </ul>
            </div>
          </div>
        ) : (
          <p className="flex items-center justify-center gap-2 py-6 text-xs text-muted-foreground">
            <Loader2 className="h-4 w-4 animate-spin text-primary-emphasis" />
            {" Loading roster"}
          </p>
        )}
        <DialogFooter>
          <Button variant="outline" onClick={onClose}>
            Close
          </Button>
          {canJoin && !l?.isMine && (
            <Button disabled={disabled || c} onClick={() => onJoin(row)} title={c ? "Full — slots unlock as the gang levels" : undefined}>
              {c ? "Full" : row.private ? "Enter code" : "Join"}
            </Button>
          )}
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

// Reference e4: the gang directory (search, table, pagination, invite-code dialog).
export function GangDirectory({
  gangs,
  myGangId,
  canJoin,
  disabled,
  onJoin,
}: {
  gangs: GangRow[];
  myGangId: string | null;
  canJoin: boolean;
  disabled: boolean;
  onJoin: (gangId: string, code: string) => void;
}) {
  const [l, o] = useState("");
  const [d, c] = useState(1);
  const [m, x] = useState<GangRow | null>(null);
  const [u, h] = useState<GangRow | null>(null);
  const [p, g] = useState("");
  const f = useMemo(() => {
    const t = l.trim().toLowerCase();
    return t ? gangs.filter((e) => e.name.toLowerCase().includes(t) || e.tag.toLowerCase().includes(t)) : gangs;
  }, [gangs, l]);
  const b = Math.ceil(f.length / 8);
  const y = Math.min(d, Math.max(1, b));
  const j = (y - 1) * 8;
  const v = f.slice(j, j + 8);
  const k = (e: GangRow) => {
    x(null);
    if (e.private) {
      h(e);
      g("");
    } else onJoin(e.id, "");
  };
  const w = () => {
    if (u) {
      onJoin(u.id, p);
      h(null);
      g("");
    }
  };
  return (
    <div data-slot="gang-directory" className="rounded-lg border border-border bg-card p-4">
      <div className="mb-2 flex flex-wrap items-center justify-between gap-2">
        <h4 className="flex items-center gap-1.5 text-xs font-semibold text-foreground">
          <Shield className="h-3.5 w-3.5" />
          {" Gangs on the island"}
        </h4>
        <div className="relative min-w-0 flex-1 sm:max-w-56">
          <Search className="pointer-events-none absolute left-2 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-muted-foreground" />
          <Input
            value={l}
            onChange={(e) => {
              o(e.target.value);
              c(1);
            }}
            placeholder="Search name or tag"
            className="pl-7 text-xs"
            aria-label="Search gangs by name or tag"
          />
        </div>
      </div>
      {0 === gangs.length ? (
        <p className="py-6 text-center text-xs text-muted-foreground">None yet — be the first.</p>
      ) : 0 === f.length ? (
        <p className="py-6 text-center text-xs text-muted-foreground">No gang matches “{l.trim()}”.</p>
      ) : (
        <>
          <div className="overflow-x-auto">
            <Table>
              <TableHeader>
                <TableRow className="hover:bg-transparent">
                  <TableHead>Gang</TableHead>
                  <TableHead className="text-right">Members</TableHead>
                  <TableHead className="w-px" />
                </TableRow>
              </TableHeader>
              <TableBody>
                {v.map((e) => {
                  const s = e.members >= e.cap,
                    i = e.id === myGangId;
                  return (
                    <TableRow key={e.id}>
                      <TableCell className="w-full max-w-0">
                        <button type="button" onClick={() => x(e)} className="block w-full min-w-0 text-left" aria-label={`View ${e.name}`}>
                          <span className="block truncate text-xs text-foreground hover:underline">
                            <span className="font-mono text-primary-emphasis">[{e.tag}]</span>
                            {" "}
                            {e.name}
                          </span>
                          <span className="flex min-w-0 items-center gap-1.5 text-[10px] text-muted-foreground">
                            <span className="truncate">
                              {"Led by "}
                              {e.leaderName}
                            </span>
                            {e.private && (
                              <Badge variant="amber" className="shrink-0 gap-1 px-1 py-0 text-[9px]">
                                <Lock className="h-2.5 w-2.5" />
                                {" Private"}
                              </Badge>
                            )}
                          </span>
                        </button>
                      </TableCell>
                      <TableCell className="text-right font-mono text-[10px] whitespace-nowrap text-muted-foreground">
                        L{e.level}
                        {" · "}
                        {e.members}/{e.cap}
                      </TableCell>
                      <TableCell className="pr-0 text-right">
                        {i ? (
                          <Badge variant="accent" className="whitespace-nowrap">
                            Yours
                          </Badge>
                        ) : canJoin ? (
                          <Button
                            size="sm"
                            variant={s ? "outline" : "default"}
                            disabled={disabled || s}
                            onClick={() => k(e)}
                            title={s ? "Full — slots unlock as the gang levels" : undefined}
                            className="shrink-0"
                          >
                            {s ? "Full" : e.private ? "Enter code" : "Join"}
                          </Button>
                        ) : (
                          <Button size="sm" variant="outline" onClick={() => x(e)} className="shrink-0">
                            View
                          </Button>
                        )}
                      </TableCell>
                    </TableRow>
                  );
                })}
              </TableBody>
            </Table>
          </div>
          {b > 1 && <Pagination page={y} totalPages={b} onPage={c} label={`${f.length} gang${1 === f.length ? "" : "s"}`} className="mt-3 mb-14 lg:mb-0" />}
        </>
      )}
      <GangProfileDialog row={m} canJoin={canJoin} disabled={disabled} onJoin={k} onClose={() => x(null)} />
      <Dialog
        open={null !== u}
        onOpenChange={(e) => {
          if (!e) {
            h(null);
            g("");
          }
        }}
      >
        <DialogContent className="sm:max-w-sm">
          <DialogHeader>
            <DialogTitle>
              Join [{u?.tag}
              {"] "}
              {u?.name}
            </DialogTitle>
            <DialogDescription>
              This gang is private. Ask a member for the current invite code — it changes every half hour, and again each time somebody uses it.
            </DialogDescription>
          </DialogHeader>
          <Input
            value={p}
            onChange={(e) => g(e.target.value.toUpperCase())}
            onKeyDown={(e) => {
              if ("Enter" === e.key && p.trim()) w();
            }}
            placeholder="ABC234"
            maxLength={8}
            autoFocus={true}
            aria-label="Invite code"
            className="text-center font-mono text-base tracking-[0.3em] uppercase"
          />
          <DialogFooter>
            <Button
              variant="outline"
              onClick={() => {
                h(null);
                g("");
              }}
            >
              Cancel
            </Button>
            <Button disabled={disabled || !p.trim()} onClick={w}>
              Join
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
