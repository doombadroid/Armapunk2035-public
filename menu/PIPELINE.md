# Main-menu asset pipeline

Turns the designer handoff in `design/` (visual source of truth — do not edit `armapunk.jsx`)
into everything `radio/addon/armapunk_menu/` ships: two Theora videos and the overlay PAAs, plus
a measured layout include. Spec: `../mainmenu.md`. Plan: `../mainmenu_plan.md`.

## One-time setup

```bash
cd menu && npm install          # playwright, react@18 UMD, @babel/standalone
npx playwright install chromium # if the browser cache is missing
```

## Regenerate everything

```bash
node render.mjs --check          # font gate + stills (16:9 full + 21:9 background-only)
node render.mjs --bake           # 11 transparent shots + out/layout.json (16:9, scale 1)
python3 bake_paa.py              # crops -> ../radio/addon/armapunk_menu/ui/*.paa (13) + layout.hpp
node render.mjs --frames bg169   # 450 frames, 2560x1440, design's own 15 s loop, menu-less
node render.mjs --frames bg219   # 450 frames, 3440x1440
bash encode.sh                   # static ffmpeg (libtheora) -> video/bg_{169,219}.ogv + loop gates
```

## How it works

- `harness/stage.js` replaces the prototype's missing runtime: the 9 `window` globals the design
  destructures, driven by an external `__seek(t)` promise instead of rAF. Rendering is a pure
  function of `t` — `--check` renders are byte-identical across browser launches.
- `harness/loader.js` fetches the pristine design source and applies load-time patches, each
  asserting its needle occurs exactly once (edit drift fails loudly). v2 design has native
  background-only/aspect/res modes, so only the hint-bake chrome-off patches remain.
- `harness/app-extra.jsx` adds the transparent bake stages and measures control rects so engine
  layout is generated, never hand-copied. Variant selection (BG_ONLY, aspect, res) is injected
  per pass via `window.__HARNESS_CFG` before page load.
- Fonts are the OFL woff2s committed beside the harness; every face is force-loaded before the
  first capture (`document.fonts.ready` alone lies for lazily-used faces).
