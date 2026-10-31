# PAA INDEX — what HTML can own, and what it can never own

Generated 2026-08-14 against `feat/staff-deck` (b0546). Method: every `.paa` in the
mission matched against every `.sqf` / `.hpp` / `.ext` / `.sqm` / `.html` / `.js`
in the mission **and** the server addon, classified not by where the file lives but
by **how the reference site uses it** — that is the only signal that says whether a
browser could ever draw it.

**712 files · 94.6 MB.**

## The ceiling

"Near zero" has a floor, and it is not a small one. Three families cannot move to
HTML at any price, because the engine draws them and a browser surface is not in
that path:

| family | why it is stuck | weight |
|---|---|---|
| **World textures** — `setObjectTexture`, `hiddenSelectionsTextures`, anything named in `mission.sqm` | painted onto model faces by the renderer; a CT_WEBBROWSER draws into a dialog, never onto a p3d | **6.2 MB** |
| **Holo-ad rotation** (`images/ads`, 21 files) | applied to billboard objects in the world by `format[]`-built paths | **20.0 MB** |
| **Engine chrome** — loadscreen, splash, overview | read by the engine before any mission script runs | ~0.3 MB |

`images/loonazon_van.paa` was 5.33 MB and, while it existed, was the largest single
world-texture holdout (a vehicle skin, so it could never move to HTML at any price).
**Removed 2026-09-02** along with the rest of the Loonazon feature, together with
`images/loonazon_logo.paa`, `images/loonazon_rule.paa` and
`images/browser_bg_port_loonazon.paa` — four `.paa` gone, not converted. The byte
totals and directory table below still date to 2026-08-14 and have not been
re-run since.

## What HTML can own

Everything below is UI art: a texture some dialog or page puts on screen. Every one
of these is replaceable by CSS, an inline SVG, or a data-URI — the phone proved the
pattern, and the deck already draws its entire launcher in SVG glyphs.

| directory | files | MB | reference sites |
|---|---:|---:|---|
| `images/cyberdeck` | 48 | 33.36 | unreferenced:22, dialog:20, sqf-ui:8 |
| `images` | 28 | 21.84 | other:22, dialog:11, world:6 |
| `images/ads` | 21 | 20.00 | unreferenced:21 |
| `images/casino` | 84 | 4.65 | html:51, other:48, dialog:31 |
| `images/ui` | 27 | 3.42 | other:15, dialog:15, sqf-ui:5 |
| `images/wallpapers` | 1 | 2.67 | other:1 |
| `images/cyberdeck/qicons` | 28 | 2.34 | other:26, html:18, sqf-ui:5 |
| `icons` | 253 | 1.69 | other:250, world:26, html:24 |
| `images/suites` | 1 | 1.33 | other:1 |
| `images/cyberdeck/icons` | 60 | 1.32 | other:60, html:16, dialog:11 |
| `images/spraycan` | 22 | 0.82 | other:22 |
| `icons/grphex` | 68 | 0.36 | other:68, html:11, dialog:6 |
| `.` | 6 | 0.34 | unreferenced:6 |
| `images/radio` | 7 | 0.18 | other:5, dialog:2, sqf-ui:1 |
| `images/spectate` | 11 | 0.13 | other:11 |
| `icons/capture` | 9 | 0.10 | other:9 |
| `outlw_magRepack/Images` | 2 | 0.05 | dialog:2 |
| `images/utils` | 1 | 0.03 | dialog:1, other:1, world:1 |
| `outlw_magRepack/Images/bulletCount` | 31 | 0.01 | dialog:31, html:31, other:31 |
| `IgiLoad/images` | 4 | 0.00 | other:4, dialog:1, engine:1 |

### Reading that table

- **`images/cyberdeck` — 33.4 MB, and NOT free.** Nine 2.67 MB backdrops
  (`backdrop*.paa`, `deck_ice`, `deck_tal`, `vr_visor`) plus ring art. Corrected
  2026-08-14 after trying to delete them: these back the BREACH MINIGAMES, not the
  loadout screens. `AP_fnc_cyberdeckSeq` is called from nine gameplay sites
  (lockpick, ATM, safe, gate, prison gate, jewelry, ignition, cuff hack, Loony Bin)
  and `AP_fnc_cyberdeckTerm` from five (fed, bank, vault, jewelry, Loony Bin). The
  deck's HTML ICEBREAKER/TAL views replaced the CONSOLE and the LOADOUT, never the
  minigames. Freeing this 33 MB means porting timing-and-interaction gameplay to
  HTML — a feature project, not a sweep.
- **`images` root — 21.8 MB.** The two handset frames (5.3 MB) plus seven
  `browser_bg_port_*.paa` at 1.33 MB each: baked backdrops for the in-fiction
  browser, which is a web page rendering job if anything ever was.
- **`images/casino` — 4.65 MB, half already HTML-consumed.** 51 of 84 are fetched by
  the casino pages through `WEBUI.texture`. Card faces are real art worth keeping as
  textures; the panel chrome around them is not.
- **`icons` — 253 files, 1.69 MB.** Long tail, low weight. Item and shop icons that
  the HTML shops fetch via `AP.texture`. Cheap to keep, cheap to convert, not where
  the megabytes are.

## Honest totals

| | files | MB |
|---|---:|---:|
| stuck with the engine | ~110 | **26.5** |
| convertible UI art | ~600 | **68.1** |
| of which already fetched by an HTML page | 89 | 5.8 |

So the realistic floor is **~26 MB**, not zero — and the fastest 55 MB is three jobs:
the cyberdeck screens, the browser backdrops, and the handset frames, all of which
are baked images of things CSS draws natively.

## Order of attack

1. **Cyberdeck backdrops (33 MB) — port the breach minigames.** Sequence and
   terminal are live gameplay with fourteen call sites between them. The HTML
   versions do not exist; the console and loadout ones do, and those are a
   different screen. Biggest prize, biggest job.
2. **Browser backdrops (9 MB) — port the LoonyNet browser.** Still wired from
   initPlayerLocal, fn_browserSites and fn_loonerReceive, so the dialog is live.
   It is the one screen that is literally a web page and is currently seven baked
   1.33 MB images.
3. **Handset frames (5.3 MB).** Blocked on the last native chassis users — the
   casino tables, group/gang-invite, tutorial, call overlay, govLaw, ring loadout.
4. **Casino chrome (~2 MB).** Falls out with the native-tables escape hatch.
5. **The `format[]`-built directories (29.9 MB).** Needs a human pass, not a scan:
   a name-match cannot see a path built at runtime, and this is exactly where a scan
   once tried to delete 2.1 MB of live card art.

## Correction, 2026-08-14

An earlier draft of this file said 22 cyberdeck files were "referenced by nothing".
That was a counting artifact — a per-KIND tally read as a per-FILE one. Re-checked
against every reference site: **there are now zero unreferenced PAAs in the mission.**
The 36 genuine orphans were deleted earlier the same day, and what remains is all
drawn by something live.

Which makes the honest position simple: no further PAA can be deleted by sweeping.
Every megabyte from here is bought by porting a screen, and each item above names
the screen and what still opens it.

## The rule this index exists to enforce

A PAA is deletable when **no reference site draws it**, not when no filename matches.
Runtime-built paths (`format ["images\ads\holo_%1_f%2.paa", id, frame]`) are
invisible to a name scan, so any sweep protects those directories wholesale and a
human reads them.
