"use client";

import { useCallback, useEffect, useLayoutEffect, useRef, useState } from "react";
import { ArrowDown, MessageSquare, Send, Shield } from "lucide-react";
import { cn } from "@/lib/utils";
import { fmtAgo } from "./format";
import { Empty, Panel } from "./primitives";
import type { ChatMessage, Connection } from "./types";

// Reference eR: the chat panel (scroll anchoring, unread tracking, send form).
export function ChatPanel({
  messages,
  meSteamId,
  clock,
  maxLen,
  chatPending,
  draft,
  onDraftChange,
  onSend,
  visible,
  onRead,
  sendError,
  sentVersion,
  connection,
  lastUpdated,
}: {
  messages: ChatMessage[];
  meSteamId: string;
  clock: number;
  maxLen: number;
  chatPending: boolean;
  draft: string;
  onDraftChange: (draft: string) => void;
  onSend: (text: string) => Promise<boolean>;
  visible: boolean;
  onRead: (id: number) => void;
  sendError: string | null;
  sentVersion: number;
  connection: Connection;
  lastUpdated: number | null;
}) {
  const f = useRef<HTMLUListElement>(null);
  const b = useRef(true);
  const y = useRef<{ id: string | undefined; offset: number } | null>(null);
  const [v, k] = useState(true);
  const w = useRef(false);
  const N = useRef(false);
  const C = useRef(sentVersion);
  const P = messages[0]?.id ?? 0;
  const S = useRef(P);
  // eslint-disable-next-line react-hooks/refs -- reference: the newest message id is mirrored into a ref during render
  S.current = P;
  const L = [...messages].reverse();
  const M = useCallback(() => {
    const e = f.current;
    if (!e || !visible || 0 === e.clientHeight) return;
    const t = e.getBoundingClientRect().top,
      a = Array.from(e.querySelectorAll<HTMLElement>("[data-message-id]")).find((e) => e.getBoundingClientRect().bottom > t);
    y.current = a
      ? {
          id: a.dataset.messageId,
          offset: a.getBoundingClientRect().top - t,
        }
      : null;
  }, [visible]);
  const A = useCallback(() => {
    const e = f.current;
    if (e && visible && 0 !== e.clientHeight && !document.hidden) {
      e.scrollTop = e.scrollHeight;
      b.current = true;
      k(true);
      M();
      onRead(S.current);
    }
  }, [onRead, M, visible]);
  const I = useCallback(() => {
    const e = f.current,
      t = y.current;
    if (!e || !visible || !e.clientHeight) return;
    const a = t ? e.querySelector(`[data-message-id="${t.id}"]`) : null;
    if (a && t) e.scrollTop += a.getBoundingClientRect().top - e.getBoundingClientRect().top - t.offset;
    M();
  }, [M, visible]);
  useLayoutEffect(() => {
    const e = f.current,
      t = visible && !N.current,
      a = sentVersion !== C.current;
    N.current = visible;
    C.current = sentVersion;
    if (e && visible && 0 !== e.clientHeight) {
      if (t || a || b.current) A();
      else I();
    }
  }, [messages, P, visible, sentVersion, A, I]);
  useEffect(() => {
    const e = f.current;
    if (!e) return;
    const t = new ResizeObserver(() => {
      if (b.current) A();
      else I();
    });
    t.observe(e);
    const a = () => {
      if (!document.hidden && b.current) A();
    };
    document.addEventListener("visibilitychange", a);
    return () => {
      t.disconnect();
      document.removeEventListener("visibilitychange", a);
    };
  }, [A, I]);
  const T = async () => {
    const e = draft.trim();
    if (e && !chatPending && !w.current) {
      w.current = true;
      try {
        await onSend(e);
      } finally {
        w.current = false;
      }
    }
  };
  return (
    <Panel title="Chat" icon={<MessageSquare className="size-3.5 text-muted-foreground" />} bodyClassName="p-0">
      <div role="status" className="px-3 pt-2 text-[10px] text-muted-foreground">
        {"connected" === connection ? "Connected" : "offline" === connection ? "Offline. Reconnecting when you return" : "connecting" === connection ? "Connecting..." : "Reconnecting..."}
        {null !== lastUpdated && "connected" !== connection && ` - Updated ${fmtAgo(clock - lastUpdated)}`}
      </div>
      <ul
        ref={f}
        onScroll={() => {
          const e = f.current;
          if (!e || !visible || !e.clientHeight) return;
          const t = e.scrollHeight - e.scrollTop - e.clientHeight < 40;
          b.current = t;
          k(t);
          M();
          if (t && !document.hidden) onRead(P);
        }}
        aria-label="Chat messages"
        aria-live="off"
        className="flex max-h-56 flex-col gap-1.5 overflow-y-auto px-3 py-2 [overflow-anchor:none]"
      >
        {0 === L.length ? (
          <li>
            <Empty>{"Nobody's said anything yet."}</Empty>
          </li>
        ) : (
          L.map((e) => (
            <li key={e.id} data-message-id={e.id} className="shrink-0 text-[11px] leading-snug">
              <span className="mr-1 font-mono text-[9px] text-muted-foreground">{fmtAgo(clock - e.at)}</span>
              {"cop" === e.faction && <Shield className="mr-0.5 inline size-3 shrink-0 text-primary-emphasis" />}
              <span className={cn("font-semibold", e.steamId === meSteamId ? "text-primary-emphasis" : "text-foreground")}>{e.name}:</span>
              {" "}
              <span className="break-words text-foreground">{e.text}</span>
            </li>
          ))
        )}
      </ul>
      {!v && (
        <button type="button" onClick={A} className="flex w-full items-center justify-center gap-1 border-t border-border py-1 text-xs text-primary-emphasis">
          <ArrowDown className="size-3" />
          {" Jump to latest"}
        </button>
      )}
      {sendError && (
        <p role="alert" className="px-3 py-1 text-xs text-destructive">
          {sendError}
        </p>
      )}
      <form
        onSubmit={(e) => {
          e.preventDefault();
          T();
        }}
        className="flex items-center gap-1.5 border-t border-border p-2"
      >
        <input
          value={draft}
          onChange={(e) => onDraftChange(e.target.value)}
          maxLength={maxLen}
          aria-label="Chat message"
          aria-invalid={!!sendError}
          placeholder="Say something..."
          className="min-w-0 flex-1 rounded-md border border-border bg-surface px-2 py-1.5 text-xs text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-1 focus:ring-ring"
        />
        <button
          type="submit"
          disabled={chatPending || !draft.trim()}
          aria-label="Send message"
          className="inline-flex shrink-0 items-center justify-center rounded-md bg-primary p-1.5 text-primary-foreground transition hover:bg-primary/90 disabled:cursor-not-allowed disabled:opacity-40"
        >
          <Send className="size-3.5" />
        </button>
      </form>
    </Panel>
  );
}
