#!/usr/bin/env bash
# Launch Arma 3 CLIENT in gamescope @ 3440x1440, bypassing the Steam launcher.
# WHY direct-Proton: the dedicated server runs as appid 107410 (steam_appid.txt), so Steam
# thinks the game is "already running" and won't launch the client. Running arma3_x64.exe
# straight through the sniper runtime + Proton sidesteps Steam's launch path entirely.
#
# Usage:
#   ./launch-client-gamescope.sh                 # land at main menu
#   ./launch-client-gamescope.sh 127.0.0.1 2302  # auto direct-connect
set -u

S="$HOME/.local/share/Steam"
CLIENT="$S/steamapps/common/Arma 3"
RUNTIME="$S/steamapps/common/SteamLinuxRuntime_sniper/_v2-entry-point"
PROTON="$S/compatibilitytools.d/GE-Proton10-34/proton"

export STEAM_COMPAT_DATA_PATH="$S/steamapps/compatdata/107410"
export STEAM_COMPAT_CLIENT_INSTALL_PATH="$S"
export SteamAppId=107410 SteamGameId=107410

# gamescope geometry
W=3440; H=1440

# optional auto-connect
CONNECT=()
if [ "${1:-}" != "" ]; then
  CONNECT=(-connect="${1}" -port="${2:-2302}")
fi

cd "$CLIENT" || exit 1
exec gamescope -W "$W" -H "$H" -f --force-grab-cursor -- \
  "$RUNTIME" -- \
  "$PROTON" run arma3_x64.exe \
  "${CONNECT[@]}" \
  -nolauncher -nosplash -skipIntro -world=empty -name=looney
