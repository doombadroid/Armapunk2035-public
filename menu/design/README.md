# Handoff: Armapunk 2035 Main Menu (Arma 3 mod)

## Overview
Animated main-menu screen for **Armapunk 2035** ("By Doomba"), a cyberpunk-styled Arma 3 modded game mode. A 15-second seamless loop: CRT boot log → neon logo reveal → menu build with live "darknet" feed → selector sweep ending on EXIT → CRT power-down that loops back into boot.

## About the Design Files
The files in this bundle are **design references created in HTML** — a working prototype showing the intended look, motion, and timing. They are NOT production code. The task is to **recreate this design as an Arma 3 mod**: engine UI configs (`config.cpp` display classes), SQF scripting, `.paa` textures, and/or an `.ogv` background video. Open `Armapunk Menu.dc.html` in a browser to watch the loop (the `.jsx` files are its runtime — keep them next to it).

## Fidelity
**High-fidelity.** Colors, typography, layout coordinates, copy, and animation timing are final. Recreate as closely as the engine allows; where Arma can't match (per-pixel scanlines, chromatic aberration), the video-background approach below preserves them exactly.

## Recommended Arma architecture
Two viable approaches — **A is recommended**:

**A. Video background + real controls (hybrid)**
1. Export the animation as video (the designer can supply an MP4/WebM render; the HTML also exports directly). Convert to Theora for Arma:
   `ffmpeg -i armapunk_menu.mp4 -c:v libtheora -q:v 8 -an armapunk_menu.ogv`
2. Override `RscDisplayMain` (via `CfgPatches` + `class RscDisplayMain` in `config.cpp`). In `onLoad`, play the `.ogv` full-screen behind the controls (e.g. `BIS_fnc_playVideo` on a background control layer, looped by replaying on the `videoStopped` event, or a scripted `ctrlSetText` on an `RscVideo`-style picture control).
3. Render the three menu items as real `RscButton`/`RscActiveText` controls positioned over the video (coordinates below) so they're clickable, with SQF hover states matching the "selected" style. **Use `Armapunk Menu Background.dc.html` as the video master for this** — it is the same loop with the menu items, selector sweep, and bottom-bar hint removed, so the live controls don't duplicate baked-in text.

**B. Pure engine recreation**
Bake the skyline/grid/rain as layered `.paa` textures (exportable from the HTML on request), animate with per-frame SQF (`ctrlSetPosition`/`ctrlSetTextColor` + `ctrlCommit 0` in an `onEachFrame` loop, text typing via `ctrlSetText` with substring). More work; only worth it if video playback in the main display proves unreliable.

**Fonts:** Michroma and Space Mono are not in Arma. Either convert/bundle them as Arma bitmap fonts, or substitute built-ins: `PuristaMedium`/`PuristaSemibold` for display text, `EtelkaMonospacePro` for terminal text. If using the video approach, only the three interactive menu labels need an engine font.

## Design tokens
- Ink (background base): `#050302`
- Neon pink (primary): `#ff2a6d` — logo, selection, hints, horizon line
- Neon blue (secondary): `#05d9e8` — terminal text, grid, panel, "2035" outline
- (Where this README says "amber"/"teal" for an element, read primary/secondary — every neon color derives from this two-color palette.)
- Alert red: `#ff5544` — EXIT armed state, antenna beacons, errors
- Warm white (logo fill): mix of primary 26% into `#fff8ea`; body dim text `rgba(255,236,208,0.5)`
- Display font: Michroma (400 only). Terminal font: Space Mono (400).
- Canvas: authored at 1080 design height; width 1920 (16:9) or 2580 (21:9), rendered at up to 4K via the Resolution tweak. Coordinates below are design px (left/right-anchored as noted). Glow: text-shadow blooms of the element's own neon color.

## Layout (1920×1080 coordinates)
- **Logo block** at x140, y200: overline `// THE FUTURE IS ALREADY BROKEN` (mono 19px, letter-spacing 5, teal); `ARMAPUNK` (Michroma 116px, warm white, amber bloom); row: `2035` (Michroma 108px, transparent fill, 2.5px teal stroke) + chip `BY DOOMBA` (mono 20px, ls 7, amber text, 1px amber border, amber 8% fill, padding 9×18); 640×2px amber rule below.
- **Menu list** at x140, y512; 3 rows, 62px tall: 5×34 selection bar, index `01`–`03` (mono 17px teal), label (Michroma 29px, ls 5). Items: DEPLOY, OPTIONS, EXIT. Selected: bar + label amber w/ glow, `<<` marker, +16px x-offset; others 50% dim. EXIT selected = red instead of amber.
- **Net feed panel**: right 120, top 200, w560: header strip `NET_FEED // doomba.sys` (teal 12% fill, blinking dot), 13 visible rows (mono 17px, 30px line-height) scrolling at 3.4 lines/s, footer `SIGNAL // relay.malden-04` + 14-bar equalizer. Line colors by prefix: [NET] teal, [SYS] dim white, [WRN]/[TRD] amber.
- **Coords line**: right 122, top 152 — `GRID 034071 // MALDEN // 03:12:SS` (SS ticks each second).
- **Bottom bar**: full-width, 58px, amber 27% top border, `rgba(8,5,3,0.78)` fill: build string left (`ARMAPUNK 2035 // BUILD 0.9.7-BETA`), amber selection hint center, `UPLINK ▮▮▮▮▮ 47 OPERATORS ONLINE` right (teal).
- **Persistent background**: sky gradient (near-black → warm `#160b05` at horizon y620); amber horizon glow + 2px horizon line; two skyline silhouette layers (`#150c07` far w/ teal sign rects, `#0a0504` near w/ faint amber window rows, red blinking antenna tips); perspective grid floor below y622 (teal 2px lines, 92px columns / 74px rows, crawling downward 44px/s); 26 teal rain streaks (rotate 9°, 900–1400px/s); corner HUD brackets inset 26px; CRT overlays: 2px scanlines, drifting bright band, vignette, 12Hz ambient flicker (0.88–1.0).
- Hint copy per item: `> JACK INTO THE MALDEN DARKNET` / `> RECALIBRATE NEURAL LINK` / `> RETURN TO MEATSPACE`.

## Animation timeline (15s loop)
1. **Boot 0–3s**: screen at 15% power; 21-line BIOS log types in from x130,y110 (mono 21px, ~1 line/70ms, `> ` prefix, teal; MISSING line red) incl. animated 14-block progress bar (0.5s). Full boot copy is in `armapunk.jsx` (`BOOT` array — includes cba_a3/ace_cyberware/doomba .pbo jokes). 2.05–2.8s: background powers up (amber flash peak 12%), log wipes upward.
2. **Logo 3–6s**: overline types (0.12–0.72); ARMAPUNK neon-flickers on (0.55–1.7, with RGB-split ghosting mid-flicker); 2035 flickers (1.15–2.1); chip slides up (2.0–2.4); rule sweeps (2.25–2.75).
3. **Menu 6–10s**: items type in staggered (start 0.35 + 0.18i, 0.32s each, block cursor while typing, slide from −30px); feed panel slides from right (+90px, 0.5–1.0); bottom bar rises (1.5–2.0); coords fade (1.7); selector lands on DEPLOY at 2.2 with a glow pulse.
4. **Idle 10–15s**: selector steps down one item per 0.55s with a decaying glow pulse; at EXIT (t≈12.2) hint becomes blinking red `EXIT? [Y/N] █`; 14.1–14.6 glitch burst; 14.25–14.75 CRT collapse (vertical squash to a bright center line, flash, power drops to 15%) → seamless loop to Boot.
- Glitch language throughout: sparse bursts (~7Hz gate) = full-width 2–12px amber/teal screen-blend slivers + ±12px horizontal frame jitter, amplitude-scaled, forced to zero at scene boundaries.
- Easing: cubic-out for entrances; neon turn-on is a stuttered flicker (see `MOTION` in `armapunk.jsx`).

## State & interaction (for the live menu layer)
- One selection index (0–2), driven by mouse hover and/or arrow keys; ENTER activates.
- Selected-item hint text swaps in the bottom bar; EXIT uses the red armed style + confirm prompt before `endMission`/quit flow.
- Attract behavior (optional): after N idle seconds, resume the selector-sweep video loop.

## Assets
- No external images — everything is CSS/JS-drawn, so any raster the mod needs (skyline layer, grid, logo lockup as `.paa`) can be exported from this HTML at native resolution on request.
- Fonts: Google Fonts — Michroma, Space Mono (OFL-licensed, bundleable).
- Video master: export from the HTML (host "Export → Video"), 15s loop, then transcode to `.ogv` as above. The Tweaks panel has **Aspect** (16:9 / 21:9) and **Resolution** (1080p / 1440p / 4K) controls — e.g. 16:9→2560×1440, 21:9→3440×1440. Export one video per aspect ratio the mod ships; left/right UI stays edge-pinned, background extends.

## Files
- `Armapunk Menu.dc.html` — the full design (open in a browser; needs the three .jsx files beside it).
- `Armapunk Menu Background.dc.html` — no-menu-text variant for the video-background approach (same loop; menu items, selector, and hint hidden — export video from this one).
- `armapunk.jsx` — all layout, copy, palette, and timing constants (the source of truth: `BOOT`, `FEED`, `MENU`, `HINTS` arrays; `MOTION` easing; scene components).
- `animations-v2.jsx`, `tweaks-panel.jsx` — prototype runtime, not part of the design spec.
