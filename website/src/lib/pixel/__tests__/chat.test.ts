// The chat delta protocol the reference client merges by: a generation or revision mismatch yields
// the full window; a match yields only the rows newer than sinceChat; chatOldestId is the oldest
// retained id so the client can drop what the server pruned.
import { describe, expect, it } from "vitest";
import { chatWindow, parseChatCursor } from "../chat";
import { apply } from "../engine";
import type { ChatRow } from "../types";
import { NOW, err, fresh, noRng, ok, shared } from "./helpers";

const row = (id: number): ChatRow => ({ id, at: NOW + id, steamId: "76561190000000002", name: "Player1", faction: "civ", text: `m${id}` });
const RET = [row(965), row(968), row(969), row(970), row(971), row(972), row(973)];

describe("chatWindow", () => {
  it("first poll (no cursor) returns the newest window, newest first, with the oldest retained id", () => {
    const w = chatWindow(RET, 4, "gen-a", null);
    expect(w.chat.map((r) => r.id)).toEqual([973, 972, 971, 970, 969, 968, 965]);
    expect(w).toMatchObject({ chatOldestId: 965, chatRevision: 4, chatGeneration: "gen-a" });
  });

  it("a matching cursor returns only rows newer than sinceChat", () => {
    const w = chatWindow(RET, 4, "gen-a", { sinceChat: 970, chatRevision: 4, chatGeneration: "gen-a" });
    expect(w.chat.map((r) => r.id)).toEqual([973, 972, 971]);
    expect(chatWindow(RET, 4, "gen-a", { sinceChat: 973, chatRevision: 4, chatGeneration: "gen-a" }).chat).toEqual([]);
  });

  it("a revision or generation mismatch returns the full window again", () => {
    expect(chatWindow(RET, 5, "gen-a", { sinceChat: 973, chatRevision: 4, chatGeneration: "gen-a" }).chat).toHaveLength(7);
    expect(chatWindow(RET, 4, "gen-b", { sinceChat: 973, chatRevision: 4, chatGeneration: "gen-a" }).chat).toHaveLength(7);
  });

  it("caps the window at 40 rows and reports 0 as the oldest id when empty", () => {
    const many = Array.from({ length: 100 }, (_, i) => row(i + 1));
    expect(chatWindow(many, 1, "g", null).chat).toHaveLength(40);
    expect(chatWindow(many, 1, "g", null).chat[0].id).toBe(100);
    expect(chatWindow([], 1, "g", null)).toEqual({ chat: [], chatOldestId: 0, chatRevision: 1, chatGeneration: "g" });
  });

  it("parseChatCursor needs a generation; numbers default to 0", () => {
    expect(parseChatCursor({})).toBeNull();
    expect(parseChatCursor({ sinceChat: "12", chatRevision: "3", chatGeneration: "g" })).toEqual({ sinceChat: 12, chatRevision: 3, chatGeneration: "g" });
    expect(parseChatCursor({ sinceChat: "x", chatGeneration: "g" })).toEqual({ sinceChat: 0, chatRevision: 0, chatGeneration: "g" });
  });
});

describe("chat action", () => {
  it("accepts a trimmed non-empty message up to 240 characters and rejects the rest", () => {
    expect(ok(apply(fresh(), shared(), { type: "chat", text: "hello" }, NOW + 1, noRng)).result).toEqual({ ok: true });
    expect(err(apply(fresh(), shared(), { type: "chat", text: "   " }, NOW + 1, noRng))).toBe("Say something.");
    expect(err(apply(fresh(), shared(), { type: "chat", text: "x".repeat(241) }, NOW + 1, noRng))).toBe("Keep it under 240 characters.");
    expect(ok(apply(fresh(), shared(), { type: "chat", text: "x".repeat(240) }, NOW + 1, noRng)).result.ok).toBe(true);
  });

  it("goes through on the road and in custody (the chat rail is always open)", () => {
    const road = fresh({ travelTo: "neochori", travelUntil: NOW + 7000 });
    expect(apply(road, shared(), { type: "chat", text: "gg" }, NOW + 1, noRng).result.ok).toBe(true);
  });
});
