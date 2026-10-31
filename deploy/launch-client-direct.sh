#!/usr/bin/env bash
# Launch the Arma 3 CLIENT directly through Proton, BYPASSING Steam's launcher.
# WHY: the dedicated server calls SteamAPI_Init as appid 107410, so Steam thinks the game is
# already running and refuses to launch the client normally. Running arma3_x64.exe straight
# through Proton never touches Steam's launch path, so the server can stay up.
set -u

STEAM="$HOME/.local/share/Steam"
CLIENT="$STEAM/steamapps/common/Arma 3"
PROTON="$STEAM/compatibilitytools.d/GE-Proton10-34/proton"
export STEAM_COMPAT_DATA_PATH="$STEAM/steamapps/compatdata/107410"
export STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM"
# graphical session (server shell has no DISPLAY by default)
export DISPLAY="${DISPLAY:-:0}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}"
# tell Proton this is appid 107410 so it finds the right prefix/runtime
export SteamAppId=107410 SteamGameId=107410

RUNTIME="$STEAM/steamapps/common/SteamLinuxRuntime_sniper/_v2-entry-point"
# NOTE on the "server up = client won't launch" problem:
# The dedicated server's dir has steam_appid.txt=107410, so it occupies the CLIENT Steam slot
# and Steam refuses to launch the client ("already running"). The server's real appid is 233780.
# This script sidesteps it entirely by launching arma3_x64.exe straight through the sniper
# runtime + Proton, which never asks the Steam client to start app 107410.
IP="${1:-127.0.0.1}"
PORT="${2:-2302}"

cd "$CLIENT" || exit 1
# GE-Proton must run inside the sniper runtime container, not bare.
exec "$RUNTIME" -- \
  "$PROTON" run arma3_x64.exe \
  -connect="$IP" -port="$PORT" \
  -nolauncher -nosplash -skipIntro -world=empty -name=looney
