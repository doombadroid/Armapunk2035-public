# Armapunk 2035 Main Menu — Design Spec

**Source of truth:** designer handoff bundle (`menu/design/` — README.md + armapunk.jsx, committed
verbatim). This spec records only the *implementation architecture* and the deliberate deviations.
Everything visual (palette, layout px, copy, timing) lives in the handoff and is final.

## Goal

Replace Arma 3's `RscDisplayMain` with the handoff's animated cyberpunk menu: CRT boot → logo
reveal → menu build with live darknet feed, then a **held, fully interactive** menu. Handoff
approach **A** (video background + real controls), which the README recommends.

## Architecture

Two Theora videos rendered from the design source itself (headless Chromium harness replaces the
prototype runtime with a deterministic seek clock), plus engine-side overlay controls whose
textures are **baked from the same renderer**, so the video→overlay handoff is pixel-continuous.

1. **`intro.ogv`** — design timeline t = 0→10 s exactly as authored (boot, logo, menu type-in,
   selector lands on DEPLOY). Plays once per game session (`uiNamespace` flag), any key/click
   skips. `RscVideo` control, `loops = 0`; `VideoStopped` EH triggers the switch.
2. **`idle.ogv`** — t = 10→70 s of a "held" variant: background, logo, feed, coords, bottom bar —
   **no menu rows, no selector, no hint** (those become engine controls). 60 s seamless loop,
   `loops = 1`. The design's global clock keeps grid/rain/feed/GRID-clock phase continuous across
   the intro→idle cut, and the loop period is engineered so frame(70) == frame(10).
3. **Overlay controls** — per menu row one `RscPicture` (texture = baked PAA row strip; states:
   dim / selected / selected-pulse, EXIT selected renders red) + one transparent `RscButton`
   hitbox. Bottom-bar hint = one `RscPicture` swapping 7 baked hint strips (6 hints + red
   `EXIT? [Y/N] █` prompt, blink via picture alpha). Row strips are 1024×128 (row ±33 px glow
   padding), hints 1024×64 — power-of-two as PAA requires. Control rects come from a generated
   layout manifest measured in the bake pages — no hand-copied coordinates.
4. **Letterboxed 16:9 stage.** All coordinates map the 1920×1080 design canvas into the largest
   16:9 box inside the safezone; ink (`#050302`) bars fill the rest (matters on the 16:10 laptop
   panel). Baked video + overlays share the same box math, defined once in SQF.

## Interaction wiring (engine IDCs read from a live derap of ui_f RscDisplayMain)

| Item | Action |
|---|---|
| DEPLOY | `connectToServer` if a target is configured (config `ArmapunkMenu >> deployServer`, profileNamespace `AP35_deployServer` overrides); else falls through to server browser (ctrl 105) |
| ARSENAL | `ctrlActivate` IDC 203 (Bootcamp group → Arsenal) |
| MULTIPLAYER | `ctrlActivate` IDC 105 (server browser) |
| EDITOR | `ctrlActivate` IDC 142 |
| OPTIONS | `ctrlActivate` IDC 301 (video options — no unified options display exists) |
| EXIT | red armed state + `EXIT? [Y/N]` prompt (design), Y → `ctrlActivate` IDC 106 |

Selection: one index 0–5; mouse hover (button `MouseEnter`) and ↑/↓ arrows; ENTER activates;
ESC/N disarms EXIT. Original engine controls remain in the display underneath the full-screen
video (which blocks stray clicks); we activate them by IDC.

## Deliberate deviations from the handoff (all invisible-by-construction)

1. Five constants nudged ≤1.3 % so every background animation's period divides 60 s (seamless
   idle loop): feed 3.4 → 10/3 lines/s; grid crawl 44 → 44.4 px/s; CRT band 120 → 125 px/s; rain
   speeds quantized to multiples of 23 px/s; logo breathe 2.1 → 2π·21/60 rad/s. Applied to *both*
   videos so the 10 s cut stays continuous.
2. Idle-loop glitch bursts keep the color slivers but drop the ±12 px frame jitter — engine
   overlays can't jitter with the video, and a shearing background under static labels reads as a
   bug, not a glitch.
3. The 15 s attract loop's selector sweep + CRT collapse is **not** shown in the live menu (it
   would fight the user's own selection). The handoff itself specifies the live layer holds
   selection; attract-after-idle is listed there as optional — deferred.
4. Menu labels/hints switch from Theora-soft (video) to PAA-crisp at the 10 s cut; same renderer,
   same pixels, slight sharpen only.
5. If the user returns to the main menu mid-session the intro is skipped (straight to idle) —
   replaying a 10 s boot every time you leave a server punishes the player.

## Assets & licensing

- Michroma + Space Mono (Google Fonts, OFL) are bundled **only as rasterized pixels** inside the
  videos/PAAs; the woff2 files live in the pipeline for reproducibility. PROVENANCE.md gains an
  entry. No engine fonts needed — every glyph the menu shows is baked.
- New PBO `armapunk_menu` in the existing multi-PBO client mod `@Armapunk2035`
  (`radio/addon/armapunk_menu/`, prefix == dir name, built by the existing `build_addon.sh`
  loop, signed by `sign_addon.sh`). `requiredAddons[] = {"A3_UI_F"}` so our RscDisplayMain
  override merges after the vanilla one.
- Generated media (.ogv, .paa) stays gitignored like the other addon binaries; the committed
  pipeline (`menu/`) regenerates them from the committed design source.

## Testing

Pipeline gates are scripted (patch-needle asserts, ffprobe codec/duration, loop-seam and
cut-continuity RMSE, PAA structural verify, PBO content listing). In-game acceptance is the
owner's playtest, same as the radio mod: boot loop plays, skip works, hover/keys/click all six
items, EXIT confirm, return-from-MP shows idle immediately, 16:10 letterboxing, no engine UI
bleed-through.


## v2 revision (2026-08-04, designer handoff 2)

Design revision supersedes parts of the above: palette pink/blue
(`#ff2a6d`/`#05d9e8`), menu reduced to THREE items (DEPLOY / OPTIONS / EXIT),
all copy Altis→Malden, and the shipped video is now the designer's
**background-only master** (`ARMAPUNK_BG_ONLY`) — the full 15 s attract loop
with menu text, selector and hint removed at the source. The intro/idle
two-video machinery and the 60 s loop periodicity patches are deleted: the
design's own CRT-collapse→boot seam is the loop, and the three live rows +
hint overlay it permanently (handoff A.3).

Aspect variants: the design is edge-pinned (logo/menu left, feed/coords
right, bar full-width) on a 1080-high canvas, width 1920 (16:9) or 2580
(21:9). The mod ships one 1440p Theora loop per aspect (2560×1440 /
3440×1440) and menu.sqf picks whichever aspect is nearest the screen at
boot, letterboxing the remainder (16:10 laptop → 16:9 master). Overlay
geometry is left-anchored design px, valid for both canvases; only the
canvas width changes in the letterbox math.

Bootstrap lessons (v1 debugging, RPT-proven): parentless config re-declares
strip the base class; display/control EHs fire before the intro mission and
their spawns die in the mission-start scheduler wipe; the only reliable
bootstrap is the CfgFunctions preInit watcher, with menu.sqf marking its own
successful entry as the retry guard.


## v3 flow (2026-08-04, owner feedback)

In-game field results forced two changes on top of v2: (1) the engine's
`loops = 1` does NOT restart a script-assigned video — the menu froze on the
last frame after one pass; every loop restart is now script-driven
(`VideoStopped` re-arms the texture). (2) The owner wants the menu to hold
on the lit logo, not replay the boot attract cycle — so the intro/held-loop
architecture returns, built on the v2 design: per aspect, a 10 s
background-only intro (once per session, skippable) cuts into a 60 s
engineered held loop (periodicity nudges reinstated; grid/rain/feed/clock
phase-continuous across the cut). The loop's restart gap and the intro→loop
switch both hide inside a glitch burst baked at the seam (design's own
glitch language). Live rows/hint fade in on the design's type-in timing
(6.35 + 0.18i / bar at 7.7 s / selector pulse at 8.2 s), since baked type-in
would put menu text back into the video the designer explicitly de-texted.
