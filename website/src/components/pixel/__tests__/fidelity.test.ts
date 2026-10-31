// Fidelity oracle: every string and every class in the Armapunk Pixel client port must come from
// the reference game. Two oracles per kind, both machine-extracted from the reference:
//  - reference_strings.json / reference_classes.json: the archive's own extraction of the page chunk;
//  - derived_strings.json / derived_classes.json: this test's extractor (extract.ts) run over the
//    de-minified page, its shadcn wrappers and the wrappers recovered from the site's shared chunks
//    (archive work/AsylumPixel.deminified.jsx + work/ui/*.jsx; regenerate with the same extractor).
// Anything else must be on the allowlist below, each entry with its reason.

import { readdirSync, readFileSync, statSync } from "node:fs";
import { join, relative } from "node:path";
import { describe, expect, it } from "vitest";
import { extractFromSource } from "./extract";
import referenceClasses from "./reference/reference_classes.json";
import referenceStrings from "./reference/reference_strings.json";
import derivedClasses from "./reference/derived_classes.json";
import derivedStrings from "./reference/derived_strings.json";

const PIXEL = join(__dirname, "..");
const PAGE = join(__dirname, "..", "..", "..", "app", "pixel", "page.tsx");

// Sanctioned differences (PIXEL_SPEC.md § UI): the brand string, the API base, the portal's font
// and theme plumbing, plus the shims strict TypeScript needs.
const STRING_ALLOWLIST = new Set<string>([
  "Armapunk Pixel", // brand: the h1
  "Armapunk Pixel — Altis", // brand: the <title>
  "/api/pixel/state?", // API base
  "/api/pixel/action", // API base
  "/api/pixel/gang?id=", // API base
  "latin", // page.tsx: next/font subset
  "--font-geist-sans", // page.tsx: next/font variable (the reference's own CSS variable name)
  "--font-geist-mono", // page.tsx: next/font variable (the reference's own CSS variable name)
  "swap", // page.tsx: next/font display
  "force-dynamic", // page.tsx: Next.js route segment config (the owner gate reads the session per request)
  "u", // PixelGame: `"u" < typeof ResizeObserver` (the reference's minified typeof guard, kept verbatim)
  "span", // badge.tsx: useRender defaultTagName (the recovered Badge's "span", keyed differently in the chunk)
  "badge", // badge.tsx: useRender state.slot (same)
]);

// Class strings that exist only because of the portal shell.
const CLASS_ALLOWLIST = new Set<string>([
  "pixel-theme dark", // page.tsx: the theme wrapper (reference tokens scoped to the page + its dark set)
]);

const refStrings = new Set<string>([...(referenceStrings as string[]), ...(derivedStrings as string[])]);
const refClasses = new Set<string>([...(referenceClasses as string[]), ...(derivedClasses as string[])]);

function sourceFiles(): string[] {
  const out: string[] = [];
  const visit = (dir: string) => {
    for (const name of readdirSync(dir)) {
      const p = join(dir, name);
      if (statSync(p).isDirectory()) {
        if (name !== "__tests__") visit(p);
      } else if (/\.tsx?$/.test(name)) out.push(p);
    }
  };
  visit(PIXEL);
  out.push(PAGE);
  return out.sort();
}

describe("pixel client fidelity", () => {
  const files = sourceFiles();

  it("scans the port", () => {
    expect(files.length).toBeGreaterThan(30);
    expect(refStrings.size).toBeGreaterThan(1000);
    expect(refClasses.size).toBeGreaterThan(600);
  });

  it("every string is the reference's", () => {
    const offenders: string[] = [];
    for (const f of files) {
      const { strings } = extractFromSource(readFileSync(f, "utf8"), f);
      for (const s of strings) if (!refStrings.has(s) && !STRING_ALLOWLIST.has(s)) offenders.push(`${relative(PIXEL, f)}: ${JSON.stringify(s)}`);
    }
    expect(offenders).toEqual([]);
  });

  it("every class string is the reference's", () => {
    const offenders: string[] = [];
    for (const f of files) {
      const { classes } = extractFromSource(readFileSync(f, "utf8"), f);
      for (const c of classes) if (!refClasses.has(c) && !CLASS_ALLOWLIST.has(c)) offenders.push(`${relative(PIXEL, f)}: ${JSON.stringify(c)}`);
    }
    expect(offenders).toEqual([]);
  });

  it("keeps the reference's own copy verbatim (spot checks)", () => {
    const all = new Set<string>();
    for (const f of files) for (const s of extractFromSource(readFileSync(f, "utf8"), f).strings) all.add(s);
    for (const s of ["Landing at Kavala…", "Choose your life on Altis", "Richest on Altis", "Prison workshop", "Routine checkpoint", "Claim free cash", "Work collects · processing refines"])
      expect(all.has(s), s).toBe(true);
    expect(all.has("Asylum Pixel")).toBe(false);
  });
});
