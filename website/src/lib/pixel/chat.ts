// Armapunk Pixel v3 chat delta protocol, the pure half. The client polls with the newest id it holds
// (`sinceChat`), the revision and the generation it last saw; it takes a full window whenever
// either changed, otherwise only the rows newer than sinceChat, and it drops local rows older than
// `chatOldestId` (the oldest row the server still retains).
import { INFERRED } from "./content";
import type { ChatCursor, ChatRow, ChatWindow } from "./types";

/**
 * `retained` is the server's retained window, newest first. A generation or revision mismatch (or
 * a first poll) returns the newest `chatWindow` rows; a match returns only rows with id above
 * sinceChat, newest first, capped at the same window.
 */
export function chatWindow(retained: ChatRow[], revision: number, generation: string, cursor: ChatCursor | null): ChatWindow {
  const oldest = retained.length ? Math.min(...retained.map((r) => r.id)) : 0;
  const base = { chatOldestId: oldest, chatRevision: revision, chatGeneration: generation };
  const sorted = [...retained].sort((a, b) => b.id - a.id);
  if (!cursor || cursor.chatGeneration !== generation || cursor.chatRevision !== revision) {
    return { ...base, chat: sorted.slice(0, INFERRED.chatWindow) };
  }
  return { ...base, chat: sorted.filter((r) => r.id > cursor.sinceChat).slice(0, INFERRED.chatWindow) };
}

/** Parse the cursor the client sends (query string or action body); null when it has none yet. */
export function parseChatCursor(v: { sinceChat?: unknown; chatRevision?: unknown; chatGeneration?: unknown }): ChatCursor | null {
  const gen = typeof v.chatGeneration === "string" ? v.chatGeneration : "";
  if (!gen) return null;
  const since = Number(v.sinceChat);
  const rev = Number(v.chatRevision);
  return { sinceChat: Number.isFinite(since) ? since : 0, chatRevision: Number.isFinite(rev) ? rev : 0, chatGeneration: gen };
}
