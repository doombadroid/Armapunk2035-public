#!/usr/bin/env bash
# Launch the Arma 3 CLIENT against the dev server, WITH the @Armapunk2035 client mod.
#
# WHY THIS EXISTS. deploy/launch-client-direct.sh over in loonybin-doomba passes no
# -mod at all, so the client runs vanilla: no radio stations, no main menu, no
# faces/NVG addons. (It used to matter more: until 2026-08-18 the mission also
# referenced hologram textures that lived only in the mod, and a vanilla client got
# a MESSAGE BOX per missing texture before reaching the server. That dependency is
# gone; the mod is optional content now, not a requirement.)
#
# That script also lives in the FROZEN LooneyBin repo, so it is not the place to fix
# this. This is the Armapunk 2035 launcher.
#
# The mod is otherwise optional: the server sets verifySignatures = 0 and does not
# require it. Loading it is what makes the startup clean.
#
#   bash deploy/launch-client.sh                 # 127.0.0.1:2342 (dev)
#   bash deploy/launch-client.sh 10.1.24.96 2302
#
# The vanilla-launch mechanics below (Proton direct, bypassing Steam) are lifted from
# the doomba script and are load-bearing: the dedicated server calls SteamAPI_Init as
# appid 107410, so Steam believes the game is already running and refuses to start the
# client normally. Going straight at arma3_x64.exe through the sniper runtime never
# asks Steam to launch 107410, so the server can stay up.
set -u

STEAM="$HOME/.local/share/Steam"
CLIENT="$STEAM/steamapps/common/Arma 3"
PROTON="$STEAM/compatibilitytools.d/GE-Proton10-34/proton"
RUNTIME="$STEAM/steamapps/common/SteamLinuxRuntime_sniper/_v2-entry-point"

# The built client mod. Lives in the main worktree's dist, not this one -- it is built
# by the radio pipeline and shared, and there is no reason for each worktree to carry
# its own copy of six PBOs.
MOD="${AP_CLIENT_MOD:-$HOME/Armapunk2035/radio/dist/@Armapunk2035}"

export STEAM_COMPAT_DATA_PATH="$STEAM/steamapps/compatdata/107410"
export STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM"
export DISPLAY="${DISPLAY:-:0}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}"
export SteamAppId=107410 SteamGameId=107410

IP="${1:-127.0.0.1}"
PORT="${2:-2342}"

if [ ! -d "$MOD" ]; then
    echo "!! client mod not found at $MOD"
    echo "   Launching WITHOUT it: vanilla client (no radio, no custom main menu)."
    echo "   Set AP_CLIENT_MOD to point at a built @Armapunk2035 if it lives elsewhere."
    MODARG=()
else
    echo "-- client mod: $MOD ($(ls "$MOD/addons"/*.pbo 2>/dev/null | wc -l) pbo)"
    # Proton needs a Windows-style path for -mod. Z: maps the Linux root.
    MODARG=(-mod="Z:${MOD//\//\\}")
fi

echo "-- connecting to $IP:$PORT"
# The exe goes to Proton as a FULL path: Proton's steam.exe does not resolve a bare "arma3_x64.exe"
# against the shell cwd (PROTON_LOG 2026-09-22: "err:steam:run_process Failed to create process ... : 2",
# file not found, even when started from the Arma 3 folder), so the client silently never started.
exec "$RUNTIME" -- \
  "$PROTON" run "$CLIENT/arma3_x64.exe" \
  -connect="$IP" -port="$PORT" \
  "${MODARG[@]}" \
  -nolauncher -nosplash -skipIntro -world=empty -name=looney
