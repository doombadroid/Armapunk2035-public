"use client";

import { useState } from "react";
import { Cherry, CircleDollarSign, Dices, Gem, Layers, Loader2, Spade, Trophy, Users } from "lucide-react";
import { cn } from "@/lib/utils";
import { fmtMoney } from "./format";
import { Empty, Panel } from "./primitives";
import { Button } from "./ui/button";
import { Input } from "./ui/input";
import { Select, SelectContent, SelectGroup, SelectItem, SelectTrigger, SelectValue } from "./ui/select";
import { Tabs, TabsList, TabsTrigger } from "./ui/tabs";
import type { ActionPayloads, ActionResult, ActionType, CasinoOutcome, CasinoState, Me } from "./types";

// Reference tF: roulette bet types.
const ROULETTE_BETS = [
  {
    value: "red",
    label: "Red — 2×",
  },
  {
    value: "black",
    label: "Black — 2×",
  },
  {
    value: "even",
    label: "Even — 2×",
  },
  {
    value: "odd",
    label: "Odd — 2×",
  },
  {
    value: "green",
    label: "Green 0 — 36×",
  },
  {
    value: "number",
    label: "Exact number — 36×",
  },
];

type Game = "blackjack" | "slots" | "roulette" | "poker";

// Reference tE: the four games.
const GAMES: { id: Game; label: string; Icon: React.ComponentType<{ className?: string; "data-icon"?: string }>; multiplayer?: boolean }[] = [
  {
    id: "blackjack",
    label: "Blackjack",
    Icon: Spade,
  },
  {
    id: "slots",
    label: "Slots",
    Icon: Cherry,
  },
  {
    id: "roulette",
    label: "Roulette",
    Icon: CircleDollarSign,
  },
  {
    id: "poker",
    label: "Poker",
    Icon: Users,
    multiplayer: true,
  },
];

function parseCard(e: string | null | undefined): { rank: string; suit: string; red: boolean } | null {
  if (!e) return null;
  const t = e.slice(-1);
  return {
    rank: e.slice(0, -1),
    suit:
      {
        S: "♠",
        H: "♥",
        D: "♦",
        C: "♣",
      }[t] ?? "?",
    red: "H" === t || "D" === t,
  };
}

// Reference tO: one playing card (or the face-down placeholder).
function PlayingCard({ card, hidden = false }: { card: string | null; hidden?: boolean }) {
  const s = parseCard(card);
  return hidden || !s ? (
    <div className="flex h-20 w-14 items-center justify-center rounded-md border border-primary/40 bg-primary/15 text-primary-emphasis shadow-sm">
      <Dices className="h-5 w-5" />
    </div>
  ) : (
    <div className={cn("flex h-20 w-14 flex-col justify-between rounded-md border border-border bg-background p-1.5 font-mono shadow-sm", s.red ? "text-red-600 dark:text-red-400" : "text-foreground")}>
      <span className="text-xs font-bold leading-none">{s.rank}</span>
      <span className="self-center text-2xl leading-none">{s.suit}</span>
      <span className="rotate-180 self-end text-xs font-bold leading-none">{s.rank}</span>
    </div>
  );
}

// Reference tB: a labelled hand.
function Hand({ label, cards, score }: { label: string; cards: (string | null)[]; score: number | null }) {
  return (
    <div className="min-w-0">
      <div className="mb-2 flex items-center justify-center gap-2 text-[10px] font-semibold uppercase tracking-wide text-muted-foreground">
        <span>{label}</span>
        {null !== score && <span className="font-mono text-foreground">{score}</span>}
      </div>
      <div className="flex flex-wrap justify-center gap-2">
        {cards.map((e, a) => (
          <PlayingCard key={`${e ?? "hidden"}-${a}`} card={e} hidden={null === e} />
        ))}
      </div>
    </div>
  );
}

// Reference tU: the highlighted result note.
function Note({ children }: { children?: React.ReactNode }) {
  return <div className="mt-3 rounded-lg border border-primary/30 bg-primary/10 px-3 py-2 text-xs leading-relaxed text-primary-emphasis">{children}</div>;
}

// Reference t_: the wager input with a Max button.
function WagerInput({ bet, setBet, max, disabled, label = "Wager" }: { bet: string; setBet: (bet: string) => void; max: number; disabled: boolean; label?: string }) {
  return (
    <label className="block">
      <span className="mb-1 block text-[10px] font-semibold uppercase tracking-wide text-muted-foreground">{label}</span>
      <div className="flex gap-2">
        <Input
          type="number"
          min="1"
          max={max}
          step="1"
          inputMode="numeric"
          value={bet}
          disabled={disabled}
          onChange={(e) => setBet(e.target.value)}
          aria-label={`${label} in Pixel cash`}
          className="font-mono tabular-nums"
        />
        <Button variant="outline" disabled={disabled || max <= 0} onClick={() => setBet(String(max))}>
          Max
        </Button>
      </div>
    </label>
  );
}

// Reference tG: the net result of a wager.
function NetResult({ bet, payout }: { bet: number; payout: number }) {
  const s = payout - bet;
  return (
    <span className={cn("font-mono font-semibold tabular-nums", s > 0 ? "text-green-700 dark:text-green-400" : s < 0 ? "text-red-700 dark:text-red-400" : "text-foreground")}>
      {s > 0 ? "+" : ""}
      {fmtMoney(s)}
      {" net"}
    </span>
  );
}

// Reference tH: the Casino tab (Blackjack, Slots, Roulette, Live Poker Showdown).
export function CasinoTab({
  me,
  casino,
  disabled,
  onAction,
}: {
  me: Me;
  casino: CasinoState;
  disabled: boolean;
  onAction: <T extends ActionType>(type: T, payload?: ActionPayloads[T]) => Promise<ActionResult | null>;
}) {
  const [i, l] = useState<Game>("blackjack"),
    [o, c] = useState("5000"),
    [m, x] = useState("red"),
    [h, p] = useState("17"),
    [g, f] = useState<CasinoOutcome | null>(null),
    [y, v] = useState<CasinoOutcome | null>(null),
    [k, w] = useState<string | null>(null),
    [N, C] = useState(false),
    P = async <T extends ActionType>(e: T, t?: ActionPayloads[T]) => {
      C(true);
      try {
        const a = await onAction(e, t);
        return a?.ok && w(a.message ?? null), a;
      } finally {
        C(false);
      }
    },
    S = casino.blackjack,
    L = casino.poker,
    M = L.seats.some((t) => t.steamId === me.steamId),
    A = !disabled && !N;
  return (
    <div className="flex flex-col gap-3">
      <Panel
        title="Asylum Pixel Casino"
        icon={<Dices className="h-3.5 w-3.5 text-primary-emphasis" />}
        right={
          <span className="font-mono text-[10px] font-semibold tabular-nums text-green-700 dark:text-green-400">
            {fmtMoney(me.cash)}
            {" cash"}
          </span>
        }
      >
        <div className="flex flex-col gap-3">
          <p className="text-xs leading-relaxed text-muted-foreground">
            Every wager is deducted from — and every win returns to — the cash in your Asylum Pixel HUD. This casino has no separate wallet and cannot use portal credit, store
            credit, or real Altis money.
          </p>
          <div className="-mx-1 overflow-x-auto px-1">
            <Tabs
              value={i}
              onValueChange={(e) => {
                l(e as Game);
                w(null);
              }}
            >
              <TabsList className="w-full min-w-max">
                {GAMES.map(({ id, label, Icon, multiplayer }) => (
                  <TabsTrigger
                    key={id}
                    value={id}
                    className="text-xs sm:text-sm data-active:bg-primary data-active:text-primary-foreground dark:data-active:border-transparent dark:data-active:bg-primary dark:data-active:text-primary-foreground"
                  >
                    <Icon data-icon="inline-start" />
                    {label}
                    {multiplayer && <span className="text-[8px] font-bold uppercase tracking-wide opacity-70">Live</span>}
                  </TabsTrigger>
                ))}
              </TabsList>
            </Tabs>
          </div>
        </div>
      </Panel>
      {"blackjack" === i && (
        <Panel title="Blackjack" icon={<Spade className="h-3.5 w-3.5 text-muted-foreground" />} right={<span className="text-[10px] text-muted-foreground">Dealer stands on 17</span>}>
          <div className="flex flex-col gap-4">
            {S ? (
              <div className="flex flex-col items-center gap-4">
                <Hand label="Dealer" cards={S.dealerCards} score={S.dealerScore} />
                <div className="h-px w-full max-w-xs bg-border" />
                <Hand label="Your hand" cards={S.playerCards} score={S.playerScore} />
              </div>
            ) : (
              <Empty>Place a wager to deal a hand.</Empty>
            )}
            {S?.status === "playing" ? (
              <div className="flex flex-wrap justify-center gap-2">
                <Button disabled={!A} onClick={() => P("blackjackhit")}>
                  <Layers data-icon="inline-start" />
                  {" Hit"}
                </Button>
                <Button variant="outline" disabled={!A} onClick={() => P("blackjackstand")}>
                  <Spade data-icon="inline-start" />
                  {" Stand"}
                </Button>
              </div>
            ) : (
              <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-center">
                <div className="w-full sm:max-w-52">
                  <WagerInput bet={o} setBet={c} max={me.cash} disabled={!A} />
                </div>
                <Button
                  disabled={!A}
                  onClick={() =>
                    P("blackjackdeal", {
                      bet: Number(o),
                    })
                  }
                >
                  <Dices data-icon="inline-start" />
                  {" Deal cards"}
                </Button>
              </div>
            )}
            {S && "playing" !== S.status && (
              <Note>
                {"won" === S.status ? "You won the hand. " : "push" === S.status ? "Push. " : "Dealer won. "}
                <NetResult bet={S.bet} payout={S.payout} />
              </Note>
            )}
          </div>
        </Panel>
      )}
      {"slots" === i && (
        <Panel title="Slot Machine" icon={<Cherry className="h-3.5 w-3.5 text-muted-foreground" />} right={<span className="text-[10px] text-muted-foreground">7s pay 25×</span>}>
          <div className="flex flex-col gap-4">
            <div className="flex justify-center gap-2 rounded-xl border-2 border-primary/30 bg-surface p-4">
              {(g?.reels ?? ["CHERRY", "BAR", "BELL"]).map((e, a) => (
                <div
                  key={`${e}-${a}`}
                  className="flex h-16 w-16 items-center justify-center rounded-lg border border-border bg-background text-center text-[10px] font-black tracking-wide text-primary-emphasis"
                >
                  {"CHERRY" === e ? <Cherry className="h-7 w-7" /> : "BELL" === e ? <Gem className="h-7 w-7" /> : "7" === e ? <span className="text-3xl">7</span> : e}
                </div>
              ))}
            </div>
            <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-center">
              <div className="w-full sm:max-w-52">
                <WagerInput bet={o} setBet={c} max={me.cash} disabled={!A} />
              </div>
              <Button
                disabled={!A}
                onClick={async () => {
                  const e = await P("slots", {
                    bet: Number(o),
                  });
                  if (e?.ok) f(e.casino ?? null);
                }}
              >
                {N ? <Loader2 className="animate-spin" data-icon="inline-start" /> : <Cherry data-icon="inline-start" />}
                {" Spin"}
              </Button>
            </div>
            {g && (
              <Note>
                <NetResult bet={g.bet ?? 0} payout={g.payout ?? 0} />
              </Note>
            )}
          </div>
        </Panel>
      )}
      {"roulette" === i && (
        <Panel
          title="Roulette"
          icon={<CircleDollarSign className="h-3.5 w-3.5 text-muted-foreground" />}
          right={<span className="text-[10px] text-muted-foreground">Straight / green pay 36×</span>}
        >
          <div className="flex flex-col gap-4">
            <div className="grid gap-3 sm:grid-cols-2">
              <WagerInput bet={o} setBet={c} max={me.cash} disabled={!A} />
              <div>
                <span className="mb-1 block text-[10px] font-semibold uppercase tracking-wide text-muted-foreground">Bet type</span>
                <Select items={ROULETTE_BETS} value={m} disabled={!A} onValueChange={(e) => x(e ?? m)}>
                  <SelectTrigger className="w-full" aria-label="Roulette bet type">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectGroup>
                      {ROULETTE_BETS.map((e) => (
                        <SelectItem key={e.value} value={e.value}>
                          {e.label}
                        </SelectItem>
                      ))}
                    </SelectGroup>
                  </SelectContent>
                </Select>
              </div>
            </div>
            {"number" === m && (
              <div className="max-w-52">
                <label className="block">
                  <span className="mb-1 block text-[10px] font-semibold uppercase tracking-wide text-muted-foreground">Number (0–36)</span>
                  <Input type="number" min="0" max="36" step="1" value={h} disabled={!A} onChange={(e) => p(e.target.value)} />
                </label>
              </div>
            )}
            <div className="flex flex-wrap items-center gap-3">
              <Button
                disabled={!A}
                onClick={async () => {
                  const e = await P("roulette", {
                    bet: Number(o),
                    choice: m,
                    number: Number(h),
                  });
                  if (e?.ok) v(e.casino ?? null);
                }}
              >
                <CircleDollarSign data-icon="inline-start" />
                {" Spin wheel"}
              </Button>
              {y && (
                <span
                  className={cn(
                    "rounded-md border px-3 py-1.5 font-mono text-sm font-bold tabular-nums",
                    "red" === y.color
                      ? "border-red-500/40 bg-red-500/10 text-red-700 dark:text-red-400"
                      : "black" === y.color
                        ? "border-border bg-muted text-foreground"
                        : "border-green-500/40 bg-green-500/10 text-green-700 dark:text-green-400",
                  )}
                >
                  {y.number}
                  {" "}
                  {y.color}
                </span>
              )}
            </div>
            {y && (
              <Note>
                <NetResult bet={y.bet ?? 0} payout={y.payout ?? 0} />
              </Note>
            )}
          </div>
        </Panel>
      )}
      {"poker" === i && (
        <Panel
          title="Live Poker Showdown"
          icon={<Users className="h-3.5 w-3.5 text-muted-foreground" />}
          right={<span className="text-[10px] text-muted-foreground">2–4 players · winner takes the pot</span>}
        >
          <div className="flex flex-col gap-4">
            <div className="rounded-lg border border-border bg-surface p-3">
              <div className="mb-2 flex items-center justify-between gap-3">
                <span className="text-[10px] font-semibold uppercase tracking-wide text-muted-foreground">Table</span>
                <span className="font-mono text-xs font-semibold tabular-nums text-foreground">
                  {"Pot "}
                  {fmtMoney(L.pot)}
                </span>
              </div>
              {0 === L.seats.length ? (
                <Empty>The table is open. Set the buy-in and take the first seat.</Empty>
              ) : (
                <ul className="divide-y divide-border">
                  {L.seats.map((a) => (
                    <li key={a.steamId} className="flex items-center gap-2 py-2 text-xs">
                      <span
                        className={cn(
                          "flex size-5 items-center justify-center rounded-full border text-[10px] font-bold",
                          a.steamId === me.steamId ? "border-primary/40 bg-primary/15 text-primary-emphasis" : "border-border bg-background text-muted-foreground",
                        )}
                      >
                        {a.name.slice(0, 1).toUpperCase()}
                      </span>
                      <span className={cn("min-w-0 flex-1 truncate", a.steamId === me.steamId ? "font-semibold text-primary-emphasis" : "text-foreground")}>
                        {a.name}
                        {a.steamId === me.steamId ? " (you)" : ""}
                      </span>
                      <span className="font-mono text-[10px] tabular-nums text-muted-foreground">{fmtMoney(a.buyIn)}</span>
                    </li>
                  ))}
                </ul>
              )}
            </div>
            {M ? (
              <div className="flex flex-wrap gap-2">
                <Button disabled={!A || L.seats.length < L.minPlayers} onClick={() => P("pokerdeal")}>
                  <Dices data-icon="inline-start" />
                  {" Deal showdown"}
                </Button>
                <Button variant="outline" disabled={!A} onClick={() => P("pokerleave")}>
                  Leave table
                </Button>
                {L.seats.length < L.minPlayers && <span className="self-center text-xs text-muted-foreground">Waiting for one more player.</span>}
              </div>
            ) : (
              <div className="flex flex-col gap-3 sm:flex-row sm:items-end">
                <div className="w-full sm:max-w-52">
                  <WagerInput bet={o} setBet={c} max={me.cash} disabled={!A} label={L.buyIn ? `Buy-in (table requires ${fmtMoney(L.buyIn)})` : "Set table buy-in"} />
                </div>
                <Button
                  disabled={!A || (null !== L.buyIn && Number(o) !== L.buyIn)}
                  onClick={() =>
                    P("pokerjoin", {
                      buyIn: Number(o),
                    })
                  }
                >
                  <Users data-icon="inline-start" />
                  {" Take a seat"}
                </Button>
              </div>
            )}
            {L.lastResult && (
              <div className="rounded-lg border border-primary/30 bg-primary/5 p-3">
                <div className="mb-3 flex flex-wrap items-center gap-2">
                  <Trophy className="h-4 w-4 text-amber-500" />
                  <span className="text-xs font-semibold text-foreground">
                    {"Last showdown · "}
                    {fmtMoney(L.lastResult.pot)}
                    {" pot"}
                  </span>
                </div>
                <div className="mb-3 flex flex-wrap gap-1.5">
                  {L.lastResult.board.map((e, a) => (
                    <PlayingCard key={`${e}-${a}`} card={e} />
                  ))}
                </div>
                <div className="flex flex-col gap-1.5">
                  {L.lastResult.players.map((e) => {
                    const a = L.lastResult?.winners.find((t) => t.steamId === e.steamId);
                    return (
                      <div key={e.steamId} className="flex flex-wrap items-center gap-2 text-xs">
                        <span className="min-w-24 font-medium text-foreground">{e.name}</span>
                        <div className="flex gap-1">
                          {e.cards.map((e, a) => (
                            <PlayingCard key={`${e}-${a}`} card={e} />
                          ))}
                        </div>
                        <span className="text-muted-foreground">{e.hand}</span>
                        {a && <span className="font-mono font-semibold tabular-nums text-green-700 dark:text-green-400">+{fmtMoney(a.payout)}</span>}
                      </div>
                    );
                  })}
                </div>
              </div>
            )}
          </div>
        </Panel>
      )}
      {k && <Note>{k}</Note>}
      <p className="px-1 text-center text-[10px] leading-relaxed text-muted-foreground">
        Pixel casino games are simulated in-game entertainment. Wagers and payouts affect only your Asylum Pixel cash balance.
      </p>
    </div>
  );
}
