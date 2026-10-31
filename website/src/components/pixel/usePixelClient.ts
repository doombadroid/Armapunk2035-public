"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import statics from "@/lib/pixel/reference/statics.json";
import type { ActionPayloads, ActionResult, ActionType, ChatMessage, Connection, Pop, PopTone, Snapshot } from "./types";

// Reference: the anonymous hook inside the page component. Polls GET /api/pixel/state (2.5 s
// visible / 30 s hidden, back-off min(30000, 2500 * 2^min(fail, 4)), 10 s abort, 429 Retry-After),
// merges chat by generation / revision, ticks a 100 ms clock, dispatches POST /api/pixel/action
// and floats the result "pops".

export interface PixelClient {
  snap: Snapshot | null;
  loading: boolean;
  error: string | null;
  clock: number;
  pops: Pop[];
  busy: boolean;
  act: <T extends ActionType>(type: T, payload?: ActionPayloads[T]) => Promise<ActionResult | null>;
  chatPending: boolean;
  chatDraft: string;
  setChatDraft: React.Dispatch<React.SetStateAction<string>>;
  chatError: string | null;
  sendChat: (text: string) => Promise<boolean>;
  chatUnread: number;
  markChatRead: (id: number) => void;
  chatSentVersion: number;
  connection: Connection;
  lastUpdated: number | null;
}

interface ActionResponse {
  snapshot: Snapshot;
  result: ActionResult;
}

// Reference: the inline chat merge (existing, snapshot, reset).
function mergeChat(e: ChatMessage[], t: Snapshot, a = false): ChatMessage[] {
  if (a) return [...t.chat].sort((e, t) => t.id - e.id);
  const s = e.filter((e) => e.id >= t.chatOldestId);
  if (0 === t.chat.length) return s.length === e.length ? e : s;
  const r = new Set(t.chat.map((e) => e.id));
  return [...t.chat, ...s.filter((e) => !r.has(e.id))].sort((e, t) => t.id - e.id);
}

export function usePixelClient(itemName: (id: string) => string): PixelClient {
  const [t, a] = useState<Snapshot | null>(null),
    [r, n] = useState(true),
    [i, l] = useState<string | null>(null),
    [o, d] = useState<Pop[]>([]),
    [c, m] = useState(false),
    [x, u] = useState(() => Date.now()),
    [h, p] = useState(false),
    [g, f] = useState(""),
    [b, y] = useState<string | null>(null),
    [j, v] = useState(0),
    [w, N] = useState(0),
    [C, P] = useState<Connection>("connecting"),
    [S, L] = useState<number | null>(null),
    M = useRef(false),
    A = useRef(0),
    I = useRef(false),
    $ = useRef(new Set<AbortController>());
  useEffect(() => {
    I.current = true;
    const inflight = $.current;
    return () => {
      I.current = false;
      for (const e of inflight) e.abort();
      inflight.clear();
    };
  }, []);
  const T = useCallback((e: number) => N((t) => Math.max(t, e)), []),
    D = useRef(0),
    R = useRef(0),
    F = useRef<{ now: number; received: number } | null>(null),
    E = useRef(0),
    O = useRef(0),
    B = useRef<ChatMessage[]>([]),
    U = useRef(0),
    _ = useRef<string | undefined>(undefined),
    G = useRef(new Set<string>()),
    H = () => B.current[0]?.id ?? 0,
    W = useCallback((e: Snapshot, t: number) => {
      if (G.current.has(e.chatGeneration)) return;
      const s = _.current,
        r = e.chatGeneration !== s;
      if (r && t < O.current) return;
      if (r && s) G.current.add(s);
      const n = r || e.chatRevision !== U.current;
      B.current = mergeChat(B.current, e, n);
      if (undefined === s) N(B.current[0]?.id ?? 0);
      else if (r) N(0);
      U.current = e.chatRevision;
      _.current = e.chatGeneration;
      const i = r || e.now >= R.current;
      if (i) {
        R.current = e.now;
        O.current = Math.max(O.current, t);
        F.current = {
          now: e.now,
          received: performance.now(),
        };
        u(e.now);
        L(e.now);
      }
      a((t) =>
        i
          ? {
              ...e,
              chat: B.current,
            }
          : t
            ? {
                ...t,
                chat: B.current,
              }
            : null,
      );
    }, []),
    Y = useCallback((e: string, t: PopTone) => {
      const a = ++D.current;
      d((s) => [
        ...s.slice(-8),
        {
          id: a,
          text: e,
          tone: t,
        },
      ]);
      setTimeout(() => d((e) => e.filter((e) => e.id !== a)), 1300);
    }, []);
  useEffect(() => {
    let e: ReturnType<typeof setTimeout> | undefined,
      t = true,
      a: AbortController | null = null,
      s = false,
      r = 0,
      i = 0;
    const o = async () => {
        if ((clearTimeout(e), !t)) return;
        if (a) {
          s = true;
          return;
        }
        if (Date.now() < i) {
          e = setTimeout(o, i - Date.now());
          return;
        }
        if (!navigator.onLine) {
          P("offline");
          e = setTimeout(o, 3e4);
          return;
        }
        const d = ++E.current,
          c = new AbortController();
        a = c;
        const m = setTimeout(() => c.abort(), 1e4);
        let x = document.hidden ? 3e4 : 2500;
        try {
          const e = new URLSearchParams({
              sinceChat: String(H()),
              chatRevision: String(U.current),
              chatGeneration: _.current ?? "",
            }),
            a = await fetch(`/api/pixel/state?${e}`, {
              credentials: "same-origin",
              signal: c.signal,
            });
          if (!t || c.signal.aborted) return;
          if (a.ok) {
            const e: Snapshot = await a.json();
            if (!t || c.signal.aborted) return;
            W(e, d);
            r = 0;
            l(null);
            P("connected");
          } else {
            const e: { error?: string } | null = await a.json().catch(() => null);
            if (!t || c.signal.aborted) return;
            if (429 === a.status) {
              const e = a.headers.get("Retry-After"),
                t = null === e ? NaN : Number(e),
                s = Number.isFinite(t) ? 1e3 * t : Date.parse(e ?? "") - Date.now();
              x = Math.max(2500, Number.isFinite(s) ? s : 2500);
              i = Date.now() + x;
            } else {
              r += 1;
              x = Math.min(3e4, 2500 * 2 ** Math.min(r, 4));
            }
            l(e?.error ?? (401 === a.status ? "Your session expired. Sign in again." : "Unable to refresh the island."));
            P("reconnecting");
          }
        } catch {
          if (t) {
            r += 1;
            x = Math.min(3e4, 2500 * 2 ** Math.min(r, 4));
            l(c.signal.aborted ? "Refresh timed out. Reconnecting..." : "Lost contact with the server.");
            P(navigator.onLine ? "reconnecting" : "offline");
          }
        } finally {
          if ((clearTimeout(m), (a = null), t)) {
            n(false);
            const t = s;
            s = false;
            e = setTimeout(o, Math.max(i - Date.now(), t ? 0 : x));
          }
        }
      },
      d = () => {
        if (!document.hidden) o();
      },
      c = () => P("offline");
    o();
    document.addEventListener("visibilitychange", d);
    window.addEventListener("focus", d);
    window.addEventListener("online", d);
    window.addEventListener("offline", c);
    return () => {
      t = false;
      clearTimeout(e);
      a?.abort();
      document.removeEventListener("visibilitychange", d);
      window.removeEventListener("focus", d);
      window.removeEventListener("online", d);
      window.removeEventListener("offline", c);
    };
  }, [W]);
  useEffect(() => {
    const e = setInterval(() => {
      const e = F.current;
      u(e ? e.now + performance.now() - e.received : Date.now());
    }, 100);
    return () => clearInterval(e);
  }, []);
  const z = useCallback(
      async <K extends ActionType>(t: K, a: ActionPayloads[K] | Record<string, never> = {}): Promise<ActionResult | null> => {
        const s = "chat" === t;
        if (s && M.current) return null;
        if (s) {
          M.current = true;
          p(true);
          y(null);
        } else {
          A.current += 1;
          m(true);
        }
        const r = ++E.current,
          n = new AbortController();
        $.current.add(n);
        const i = setTimeout(() => n.abort(), 1e4);
        try {
          const i = await fetch("/api/pixel/action", {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
            },
            credentials: "same-origin",
            signal: n.signal,
            body: JSON.stringify({
              type: t,
              ...a,
              sinceChat: H(),
              chatRevision: U.current,
              chatGeneration: _.current,
            }),
          });
          if (!i.ok) {
            const e: { error?: string } | null = await i.json().catch(() => null);
            if (!I.current || n.signal.aborted) return null;
            const t = e?.error ?? (401 === i.status ? "Signed out" : "Server error");
            if (s) y(t);
            else Y(t, "bad");
            return null;
          }
          const l: ActionResponse = await i.json();
          if (!I.current || n.signal.aborted) return null;
          W(l.snapshot, r);
          const o = l.result;
          if (o.ok) {
            if (o.gained) for (const [t, a] of Object.entries(o.gained)) Y(`+${a} ${itemName(t)}`, o.jackpot ? "gold" : "gain");
            if (o.cash) Y(`${o.cash < 0 ? "-" : "+"}$${Math.abs(o.cash).toLocaleString()}`, o.cash < 0 ? "bad" : "cash");
            if (o.xp) Y(`+${o.xp} XP`, "xp");
            if (o.papers) Y(`+${o.papers} contract paper${1 === o.papers ? "" : "s"}`, "gain");
            if (o.chest) Y(`Found: ${CHEST_NAMES[o.chest] ?? "a chest"}!`, "gold");
            if (o.heat) Y(`+${o.heat} heat`, "heat");
            if (o.talentPoints) Y(`LEVEL UP — +${o.talentPoints} talent point${1 === o.talentPoints ? "" : "s"}`, "gold");
            if (!o.gained && !o.cash && !o.xp && o.message) Y(o.message, "gain");
          } else if (s) y(o.error ?? "Message was not accepted.");
          else Y(o.error ?? "No good", "bad");
          return o;
        } catch {
          if (I.current) {
            if (s) y("Message delivery could not be confirmed. Check chat before sending again.");
            else Y("Network error", "bad");
          }
          return null;
        } finally {
          clearTimeout(i);
          $.current.delete(n);
          if (s) {
            M.current = false;
            if (I.current) p(false);
          } else {
            A.current -= 1;
            if (I.current) m(A.current > 0);
          }
        }
      },
      [Y, W, itemName],
    ),
    q = useCallback(
      async (e: string) => {
        const t = await z("chat", {
          text: e,
        });
        return !!t?.ok && !!I.current && (f((t) => (t.trim() === e.trim() ? "" : t)), v((e) => e + 1), true);
      },
      [z],
    ),
    V = (t?.chat ?? []).filter((e) => e.id > w).length;
  return {
    snap: t,
    loading: r,
    error: i,
    clock: x,
    pops: o,
    busy: c,
    act: z,
    chatPending: h,
    chatDraft: g,
    setChatDraft: f,
    chatError: b,
    sendChat: q,
    chatUnread: V,
    markChatRead: T,
    chatSentVersion: j,
    connection: C,
    lastUpdated: S,
  };
}

// Reference k: the bundle's inline chest table keyed by rarity (a dead duplicate of statics.chests,
// so it is read from the same JSON the page prop comes from).
const CHEST_NAMES: Record<string, string> = Object.fromEntries(statics.chests.map((e) => [e.rarity, e.name]));
