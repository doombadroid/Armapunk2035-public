// @vitest-environment jsdom
// Render smoke: PixelGame mounted against the reference snapshot shape (state_example.json) with
// fetch mocked; the header, the player card figures and the five city cards must render.

import { cleanup, render, screen, waitFor } from "@testing-library/react";
import { NuqsTestingAdapter } from "nuqs/adapters/testing";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import staticsJson from "@/lib/pixel/reference/statics.json";
import snapshotJson from "@/lib/pixel/reference/state_example.json";
import PixelGame from "../PixelGame";
import type { Snapshot, Statics } from "../types";

const statics = staticsJson as Statics;
const snapshot = snapshotJson as unknown as Snapshot;

class ResizeObserverStub {
  observe() {}
  unobserve() {}
  disconnect() {}
}

function jsonResponse(body: unknown, status = 200): Response {
  return {
    ok: status >= 200 && status < 300,
    status,
    headers: new Headers(),
    json: async () => body,
  } as unknown as Response;
}

describe("PixelGame smoke", () => {
  const fetchMock = vi.fn<typeof fetch>();

  beforeEach(() => {
    vi.stubGlobal("ResizeObserver", ResizeObserverStub);
    fetchMock.mockReset();
    fetchMock.mockImplementation(async (input) => {
      const url = String(input);
      if (url.startsWith("/api/pixel/state?")) return jsonResponse(snapshot);
      if (url === "/api/pixel/action") return jsonResponse({ snapshot, result: { ok: true } });
      return jsonResponse({ error: "not found" }, 404);
    });
    vi.stubGlobal("fetch", fetchMock);
  });

  afterEach(() => {
    cleanup();
    vi.unstubAllGlobals();
  });

  it("renders the header, the player card and the five cities from the reference snapshot", async () => {
    render(
      <NuqsTestingAdapter>
        <PixelGame statics={statics} canAccessCasino={true} />
      </NuqsTestingAdapter>,
    );
    expect(screen.getByRole("heading", { level: 1 }).textContent).toBe("Armapunk Pixel");
    expect(screen.getByText("Landing at Kavala…")).toBeTruthy();

    // "Doomba" is the player card, the roster row and the feed lines once the snapshot lands.
    await waitFor(() => expect(screen.getAllByText("Doomba").length).toBeGreaterThan(0));
    // The polled state request carries the chat cursor params.
    const stateCall = fetchMock.mock.calls.find(([input]) => String(input).startsWith("/api/pixel/state?"));
    expect(stateCall).toBeTruthy();
    const params = new URL(String(stateCall?.[0]), "http://x").searchParams;
    expect([...params.keys()].sort()).toEqual(["chatGeneration", "chatRevision", "sinceChat"]);

    // Player card: cash compact + exact, level, location, "Wanted" absent (heat 0).
    expect(screen.getByText("$5.50M")).toBeTruthy();
    expect(screen.getByText("$5,495,846")).toBeTruthy();
    expect(screen.getByText("LVL 100")).toBeTruthy();
    expect(screen.getAllByText("Kavala").length).toBeGreaterThan(0);
    expect(screen.queryByText("Wanted")).toBeNull();
    expect(screen.getByText("APD sees you at 22")).toBeTruthy();

    // The five city cards.
    for (const name of ["Kavala", "Neochori", "Athira", "Pyrgos", "Sofia"]) expect(screen.getAllByText(name).length).toBeGreaterThan(0);
    expect(screen.getByText("you are here")).toBeTruthy();
    expect(screen.getByText("2 online")).toBeTruthy();

    // The default tab is Work, with the current city's sites.
    expect(screen.getByText("Every activity")).toBeTruthy();
    expect(screen.getByText("Apple Orchard")).toBeTruthy();
    expect(screen.getByText("Richest on Altis")).toBeTruthy();
  });
});
