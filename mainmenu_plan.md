# Armapunk 2035 Main Menu — Implementation Plan

> **For agentic workers:** executed inline in the authoring session (visual pipeline; context is
> the review gate between tasks). Steps use checkbox syntax for tracking. Spec:
> `mainmenu.md` — read it first; the designer
> handoff in `menu/design/` is the visual source of truth.

**Goal:** Ship `armapunk_menu.pbo` in `@Armapunk2035` replacing RscDisplayMain with the handoff's
animated menu (video background + baked-PAA live controls).

**Architecture:** deterministic Chromium harness renders the design source → 2 Theora videos +
25 PAA overlay textures + a measured layout manifest; a config override + one SQF file drive
intro→idle switching, selection, and IDC activation. See spec.

**Tech stack:** node + playwright (pipeline only), static ffmpeg w/ libtheora, existing
`tools/make_paa.py`, armake2 via existing `radio/make_pbo.py` + `build_addon.sh`.

## Global constraints

- Never commit to `main`; branch `main-menu`, PR for owner review.
- PBO prefix MUST equal addon dir name (`armapunk_menu`).
- Generated media (.ogv/.paa/.png frames) gitignored; pipeline must regenerate everything from
  committed sources. Node modules gitignored.
- Design source `menu/design/armapunk.jsx` stays pristine — variants only via loader patches that
  assert their needle matches exactly once.
- No foreign-server references; credits per repo footer rule.

---

### Task 1: Pipeline scaffold (`menu/`)

**Files:** create `menu/design/{README.md,armapunk.jsx}` (verbatim from handoff),
`menu/harness/{index.html,stage.js,loader.js,app-extra.jsx,fonts-local.css,font_*.woff2}`,
`menu/render.mjs` (serve harness over localhost http; modes `--check`, `--bake`, `--frames`),
`menu/package.json` (playwright, react@18 UMD, @babel/standalone — classic JSX runtime),
`menu/.gitignore` (`node_modules/`, `out/`), `menu/PIPELINE.md`.

**Produces:** `node render.mjs --check` → loads page, asserts all loader patches applied, fonts
loaded via explicit `document.fonts.load()` per family, writes `out/check_t8.5.png`.

- [x] Copy proven scratchpad harness + design files; add font preloading before first capture
- [x] `cd menu && npm install && node render.mjs --check` → exits 0, PNG matches handoff look
- [x] Commit `feat(menu): deterministic render pipeline for main-menu design`

### Task 2: Bakes + layout manifest

**Files:** extend `menu/render.mjs` (`--bake`), create `menu/bake_paa.py`, generated:
`menu/out/layout.json`, `radio/addon/armapunk_menu/ui/*.paa` (25), generated layout include
`radio/addon/armapunk_menu/layout.hpp` (committed — small, reviewable).

**Bake set:** rows sel=-1 (6 dim crops), sel=k k=0..5 (6 selected, EXIT red at k=5), pulse=1
variants (6), hints sel=0..5 (6), armed prompt (1). Row crop 1024×128 centered on row (y −33 px);
hint crop 1024×64 anchored to measured hint rect. Transparent page, `omitBackground` screenshots.

**Produces:** `layout.hpp` `#define`s: per-row box (design px), hint box, video box — consumed by
config.cpp/SQF via the letterbox mapping macros.

- [x] `node render.mjs --bake` → 20 PNG shots + layout.json (row h == 62 asserted)
- [x] `python3 bake_paa.py` → 25 PAAs, each passes `make_paa.verify_paa`; layout.hpp regenerated
- [x] Commit `feat(menu): overlay texture bakes + measured layout manifest`

### Task 3: Videos

**Files:** extend `menu/render.mjs` (`--frames intro|idle`), create `menu/encode.sh` (fetches or
reuses static ffmpeg w/ libtheora, encodes `-q:v 8 -an`), outputs
`radio/addon/armapunk_menu/video/{intro.ogv,idle.ogv}`.

**Frames:** intro t=0→10 s, 30 fps, design scenes as authored. idle t=10→70 s, held variant
(`__custom=held`, `__noJitter`, `__noHint`). PNG frames → ffmpeg image2 sequence.

- [x] Render 300 + 1800 frames; assert intro frame count == 300, idle == 1800
- [x] Seam gate: RMSE(idle frame @t70 vs @t10) ≈ 0; cut gate: RMSE(intro last vs idle first,
      menu column masked) small — script prints both, fails > threshold
- [x] `ffprobe`: both streams theora, yuv420p, 1920×1080, durations 10.00 / 60.00
- [x] Commit `feat(menu): intro + seamless idle loop renders`

### Task 4: Addon config

**Files:** create `radio/addon/armapunk_menu/config.cpp` (+ `#include "layout.hpp"`).

**Skeleton:**

```cpp
class CfgPatches { class ArmapunkMenu {
    units[]={}; weapons[]={}; requiredVersion=1.0;
    requiredAddons[]={"A3_UI_F","MaldenRadio"};   // merge after vanilla UI; keep mod grouped
    author="Doomba"; name="Armapunk 2035 Main Menu";
}; };
class ArmapunkMenu {  // mod settings
    deployServer[] = {};          // {"host", port, "password"} — empty = server browser
    introEverySession = 0;        // 1 = replay intro on every menu load
};
class RscStandardDisplay;
class RscDisplayMain : RscStandardDisplay {
    onLoad = "... call compile preprocessFileLineNumbers '\armapunk_menu\menu.sqf' ...";
    class controls {  // appended controls, drawn over vanilla ones
        class AP35_Letterbox;     // ink RscText fullscreen
        class AP35_VideoIdle;     // RscVideo loops=1 autoplay=0
        class AP35_VideoIntro;    // RscVideo loops=0 autoplay=0
        class AP35_Row0..5;       // RscPicture (baked strips)
        class AP35_Hit0..5;       // transparent RscButton hitboxes
        class AP35_Hint;          // RscPicture
    };
};
```

- [x] Inherit-don't-redefine: pull vanilla `RscDisplayMain` controls untouched (external class
      declarations only); our classes appended so they z-order on top
- [x] Syntax gate: `armake2 rapify config.cpp /tmp/config.bin` exits 0 (first boot log is the
      second gate — owner playtest)
- [x] Commit `feat(menu): RscDisplayMain override config`

### Task 5: Menu logic (`radio/addon/armapunk_menu/menu.sqf`)

**State:** `_sel` 0–5, `_armed` bool; uiNamespace vars `AP35_introPlayed`, EH-installed guard.

- [x] Letterbox math once: design-px → screen mapping applied to all control positions from
      layout.hpp values (ctrlSetPosition in onLoad; config positions are placeholders)
- [x] Intro flow: first load → show intro ctrl, `ctrlSetText` intro.ogv; `VideoStopped` or
      KeyDown/click → switch (hide intro, text+show idle, show rows+hint); repeat loads → idle
      immediately. EXIT armed → hint blink loop (`ctrlSetTextColor` alpha, uiSleep 0.1 spawn)
- [x] Input: per-row button `MouseEnter` → select; `ButtonClick` → activate; display `KeyDown`
      (up/down/enter/Y/N/ESC) returning true only when consumed
- [x] Activation map per spec table incl. DEPLOY `connectToServer` branch
- [x] Review pass against `docs/` SQF footguns (params not select, no phantom else) — no local
      SQF linter exists
- [x] Commit `feat(menu): menu state machine + engine wiring`

### Task 6: Build, install, PR

- [x] `python3 radio/make_pbo.py radio/addon/armapunk_menu <dist>/addons/armapunk_menu.pbo
      armapunk_menu` from the worktree, into the MAIN checkout's existing
      `radio/dist/@Armapunk2035/addons/` (worktree lacks the gitignored radio/zee/JAS binaries —
      do NOT run full build_addon.sh there)
- [x] Verify listing: `armake2 inspect` (or unpack) shows config.cpp, menu.sqf, layout.hpp,
      2 ogv, 25 paa, correct prefix
- [x] PROVENANCE.md + mod.cpp description: fonts note (OFL, rasterized); PIPELINE.md regen doc
- [x] Push branch, open PR with owner playtest checklist (spec Testing section)
