# MALDEN GRID v2 — 3D tactical map. Design brief

Design the full-screen 3D map for a cyberpunk Arma 3 roleplay server.
Self-contained; you do not need the repo. **Every constant and payload below
was measured out of the running game, not imagined** — where this brief and
your instincts disagree, this brief is the game.

A working 2D version already ships (pan/zoom sat tiles, group blips, markers).
You are replacing its rendering, not its data model. The data model is law.

---

## 1. What this screen is

The island of Malden (12 800 × 12 800 m) as a **tilting, panning, rotating 3D
terrain** — real topology, the game's own satellite imagery draped over it,
and live blips for you, your squad, and the world's markers. Vehicle blips
carry **vehicle-type icons**. It opens full-screen from the phone, and it is
read-only: nothing on it decides anything.

Fiction: military-grade AR terrain feed, NIGHT CITY palette. The existing
phone/casino design language applies — same tokens, mono/sans split:

```css
--scr:#050b09  --panel:#0c1712  --acc:#c9e21a  --acc2:#33ffbb  --danger:#ff5a3c
--amber:#ffb020  --magenta:#ff3d81  --ink:#dcefe0  --dim:#7f938a  --faint:#465a51
--line:rgba(201,226,26,.15)
--mono: ui-monospace,'JetBrains Mono','SF Mono',Menlo,Consolas,monospace
```

---

## 2. Hard constraints — measured, not assumed

- **No libraries, no network, no storage.** No `<script src>`, no CDN, no
  fetch/XHR, no localStorage. three.js cannot be linked and must not be
  inlined; write raw WebGL. All assets come from the two game APIs below.
- **ASSUME SOFTWARE WebGL.** The host renders web views on the CPU
  (SwiftShader-class). Canvas 2D sustains 60 fps full-screen; shader cost is
  what kills. Budget accordingly:
  - one terrain mesh, **≤ 256×256 grid visible**, single draw call if you can
  - satellite tiles in as few atlas textures as practical
  - blips/labels as a 2D canvas overlay ON TOP of the GL canvas — text in GL
    on a software rasterizer is a waste of everyone's frame
  - **idle = still.** rAF runs during interaction and for ~1s after a data
    push, then stops. This is the house rule every shipped screen obeys.
  - target 30 fps during camera motion, on the assumption of software raster.
- **Viewport**: full-screen dialog, `devicePixelRatio` 1. Esc closes (the
  game does it; no page handler needed).
- **The mandatory head block**: keep the `WEBUIReady` promise +
  `A3API.RequestFile("webui\\ui\\webui.js")` self-boot exactly as the current
  map.html has it. A page without it renders and is deaf.

---

## 3. Terrain data — where the 3D comes from

### Heightfield
Delivered as a baked text asset in the mission, loaded via
`A3API.RequestFile("ui\\html\\malden_hf.txt")` (returns the file as a string).

Format, line 1 is meta, then one row per line, north row first:

```
# size cellMeters minH maxH
200 64 -5.0 261.0
h,h,h,...   (size values per row, size rows, metres ASL, plain floats)
```

Parse defensively: `size` may be anything 100–512; render whatever arrives.
Sea level is 0 — everything ≤ 0 renders as water (flat, its own treatment;
the cyberpunk move is a dark plane with a faint grid, not simulated waves).

### Satellite imagery
The game ships Malden's sat layer as a **13 × 13 grid** of tiles:

```
A3API.RequestTexture("a3\\map_malden\\data\\layers\\s_XXX_YYY_lco.paa", maxSize)
```

- `XXX` = column 000–012 (west→east), `YYY` = row 000–012 (north→south)
- returns a data-url; `maxSize` picks the mip: request **128 zoomed out,
  256/512 as the camera closes in**; convert lazily, ≤ 6 in flight, cache
  every resolution, draw a worse mip while a better one converts
- tile geometry (already calibrated in the 2D map — copy these as named
  constants with the same names):
  - `SPAN = 12800/13` m per tile step
  - `OV_PX = 16` — tiles overlap 16 px per edge (Terrain Builder convention);
    metres per tile pixel `K = SPAN/(TILE_PX − 2·OV_PX)`, `TILE_PX = 512`
  - `ROW0_NORTH = true`, `SWAP_XY = false` — leave the flags in place;
    they are the calibration story if the island ever mirrors

World → texture mapping: world (0,0) is the **south-west** corner; world Y
grows north; tile row 0 is the **north** edge.

### Buildings — the island's actual structures, dumbed down

Every building on the island renders as a **simplified extruded footprint** —
an oriented box (or box + roof-hint prism if it stays cheap), never the real
model. The data is a baked text asset, same delivery as the heightfield:

`A3API.RequestFile("ui\\html\\malden_bld.txt")`

```
# count
x,y,dir,sx,sy,sz,kind     (one per building)
```

- `x,y` world centre, `dir` degrees clockwise from north, `sx,sy` footprint
  metres, `sz` height metres — extracted from each object's real bounding box,
  so the mission's custom skyscrapers arrive automatically tall
- `kind`: 0 generic · 1 industrial · 2 military · 3 church/landmark ·
  4 custom/neon (the mission's own towers — give these the acid/cyan
  treatment; they are the skyline and the fiction)
- base altitude is NOT in the file — sit every box on your heightfield,
  exactly like blips

Expect **3 000–6 000 rows**. Parse the count from line 1 and render whatever
arrives. Budget rules on software raster:

- zoomed out: buildings OFF entirely (below a zoom threshold they are noise)
- mid: flat tinted footprints, no extrusion
- close: extruded boxes, frustum-culled, **≤ ~800 drawn**, one instanced /
  batched draw — never a draw call per building
- night (`env.hour`): sparse emissive window dots on kind 4 and a faint rim
  on the rest is the whole flourish; skip it if it costs a frame

---

## 4. Camera

- **Pan**: drag. **Zoom**: wheel, toward the cursor. **Tilt + rotate**:
  right-drag or CTRL-drag — tilt 0° (top-down) to ~70°, free yaw.
- Top-down at minimum tilt must read exactly like the 2D map — this screen
  replaces it, so straight-down is a first-class state, not an afterthought.
- `◎` button: fly to the player, sensible tilt. `N` indicator that is also a
  button: reset yaw to north-up. `2D/3D` toggle is welcome but optional.
- Clamp the camera to the island + a margin; never under the terrain.
- A click that is not a drag reports world coordinates in the header readout
  (a later screen turns that into a taxi destination — emit it, don't use it).

---

## 5. Live data — the bridge, and the one rule

```js
AP.on("map",       d => ...)   // 1 Hz while open
AP.on("mapStatic", d => ...)   // at open + every 15 s
```

`map`:

```js
{ self:  { x, y, dir, name, veh:"none"|"car"|"truck"|"air"|"heli"|"boat" },
  group: [{ name, x, y, alive, leader,
            veh:"none"|"car"|"truck"|"air"|"heli"|"boat",
            crew: 3 }],            // ≥2 means stacked blip: one vehicle, n heads
  env:   { hour: 22.4, overcast: 0.3 } }
```

`mapStatic`:

```js
{ markers: [{ x, y, text, type, color:"ColorRed"|..., alpha }] }
```

- Heights are NOT in the live payload — you have the heightfield; sit every
  blip on the terrain yourself.
- `env.hour` is in-game time. Light the terrain with it: noon flat, dusk warm,
  night dark with the acid/cyan blips carrying the scene. This is the flourish
  that makes it feel like a feed rather than a screenshot.
- Marker colors arrive as engine names; map them to the palette (table in the
  current map.html — reuse it).

**THE ESP RULE.** The payload contains you, your group, and markers your own
settings already show. It will never contain other players. Do not design UI
that implies otherwise (no "contacts" layer, no enemy pings) — a slot that
exists will eventually get filled, and this one must not be.

### Vehicle-type icons

Own glyph per `veh` value, plus on-foot. Stroke-style SVG/canvas glyphs in the
established two-layer language (body + accent), ~14 px at default zoom, always
screen-facing (billboarded), scale-clamped so they never vanish or balloon.
`crew ≥ 2` renders one vehicle glyph with a count chip, not n overlapping
blips. Dead group members: the existing grey treatment.

---

## 6. What the screen must answer, in order

1. Where am I, which way am I facing, what's the terrain around me
2. Where is my squad, alive or not, on foot or in what kind of vehicle
3. Where are the world's marked places (the player's own marker settings)
4. What did I just click (coordinates readout)

Chrome: header (title, zoom/scale readout, coords), a status strip for hints,
the zoom/center/north controls. Everything else is map.

---

## 7. Deliverables

- One self-contained `map.html` — inline CSS/JS, the head block preserved,
  raw WebGL + 2D overlay canvas
- An `AP` stub behind a `typeof AP === "undefined"` guard with mock data:
  synthetic heightfield (sine hills), flat-color placeholder tiles, a fake
  squad of 3 (one in a heli, one dead), ~20 markers, a mock building file
  (~200 boxes, a few kind-4 towers), `hour` cycling — so the page reviews
  standalone in a browser
- A note: what animates, what the idle state costs (the answer must be
  "nothing"), and the terrain grid size you settled on for software raster

## 8. Do not

- link or inline any library, font, or external asset
- run rAF while idle, ever
- exceed the terrain/texture/building budget on the assumption of hardware GL
- draw buildings below the zoom threshold, or one draw call per building
- put text in the GL canvas — labels live on the 2D overlay
- invent data fields, an enemy layer, or any position not in the payload
- decide anything — the map is read-only; the click emits coords and stops
