"use client";

import { useState } from "react";
import { Copy, Globe, KeyRound, Lock, LogOut, Sparkles, Users } from "lucide-react";
import { cn } from "@/lib/utils";
import { fmtMoney } from "./format";
import { GangBonusChips, GangMemberRow, GangXpBar } from "./GangBits";
import { GangDirectory } from "./GangDirectory";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "./ui/alert-dialog";
import { Button } from "./ui/button";
import { Input } from "./ui/input";
import { Switch } from "./ui/switch";
import { useToast } from "./ui/use-toast";
import type { GangRow, Me, Statics } from "./types";

// Reference e3: the privacy / invite-code card.
function GangPrivacyCard({
  isPrivate,
  isLeader,
  inviteCode,
  inviteExpiresAt,
  windowMs,
  disabled,
  onPrivacy,
}: {
  isPrivate: boolean;
  isLeader: boolean;
  inviteCode: string | null;
  inviteExpiresAt: number;
  windowMs: number;
  disabled: boolean;
  onPrivacy: (isPrivate: boolean) => void;
}) {
  const o = useToast(),
    // eslint-disable-next-line react-hooks/purity -- reference: the invite-code countdown reads Date.now() at render
    d = Math.max(0, Math.ceil((inviteExpiresAt - Date.now()) / 6e4));
  return (
    <div className="rounded-lg border border-border bg-card p-4">
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <h4 className="flex items-center gap-1.5 text-xs font-semibold text-foreground">
            {isPrivate ? <Lock className="h-3.5 w-3.5" /> : <Globe className="h-3.5 w-3.5" />}
            {isPrivate ? "Private" : "Public"}
          </h4>
          <p className="mt-0.5 text-[10px] leading-relaxed text-muted-foreground">
            {isPrivate ? "Listed in the directory, but joining needs the invite code below." : "Anyone can join straight from the directory."}
            {!isLeader && " Only the leader can change this."}
          </p>
        </div>
        {isLeader && <Switch checked={isPrivate} disabled={disabled} onCheckedChange={(e) => onPrivacy(true === e)} aria-label="Private gang" className="mt-0.5 shrink-0" />}
      </div>
      {isPrivate && inviteCode && (
        <div className="mt-3 rounded-md bg-surface p-2.5">
          <div className="flex items-center gap-2">
            <KeyRound className="h-3.5 w-3.5 shrink-0 text-muted-foreground" />
            <code className="min-w-0 flex-1 truncate font-mono text-base font-bold tracking-[0.3em] text-primary-emphasis">{inviteCode}</code>
            <Button
              size="sm"
              variant="outline"
              onClick={() => {
                if (inviteCode)
                  navigator.clipboard
                    .writeText(inviteCode)
                    .then(() => o.success("Invite code copied."))
                    .catch(() => o.error("Could not copy the code."));
              }}
              className="shrink-0"
            >
              <Copy />
              {" Copy"}
            </Button>
          </div>
          <p className="mt-1.5 text-[10px] leading-relaxed text-muted-foreground">
            {"New code in "}
            {0 === d ? "under a minute" : `~${d}m`}, and again as soon as somebody joins with this one. Codes roll every{" "}
            {Math.round(windowMs / 6e4)}
            {" minutes whether they are used or not."}
          </p>
        </div>
      )}
    </div>
  );
}

// Reference e0: the Gang tab (my gang, or found / join).
export function GangTab({
  me,
  gangs,
  statics,
  disabled,
  onCreate,
  onJoin,
  onLeave,
  onKick,
  onPrivacy,
}: {
  me: Me;
  gangs: GangRow[];
  statics: Statics;
  disabled: boolean;
  onCreate: (name: string, tag: string) => void;
  onJoin: (gangId: string, code: string) => void;
  onLeave: () => void;
  onKick: (targetId: string) => void;
  onPrivacy: (isPrivate: boolean) => void;
}) {
  const [m, x] = useState(""),
    [u, h] = useState(""),
    [p, g] = useState(false),
    [f, y] = useState<{ steamId: string; name: string } | null>(null),
    v = me.gang,
    k = <GangDirectory gangs={gangs} myGangId={v?.id ?? null} canJoin={!v} disabled={disabled} onJoin={onJoin} />;
  if (v) {
    const e = v.members.find((e) => e.leader);
    return (
      <div className="space-y-3">
        <div className="rounded-lg border border-border bg-card p-4">
          <div className="flex items-center justify-between gap-2">
            <div className="min-w-0">
              <h3 className="truncate text-sm font-bold text-foreground">
                <span className="font-mono text-primary-emphasis">[{v.tag}]</span>
                {" "}
                {v.name}
              </h3>
              <p className="text-[10px] text-muted-foreground">
                {"Level "}
                {v.level}
                {" / "}
                {statics.gang.maxLevel}
                {" · "}
                {v.members.length}/{v.cap}
                {" members"}
                {e && (
                  <>
                    {" · led by "}
                    {e.name}
                  </>
                )}
              </p>
            </div>
            <button
              type="button"
              disabled={disabled}
              onClick={() => g(true)}
              className={cn(
                "inline-flex shrink-0 items-center gap-1.5 rounded-md border border-destructive/40 px-2.5 py-1.5",
                "text-[10px] font-bold uppercase text-destructive transition hover:bg-destructive/10",
                "disabled:cursor-not-allowed disabled:opacity-40",
              )}
            >
              <LogOut className="h-3 w-3" />
              {" Leave"}
            </button>
          </div>
          <GangXpBar level={v.level} xp={v.xp} xpInto={v.xpInto} xpNeeded={v.xpNeeded} className="mt-3" />
          <div className="mt-3 flex flex-wrap gap-1.5">
            <GangBonusChips yieldBonus={v.yieldBonus} xpBonus={v.xpBonus} />
            <span className="rounded bg-muted px-1.5 py-0.5 font-mono text-[10px] text-muted-foreground">next slot at even levels</span>
          </div>
        </div>
        <GangPrivacyCard
          isPrivate={v.isPrivate}
          isLeader={v.isLeader}
          inviteCode={v.inviteCode}
          inviteExpiresAt={v.inviteExpiresAt}
          windowMs={statics.gang.inviteWindowMs}
          disabled={disabled}
          onPrivacy={onPrivacy}
        />
        <div className="rounded-lg border border-border bg-card p-4">
          <h4 className="mb-2 flex items-center gap-1.5 text-xs font-semibold text-foreground">
            <Users className="h-3.5 w-3.5" />
            {" Members"}
          </h4>
          <ul className="space-y-1">
            {v.members.map((e) => (
              <GangMemberRow
                key={e.steamId}
                m={e}
                disabled={disabled}
                onKick={
                  v.isLeader && !e.leader
                    ? () =>
                        y({
                          steamId: e.steamId,
                          name: e.name,
                        })
                    : undefined
                }
              />
            ))}
          </ul>
        </div>
        {k}
        <AlertDialog open={p} onOpenChange={g}>
          <AlertDialogContent>
            <AlertDialogHeader>
              <AlertDialogTitle>
                Leave [{v.tag}
                {"] "}
                {v.name}?
              </AlertDialogTitle>
              <AlertDialogDescription>
                You lose the gang bonuses immediately.
                {v.isLeader && v.members.length > 1
                  ? " Leadership passes to the longest-standing member."
                  : 1 === v.members.length
                    ? " You are the last member — the gang dissolves and its XP is gone for good."
                    : ""}
              </AlertDialogDescription>
            </AlertDialogHeader>
            <AlertDialogFooter>
              <AlertDialogCancel>Cancel</AlertDialogCancel>
              <AlertDialogAction
                onClick={() => {
                  g(false);
                  onLeave();
                }}
              >
                Leave gang
              </AlertDialogAction>
            </AlertDialogFooter>
          </AlertDialogContent>
        </AlertDialog>
        <AlertDialog
          open={null !== f}
          onOpenChange={(e) => {
            if (!e) y(null);
          }}
        >
          <AlertDialogContent>
            <AlertDialogHeader>
              <AlertDialogTitle>
                {"Kick "}
                {f?.name}?
              </AlertDialogTitle>
              <AlertDialogDescription>They lose the gang bonuses and their slot opens up. They can be invited back by joining again.</AlertDialogDescription>
            </AlertDialogHeader>
            <AlertDialogFooter>
              <AlertDialogCancel>Cancel</AlertDialogCancel>
              <AlertDialogAction
                onClick={() => {
                  if (f) onKick(f.steamId);
                  y(null);
                }}
              >
                Kick
              </AlertDialogAction>
            </AlertDialogFooter>
          </AlertDialogContent>
        </AlertDialog>
      </div>
    );
  }
  const w = me.cash >= statics.gang.createCost,
    N = me.level >= statics.gang.minLevel;
  return (
    <div className="space-y-3">
      <div className="rounded-lg border border-border bg-card p-4">
        <h3 className="flex items-center gap-1.5 text-sm font-bold text-foreground">
          <Sparkles className="h-4 w-4 text-amber-500" />
          {" Found a gang"}
        </h3>
        <p className="mt-1 text-[10px] leading-relaxed text-muted-foreground">
          {fmtMoney(statics.gang.createCost)}
          {", level "}
          {statics.gang.minLevel}
          {"+. Starts with "}
          {statics.gang.baseCap}
          {" member slots; gang levels add more (up to"}
          {" "}
          {statics.gang.maxCap}) and give every member +{Math.round(100 * statics.gang.yieldPerLevel)}% yield and +{Math.round(100 * statics.gang.xpPerLevel)}
          {"% XP per level. Half of every member's XP also feeds the gang."}
        </p>
        <div className="mt-2 flex flex-wrap items-center gap-1.5">
          <Input value={m} onChange={(e) => x(e.target.value)} placeholder="Gang name (3-20 chars)" maxLength={20} className="min-w-0 flex-1 text-xs" />
          <Input value={u} onChange={(e) => h(e.target.value.toUpperCase())} placeholder="TAG" maxLength={4} className="w-16 font-mono text-xs uppercase" />
          <Button size="sm" disabled={disabled || !w || !N || m.trim().length < 3 || u.trim().length < 2} onClick={() => onCreate(m, u)} className="shrink-0">
            {N ? (w ? "Found" : fmtMoney(statics.gang.createCost)) : `Level ${statics.gang.minLevel}`}
          </Button>
        </div>
      </div>
      {k}
    </div>
  );
}
