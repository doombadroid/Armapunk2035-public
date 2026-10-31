# LooneyBin Phone Redesign — Samsung One UI

Design mockups for a reworked in-game phone. **These are mockups (SVG → PNG), not yet in-game.**

## Render
```
python3 design/phone/phonegen2.py     # writes /tmp/phone/oneui_*.png  (needs rsvg-convert)
```
`phonegen2.py` reuses the icon glyphs + app list from `phonegen.py`.

## Screens (`renders/`)
- **oneui_home** — clock widget (= in-game map time), 4-wide squircle app grid, dock, page dots.
- **oneui_drawer** — full app drawer (feature parity with `AP_phone_buttons`, paged).
- **oneui_settings** / **oneui_settings_dark** — One UI cards + toggles, with a working **Dark mode** toggle (ships both light + dark themes).
- **oneui_wallpaper** — wallpaper picker (Galaxy / Aurora / Sunset / Mint / Mono / Midnight).

## Status bar
- Left: **server-restart countdown** (e.g. `23m`) instead of a clock.
- Right: signal bars · **iGG** (unbranded network label) · battery %.

## Feature parity
All 25 entries from `mission/LooneyBin.Altis/core/configuration.sqf` `AP_phone_buttons` are present as apps, color-coded by category (comms / gang / economy / property / progression / crime / system / admin).

All 7 screens are done (home, drawer, settings light+dark, wallpaper, market, my gang).

## In-game build — plan + findings
Existing phone = `dialog/smartphone.hpp` (idd **90000**) driven by `core/pmenu/fn_p_openMenu.sqf`:
- **Wallpaper system already exists** — `PhoneWallpaper` (idc 90300) loads `images\wallpapers\<file>` from the `AP_wallpapers` array keyed by `AP_wallpaper`. The picker reuses this; "Apply" just sets `AP_wallpaper`.
- App grid = buttons **90200+** populated from `AP_phone_buttons`; 4 fixed = **90100+**. Each is `<img image='icon.paa'/>` + label in structured text.
- Status slots `StatusTextLeft` (90301) / `Center` (90302) — repurpose Left = restart countdown, add a right cluster (signal/iGG/battery).

Steps to ship:
1. **Icons**: One UI squircle icons are in `icons/` as PNG. Structured-text `<img>` wants **`.paa`** — no converter on this box (blocker). Resolve = install a paa tool (armake2/PAATool) OR reuse the existing `icons\phone_*.paa` in the new layout.
2. Rewrite `smartphone.hpp` to the One UI grid + status bar + card frame; add a light/dark `AP_phoneTheme` color set.
3. `fn_p_openMenu` / a theme fn: paint theme, fill the restart-countdown text, lay out the 4-wide grid.
4. Settings: wire the **Dark mode** toggle (`AP_phoneTheme`) + the wallpaper picker (`AP_wallpaper`).

**Untestable on this box** (needs Arma running) — build + verify on the dev server before it touches the live phone.
