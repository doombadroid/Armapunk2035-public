# Deck icon regen (iOS high-contrast set, 2026-07-21)

1. Edit `icon_sheet_ios.html` (33 tiles, 8-col grid of 128px cells; order = NAMES list below).
2. Render: `chrome-headless-shell --headless --disable-gpu --screenshot=sheet.png --window-size=1024,640 --default-background-color=00000000 --hide-scrollbars file://.../icon_sheet_ios.html`
3. Slice cells (128x128, row-major) and bake each with `make_paa.build_paa_dxt5` (tools/make_paa.py) to `mission/LooneyBin.Altis/icons/deck_<name>.paa`.

NAMES order: cyberdeck quickhacks admin camera group mygang captures perks talents infamy keychain licenses settings wallpaper achieve titles market housing quests phone casino browser robotaxi ownermode sync money message inventory wanted gangsonline bounty prestige honor

Approved mockup artifact: https://claude.ai/code/artifact/83f53959-eb5e-4ba3-86a0-dd7787c9a51b
