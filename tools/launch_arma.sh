#!/usr/bin/env bash
# Launch Arma 3 directly under Proton, bypassing the Arma 3 Launcher.
#
# The launcher hangs on this box (owner, 2026-08-04) and every mod iteration
# needs a full game restart, so the agent drives launches through here. This
# reproduces the owner's Steam launch options exactly:
#   DXVK_HUD=fps,frametimes DXVK_FRAME_RATE=90 PROTON_ENABLE_WAYLAND=1 \
#   gamemoderun %command% -malloc=system -mod=@Armapunk2035
#
# Direct launch works because the game dir carries steam_appid.txt (107410),
# so SteamAPI authenticates with the running Steam client without the launcher.
#
# NEVER pass -skipIntro: the main menu's intro MISSION is what fires the
# mod's CfgFunctions preInit bootstrap. With -skipIntro the custom menu
# never appears (cost a round on 2026-08-04).
# Usage:  tools/launch_arma.sh [extra arma args...]
#   ARMA_MODS=@Armapunk2035;@Other   override the mod list
#   PROTON_DIR=/path/to/proton       override the Proton build
set -euo pipefail
STEAM="$HOME/.local/share/Steam"
GAME="$STEAM/steamapps/common/Arma 3"
PROTON="${PROTON_DIR:-$STEAM/compatibilitytools.d/GE-Proton10-34}/proton"
# CBA_a3 (workshop 450814997) is required — the main menu misbehaves without
# it (owner, 2026-08-04), and the mission expects CBA settings.
CBA="$STEAM/steamapps/workshop/content/107410/450814997"
MODS="${ARMA_MODS:-@Armapunk2035;$CBA}"

[ -x "$PROTON" ] || { echo "no proton at $PROTON"; exit 1; }
[ -f "$GAME/arma3_x64.exe" ] || { echo "no game at $GAME"; exit 1; }

# Kill a stuck launcher/game by exact process name (never by -f pattern: a
# pattern that names the target also matches the killing shell's own cmdline
# and takes it out instead — cost us two rounds today).
# Kill any running instance by its WINDOW pid. Under Proton the Linux process
# name is NOT the Windows exe name, so pkill -x/-f never matches the game (and
# a -f pattern matches the killing shell instead — that footgun ate two rounds
# on 2026-08-04). The compositor knows the real pid; ask it.
for pid in $(hyprctl clients -j 2>/dev/null | python3 -c "
import json, sys
try:
    for c in json.load(sys.stdin):
        if 'arma3_x64' in c['class'] or 'arma3launcher' in c['class']:
            print(c['pid'])
except Exception:
    pass" 2>/dev/null); do
    kill "$pid" 2>/dev/null || true
done
sleep 6

# Arma opens on whichever display the CURSOR is on (owner, 2026-08-04), so
# park the pointer on the target output before launching — otherwise the game
# lands on the laptop panel at the wrong resolution and everything is cropped.
TARGET_MON="${ARMA_MONITOR:-HDMI-A-1}"
hyprctl monitors -j 2>/dev/null | python3 -c "
import json, subprocess, sys
name = sys.argv[1]
for m in json.load(sys.stdin):
    if m['name'] == name:
        s = float(m.get('scale', 1))
        x = int(m['x'] + (m['width'] / s) / 2)
        y = int(m['y'] + (m['height'] / s) / 2)
        subprocess.run(['hyprctl', 'dispatch', 'movecursor', str(x), str(y)])
        break
" "$TARGET_MON" 2>/dev/null || true
sleep 1

export STEAM_COMPAT_DATA_PATH="$STEAM/steamapps/compatdata/107410"
export STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM"
export STEAM_COMPAT_INSTALL_PATH="$GAME"
export STEAM_COMPAT_APP_ID=107410
export SteamAppId=107410
export SteamGameId=107410
export DXVK_HUD=fps,frametimes
export DXVK_FRAME_RATE=90
export PROTON_ENABLE_WAYLAND=1

# Bare `proton run` exits immediately on this box (missing container libs +
# "xrandr not in PATH"). Steam wraps Proton in the sniper runtime container —
# reuse that exact chain, swapping the launcher exe for the game exe.
RUNTIME="$STEAM/steamapps/common/SteamLinuxRuntime_sniper/_v2-entry-point"
cd "$GAME"
if [ -x "$RUNTIME" ]; then
    exec gamemoderun "$RUNTIME" --verb=waitforexitandrun -- \
        "$PROTON" waitforexitandrun "$GAME/arma3_x64.exe" \
        -malloc=system -mod="$MODS" -nosplash "$@"
else
    exec gamemoderun "$PROTON" run "$GAME/arma3_x64.exe" \
        -malloc=system -mod="$MODS" -nosplash "$@"
fi
