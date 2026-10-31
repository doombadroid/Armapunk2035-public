# LooneyBin UI Design — NIGHT CITY

Hand-off doc: everything learned building the NIGHT CITY UI system (shops, garages, clothing, radio
radial, phone apps, HUD). Read this before touching any dialog. Mockups: the "NIGHT CITY — LooneyBin
cyberpunk UI" artifact is the visual north star; STRONGBOX (graphite+brass) was the rejected first
direction, kept only as reference.

---

## 1. The palette (exact values — do not eyeball)

| Token | RGBA (SQF) | Hex (structured text) | Use |
|---|---|---|---|
| **void** | `{0.035, 0.051, 0.082, 1}` | `#090D15` | deepest background, glyphs on lit surfaces |
| **graphite** | `{0.118, 0.153, 0.208, 1}` | `#1E2735` | panel body, resting surfaces |
| **raised** | `{0.157, 0.196, 0.247, 1}` | `#28323F` | hover/secondary buttons, meter tracks |
| **cyan** | `{0.216, 0.910, 0.941, 1}` | `#37E8F0` | THE accent: actions, active tab underline, BUY |
| **magenta** | `{0.945, 0.239, 0.659, 1}` | `#F13DA8` | selection/focus ONLY (the "one bloom" rule) |
| **mint** | `{0.325, 0.890, 0.612, 1}` | `#53E39C` | money-positive, price plates |
| **aged gold** | — | `#C7A24E` | prices, wallet readouts (mono font) |
| **slate** | `{0.537, 0.576, 0.627, 1}` | `#8993A0` | muted labels, sub-lines, inactive tabs |
| **text** | `{0.922, 0.937, 0.957, 1}` | `#EBEFF4` | primary text |
| dim placeholder | — | `#5B6572` | search-box hint text |

Rules that survived owner review:
- **One bloom.** Magenta = the single focus element per screen (selected row badge, focus-panel clip).
  Everything else stays cyan/graphite. Two magentas on screen = wrong.
- **States are brightness, not hue.** Radial wedges & rows lerp graphite→station-color by
  `rest 0.38 / hover 0.62 / active 1.0`. Full alpha always — owner explicitly wants **100% opaque**
  surfaces, no glassy transparency.
- Semantic colors (mint=money-good, red=danger) are separate from the accent and don't count as it.

## 2. Type

| Role | Font | Notes |
|---|---|---|
| Titles | `PuristaSemibold` | ALL CAPS shop titles |
| Names/labels | `PuristaMedium` | row names, buttons |
| Sub/meta | `PuristaLight` | class-type sublines, captions |
| **Numbers/prices** | `EtelkaMonospacePro` | ALWAYS — money, load values, countdowns. Gold `#C7A24E`. |

Scale (shop dialog, pre-`NC_S`): title 0.036, wallet 0.030, tabs 0.018, row name 0.0348, row sub
0.0232, row price 0.0334, acc rows 0.0247/0.0232, detail name 0.021, plate digits 0.038.

**CT_STRUCTURED_TEXT sizes from `size`, `sizeEx` is IGNORED.** Set both to the same value anyway
(harmless, self-documenting). Text on busy backgrounds needs `shadow` or it's unreadable (radial
station labels lesson).

## 3. Visual language — "THE CLIP"

- Panels are PAA art with **sheared corner clips**: cyan clip = standard panel, **magenta clip = the
  one focus card** (e.g. weapon detail). Chrome set in `images/ui/`:
  `nc_panel.paa`, `nc_panel_focus.paa`, `nc_panel_wide.paa`, `nc_panel_tall.paa`, `nc_row.paa`,
  `nc_divider.paa` (cyan gradient rule), `nc_preview.paa`, `nc_btn_cyan.paa`, `nc_plate.paa`,
  `nc_seg.paa`.
- **Bake glow into the art.** `nc_plate.paa` has the mint glow baked in; digits render on top. There is
  no usable engine glow — don't chase one.
- Row anatomy: 4px colored left **badge** (faction/category color; magenta when selected) + name +
  slate subline + right-aligned gold mono price. Badge color per tab: cyan=weapons, olive=grenades,
  slate=gear.
- Meters (LOAD): raised track + cyan fill + `nc_seg.paa` segment overlay ON TOP of the fill.
- Buttons: cyan plate + void-dark centered label. See §5 for why they're pictures.

## 4. Layout patterns that shipped

- **List + detail:** left scroll list (~55% width), right focus card (preview inset, name, price
  plate, meta line, LOAD meter, full-width BUY), accessories panel below the card. (plbShop.hpp)
- **Category tabs:** label row + 3px cyan underline on the active tab, invisible hit buttons.
  Inactive label slate, active cyan.
- **Search bar under every scroll list** (weapon + clothing shops): graphite box, 3-4px cyan left
  edge, transparent `AP_RscEdit` on top of a dim "Search..." text ctrl that hides when non-empty.
  KeyUp → re-render list through `toLower/find` substring filter. Filter persists across tabs. NEVER
  compile user text (no injection surface). On search refresh: skip camera work + do NOT
  `ctrlSetFocus` the list — it yanks the caret out of the box every keystroke (clothing lesson).
- **Radial (radio) menu:** half-pie **bottom-left above the chat**, wedges meeting at the center —
  **no center circle, no gaps**. Selection = mouse ANGLE (whole sector is the hit zone), LMB commits.
  OFF/power is its own wedge adjacent to the last station. Icons at 0.66R centroid, ~0.23R size.
  **Custom bold glyphs beat brand logos** — logos are mud at 40px. Station colors come from
  `radioCfg.hpp AUTORADIO_RadioColor` (single source of truth). Active wedge = full-brightness color
  + void-dark glyph; resting = graphite-lerped + colored glyph.
- **Keep the player visible when it matters:** clothing shop is a compact LEFT panel because the
  try-on preview (your actual character) IS the content.
- **Whole-row hit targets:** invisible button spanning the row, `setVariable ["ridx", i]`, ButtonClick
  reads it back. Never rely on text-control clicks.

## 5. Engine gotchas (the expensive lessons — read twice)

1. **`sizeEx` is ignored on CT_STRUCTURED_TEXT** — use `size`.
2. **`animTexture*` does not render on `AP_RscButtonMenu`.** Every "picture button" (BUY) =
   `AP_RscPicture` + centered label + `AP_RscButtonInvisible` overlay for the click.
3. **Display-level Mouse EHs don't fire on `createDialog` displays.** The radial's angle picking =
   fullscreen invisible catch-button + `getMousePosition` math. Don't fight this; it's engine behavior.
4. **`ctrlCreate` bypasses dialog-class macro scaling.** The .hpp `NC_S` knob (`NCX/NCY/NCW/NCH/NCT`
   macros — author in 0-1 coords, the config parser evaluates the arithmetic) scales *declared*
   controls only. Row templates that get `ctrlCreate`'d (`AP_ShopRow*`) must carry **pre-scaled**
   sizes in their class def.
5. **`description.ext` must include `dialog\MasterHandler.h`** — it pulls all ~46 dialogs. Dropping it
   during a "cleanup" bricked every menu on the server (the b0101 catastrophe). Grep for it after any
   description.ext edit.
6. **Never reference a texture that doesn't exist.** A missing .paa = flashing missing-texture box at
   runtime, no parse error, nothing in the server RPT (client-side only). radial_rim.paa shipped as a
   reference with no file — verify `images/ui/` contents against every `ctrlSetText ".paa"` before PR.
7. **Nil-guard dynamic row builders.** `fetchCfgDetails` returns `[]` for an unknown classname;
   `_det select 1` is then nil and `nil != ""` **throws and silently aborts the whole `forEach`** —
   the armory rendered "missing tons of weapons" with zero errors server-side. Old `lbAdd`+`getText`
   renderers skipped bad classes; `ctrlCreate` renderers must guard + `diag_log` the bad class.
8. **Scrollable dynamic lists:** `AP_RscControlsGroupOneScrollbar` + rows ctrlCreate'd into it at
   `y = i * rowHeight`. Delete tracked ctrls (`AP_NC_RowCtrls`) before re-render.
9. **`disableSerialization`** at the top of every UI script that holds display/control handles.
10. **Close-time settlement:** `waitUntil { isNull (findDisplay IDD) }` then do the money/gear sync
    (saveGear, cartel remit, receipt). Never settle per-click.
11. **RESKIN ONLY when re-theming existing dialogs:** keep every `idc` and control class; change
    colors/geometry/art only. The clothing shop reskin kept 3101/3102/1000/1001/1002 and the try-on
    mechanism survived untouched. Rebuilds are for NEW surfaces (plbShop) only.
12. **CfgRemoteExec mode=1:** any server→client UI callback (`AP_fnc_renameHouseDone` etc.) must be
    whitelisted with `allowedTargets=1`, client→server actions with `allowedTargets=2`. Forgetting =
    silent no-op.
13. `ctrlSetAngle [_a, 0.5, 0.5, false]` rotates around the control center — wedges + rotated art.
14. Transitions: `ctrlSetFade` + `ctrlCommit 0.12` — snappy, no easing curves available; 0.12s reads
    as intentional, longer reads as laggy.
15. uiNamespace state convention: `AP_NC_*` (Items/Shop/BM/Discount/AddonPool/Tab/RowCtrls/AccCtrls/
    All/IsLive), display handle stored by `onLoad`. One namespace prefix per dialog family.
16. Number formatting: `AP_fnc_numberText` for money (comma groups); `toFixed` for coordinates
    (never `format` on big floats — scientific notation corrupts exports).

## 6. PAA asset pipeline

- Author PNG → `tools/make_paa.py` (`build_paa_dxt5`) → .paa into `mission/.../images/ui/`.
  (Pipeline lives in the loonybin-phone repo tools; python-lzo venv needed to DECODE existing
  LZO-compressed DXT5 mips when reverse-engineering shipped art.)
- Power-of-two dimensions. DXT5 for anything with alpha (all the chrome).
- Custom glyph icons: high-contrast white-on-transparent, designed to read at 40px.

## 7. Process that works with the owner

- **Demo commands before live wiring:** `!shopdemo` `!invdemo` `!toast` `!wep` render the dialogs with
  fake data. Build the look in the sandbox, get sign-off, THEN route the real pipeline through it
  (fn_ncShop replaced fn_weaponShopMenu's renderer but reuses its entire purchase path).
- **Expect 4–6 screenshot iterations.** Real rounds from the radial: "logos shrink", "raise above
  chat", "30% smaller", "wedges touch, kill the center circle", "100% opaque", "brighten + move power
  wedge", "re-theme colors/logos to Night City". Make EVERYTHING a knob (one `NC_S` scale define,
  color defines at file top, radii/offsets as privates up top).
- **Rejected directions stay dead:** STRONGBOX (graphite+brass) lost to NIGHT CITY. The One-UI phone
  restyle was rejected outright ("ugly af") — do not restyle the phone frame; NC accents only.
- Dialog IDD/idc allocations in use: 515300 shop (rows 515310, tabs 515350-355, search 515360/361,
  detail 51532x, acc 515340), 515500 radial (wedges 8000+, icons 8200+), 3100 clothing (list 3101,
  filter 3102, search 3110/3111), 39500 virtual shop, 100100 vehicle shop. Pick a fresh 5-digit block
  for new dialogs; grep first.

## 8. File map

| What | Where |
|---|---|
| Weapon shop dialog | `dialog/plbShop.hpp` (idd 515300) |
| Weapon shop logic | `core/shops/fn_ncShop.sqf` (open/tab/search/row/acc/buy modes) |
| Clothing dialog (reskin) | `dialog/clothing.hpp` (idd 3100) |
| Clothing populate/filter | `core/shops/fn_clothingFilter.sqf` / `fn_clothingMenu.sqf` |
| Radio radial | `core/radio/fn_radioRadial.sqf` + `radioCfg.hpp` colors |
| Row templates (ctrlCreate) | top of `plbShop.hpp` (`AP_ShopRow*`, `AP_AccRow*`) |
| Common control classes | `dialog/common.hpp` (`AP_RscEdit`, `AP_RscControlsGroupOneScrollbar`, …) |
| Master include | `dialog/MasterHandler.h` ← referenced by `description.ext` (NEVER drop) |
| NC chrome art | `images/ui/nc_*.paa`, `images/ui/radial_*.paa` |
| Demo sandbox | `core/radio/fn_plbShopDemo.sqf` (`!shopdemo`) |
| HUD (started, in progress) | see "LooneyBin HUD — Design Language" artifact |

## 9. The VISOR DOCK (bottom icon dock) + the previewer tool — ACTIVE WORK

### What it is
A **bottom macOS-style magnifying icon dock**, drawn as a translucent HUD over the live 3D game (it replaces an
older radial wheel menu opened with SHIFT+Y while the in-game goggle item is worn). It shows the player's
selected **ability icons** from their loadout, grouped into sections with thin dividers (primary / utility /
defense), each icon a glyph sitting on a dark rounded card. Sliding the cursor **magnifies** the nearest icon
(a gaussian parabola; magnified icons rise up out of the bar), a **tooltip** above names the ability + its
numbers, and clicking activates the nearest. A **target-lock card** (top-right) shows whatever the player is
aiming at when it opened. A full-screen **scanline + edge-vignette** overlay gives the "looking through a
visor" feel. It is 1:1 with the HTML mockup `scratchpad/vr_dock.html` (two palette variants: ICEBREAKER = acid
green, TAL = amber).

### The problem this solves (why the tool exists)
The engine has no CSS / flexbox / blur / rounded corners; every visual piece is a bitmap texture + a
fixed-rect control. To match the mockup we **bake each piece to a PNG→PAA** and hand-place controls. The
bottleneck was blind iteration: bake → deploy → screenshot → adjust → redeploy. So there is now a **local
previewer** that renders what the dialog will look like WITHOUT deploying.

### `scratchpad/deck_bake/dock_preview.py` (iterate here, deploy once)
Composites the REAL baked PNGs (bar, tiles, glyphs, scanline overlay, lock card) at the driver's EXACT computed
positions over a game-like background, magnification simulated → PNG.
```bash
cd ~/loonybin-doomba/scratchpad/deck_bake
python3 dock_preview.py --res 2560x1080 --pal ice --cursor 0.47   # --pal ice|tal, --cursor 0..1 (mouse x), --bg <img>, --out <png>
```
Loop: tweak `dock_preview.py` → render → eyeball → repeat → **only then** port the constants into the driver
and deploy a single time.
- **Keep its constants in sync with the driver** `core/items/fn_qhDockFill.sqf`: iconH, spacing, divGap, pad,
  magnify boost/sigma, glyph inset, rise, bar geometry, lock-card text positions. Change one, change both.
- **Fidelity needs a realistic background.** A translucent HUD reads completely differently over a dark vs a
  bright world. Preview over the ACTUAL scene brightness (bright daytime ground) or it lies: tiles that looked
  subtle over a clean bg glared over bright terrain. Cards that must read over a bright world are baked DARK
  (not white-for-tinting), else runtime tint makes them glow.

### CURRENT STATE (2026-07-22 evening — PORTED + deployed to DEV, pending in-game eyeball)
Previewer and driver are in sync. Everything below is live in `fn_qhDockFill.sqf` + baked art:
1. Bar: `barH = iconH*1.8`, `iconBottom = barBottom - barH*0.28`.
2. Dark card tile baked (`vrtile_dark.png` → `vrtile.paa`), tile NOT tinted ([1,1,1,1]); only the glyph
   carries tone and brightens with focus (`1 + boost*0.4`).
3. **macOS push-apart magnify**: each growing icon shoves every other by half its growth, away from
   itself (O(n²) over ~12, per MouseMoving). Bar + glow hug the DISPLACED row and stretch during
   magnify. Single layout codepath: `AP_fnc_vrMag` does everything; fill calls it once with a
   far-away cursor for the rest state. Dots/divider ticks follow displaced centres
   (`AP_vrDots`/`AP_vrDivs`).
4. **Baked-art halo insets** (measure with alpha>140 — the >40 soft threshold catches the fade and
   lies by ~24px): bar hard body L 0.1005 / R 0.0995 / T 0.2554; card hard body L 0.20 / B 0.20.
   Control rect = visible rect expanded by insets; without this, tiles "poke out of the bar" and text
   "escapes the card" — it is NOT layout math, it's art margins.
5. **Lock card is H-sized** (`0.289*szH*pxr` wide, right-anchored at `0.152*szH*pxr` margin): W-fraction
   sizing squeezed it 25% at 1920x1080 and text overflowed. Status line is bottom-anchored
   (`vh - 0.040*szH`). Verified in previewer at 1920x1080 / 2560x1080 / 3440x1440.
6. **Tooltip anchors to the risen tile top** (`tileTop - 0.0585*szH`), not a fixed bar offset — fixed
   offsets hid the stat line behind the magnified tile.
7. Glow: alpha 0.55, width 1.1×barW (full alpha read as a lawn strip over bright terrain).
`vr_dock.hpp` BarBg/CardBg are w=0;h=0 — the driver owns ALL chrome placement now.

### Bake pipeline (headless chrome → PAA)
```bash
CHS=~/.cache/ms-playwright/chromium_headless_shell-1217/chrome-headless-shell-linux64/chrome-headless-shell
"$CHS" --headless --disable-gpu --force-device-scale-factor=2 --window-size=WxH \
   --default-background-color=00000000 --screenshot=out.png "file://.../page.html"
python3 -c "import sys;sys.path.insert(0,'tools');import make_paa;make_paa.build_paa_dxt5('out.png','mission/.../x.paa')"
```
Measure geometry with `--dump-dom` + a script stamping `getBoundingClientRect` (harnesses in `deck_bake/`:
`vr_bake.html`, `vr_meas.html` → `*_rects.json`). Store positions as screen fractions → `safezoneX +
f*safezoneW`. White-in-PNG glyphs are tinted per tone at runtime with `ctrlSetTextColor`.

### Engine footguns for ctrlCreate'd dialogs (all bit at least once)
- `UI_GRID_*` are `.hpp` `#define`s — undefined in SQF. In a driver compute the grid: `2.5*pixelW*pixelGrid`
  (= UI_GRID_W) etc. Using the macro name in SQF → nil → NaN → all controls pile at 0,0.
- `ctrlCreate ["AP_RscPicture", idc]` throws a "No entry .../AP_RscPicture.text" WARNING POPUP per picture
  (no `text=""` default). Use `AP_RscPictureKeepAspect` (has `text=""`).
- The full-screen mouse catcher MUST be a `AP_RscButtonMenu`; a `AP_RscText` static receives no
  MouseMoving, so magnify/click never fire. Static icons drawn on top do not block the button below.
- `ctrlSetVariable`/`ctrlGetVariable` do NOT exist in this build — bake per-control data into the handler via
  `ctrlAddEventHandler ["ButtonClick", compile format ["['%1'] call fn", _id]]`.
- Icons square in pixels: `iconW = iconH*(pixelW/pixelH)`. The bar must HUG the icons (sum of widths + padding),
  never a fixed `safezoneW` fraction, or it sprawls on ultrawide.

### File map
| What | Where |
|---|---|
| Visor dock dialog | `dialog/vr_dock.hpp` (idd 941300) |
| Dock launcher / populate+magnify | `core/items/fn_qhDock.sqf` (SHIFT+Y) / `core/items/fn_qhDockFill.sqf` (onLoad) |
| Ability console app (phone, related) | `dialog/qh_console.hpp` (idd 941500) + `core/items/fn_qhConsole.sqf` |
| Baked art (bar, card, tile, glow, overlay, glyphs) | `mission/LooneyBin.Altis/images/cyberdeck/` (`vrdock_bar/card_*`, `vrtile`, `vrglow`, `vr_visor`, `qicons/`) |
| Previewer + bake harnesses | `scratchpad/deck_bake/` (`dock_preview.py`, `vr_bake.html`, `vr_meas.html`, `*_rects.json`, source PNGs) |

## 10. ICEBREAKER/TAL OS console v2 (2026-07-22, deployed DEV)
- Console previewer: `scratchpad/deck_bake/console_preview.py --pal ice|tal --state v2` — composites the
  baked `deck_ice|tal.png` chrome with simulated live overlays at the hpp cell coords (67.5 px/cell at
  2176x1350, centre 1088,675; QS cancels). Its first current-state render EXPOSED the v1 bugs (dead scope
  void, name/kind text collision, cramped switch buttons) — render composites BEFORE judging a shipped UI.
- v2 layout: NEARBY target list (4 baked row plates x[-14.756..w 8.119] y 2.230/3.681/5.133/6.585 h 1.244)
  fills the old void; kind+dist merged to one meta line under the name (941512, left-aligned; 941513 parked);
  footer strip 941530/31 (UPLINK/TRACE); slot tags baked (`.tile::after`, survives the bake's child-hiding).
- Bake source `deck_bake/deck_skel.html` (?app=ice|tal, dsf2, window 1088x675 → PAA). **Deck height is
  layout-coupled**: the scope column's min-content can silently grow the whole deck (675→685 when the rows
  were 44px) — after ANY skel edit, verify the raw PNG is exactly 2176x1350 and re-dump RECTS.
- Selection wash = 941529 AP_RscText positioned by fn_qhConsolePick (rows table `AP_qhcRows` in
  fn_qhConsole.sqf — keep in sync with the hpp). Row hit buttons are declared AFTER the row texts
  (structured text eats clicks; whole-row invisible button on top, §4 pattern).
