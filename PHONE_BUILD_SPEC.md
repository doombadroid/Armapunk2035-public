# Phone Redesign — Build Contract (phone_redesign worktree)

Restyle the in-game phone (`dialog/smartphone.hpp` idd 90000 + `core/pmenu/`) to the Samsung One UI design in `design/phone/renders/*.png` (the visual target). **UNTESTABLE on this box (no Arma) → first pass; flag every assumption; dev-server test later.**

## Hard rules
- **ALL dynamic/changing text** (restart countdown, battery, player name, cash/bank, gang name, member names, market prices, headers that change) = `AP_RscStructuredText` / `AP_RscText` with **`font="RobotoCondensed"`**. NEVER bake changing text into an image.
- Rounded chrome (cards, squircle icon backgrounds, dock bar) = `.paa` images at `images\phone\*.paa` (the asset agent generates these). Reuse ONE `card.paa` / `squircle.paa` and **tint per app/theme** via `colorText[]`/`color[]` rather than many textures.
- Reuse the existing wallpaper system: `AP_wallpapers` (24), `AP_wallpaper`, `fn_setWallpaper.sqf`, `images\wallpapers\*.paa`.
- Theme: `AP_phoneTheme` (0 = light [default], 1 = dark), persisted in `LoonyBinClientSettings` (same pattern as `AP_wallpaper` in `fn_settingsInit.sqf` / index in `AP_clientDefaultSettings`). Applied at runtime by `fn_p_theme`.
- Coordinate system = `UI_GRID_X/Y` (0.5) + `UI_GRID_W/H` (`2.5*pixelW/H*pixelGrid`). Base new positions on the existing `smartphone.hpp` control coords (the phone already sits centered).

## idc map (dialog/smartphone.hpp, idd 90000)
- `90300` PhoneWallpaper — exists, reuse (RscPictureKeepAspect, loads `images\wallpapers\<AP_wallpaper file>`).
- `90301` StatusLeft = **restart countdown** — `AP_RscStructuredText`, RobotoCondensed, top-left.
- `90303` StatusRight = **iGG + battery%** — `AP_RscStructuredText`, RobotoCondensed, top-right.
- `90310` Header title (screen name, dynamic) — `AP_RscStructuredText`.
- `90200..90224` = app grid buttons (up to 25), **4 columns** (existing `AP_PhoneButton`, repositioned to the One UI grid; icon via structured text `<img>` + label).
- `90100..90103` = the 4 fixed top buttons (Sync/Money/Message/Inventory) — keep, fold into the grid or a dock.
- `90400..90403` = dock icons (4).
- `90320` = page dots.
- `1005` = Home/close (exists).
- Card/dock backgrounds = `AP_RscPictureKeepAspect` controls using `images\phone\card.paa` etc., tinted per theme.

## color sets (used by fn_p_theme; mockup palette, 0–1 floats)
- light: cards `{1,1,1,1}`; text `{0.086,0.086,0.086,1}` / sub `{0.53,0.53,0.55,1}`; accent `{0.06,0.48,1,1}`.
- dark: cards `{0.106,0.106,0.122,1}`; text `{0.95,0.95,0.96,1}` / sub `{0.6,0.6,0.63,1}`; accent `{0.06,0.48,1,1}`.

## fns (core/pmenu/)
- `fn_p_openMenu.sqf` (REWRITE): create dialog, call `fn_p_theme`, fill the 4-wide app grid from `AP_phone_buttons` (same conditional pattern as now), set header text, `spawn fn_p_statusBar`.
- `fn_p_statusBar.sqf` (NEW): loop while `findDisplay 90000` alive — set `90301` = `"<N>m"` (minutes to next restart; pull from `server_control.watch_until`/a restart-time var if available, else a placeholder + a clear TODO), `90303` = iGG + battery (use `100`/flavor + TODO). RobotoCondensed structured text.
- `fn_p_theme.sqf` (NEW): read `AP_phoneTheme`, `ctrlSetTextColor`/`ctrlSetBackgroundColor` on the card + text controls.
- `fn_setWallpaper.sqf` (EXISTS): reuse from the picker.

## settings (dialog/settings.hpp + core/pmenu/fn_settings*.sqf)
- Add a **Dark mode** toggle → flips `AP_phoneTheme` (0/1), persists in `LoonyBinClientSettings`, re-applies `fn_p_theme` if the phone is open.
- Restyle the **wallpaper picker** (grid over `AP_wallpapers`) to `design/phone/renders/oneui_wallpaper.png`; selecting calls `fn_setWallpaper`.

## assets (images\phone\*.paa — asset agent)
- `card.paa` (rounded-rect, white, tinted at runtime), `squircle.paa` (rounded icon bg, tinted), `dock.paa`.
- App glyphs: reuse `icons\phone_*.paa` OR convert `design/phone/icons/app_*.png` → `.paa` (via armake2, building now at `~/.cargo/bin/armake2`).
</content>
