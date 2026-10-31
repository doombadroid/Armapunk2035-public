#!/usr/bin/env bash
# provision_cachyos.sh — stand up the LooneyBin stack on a fresh CachyOS (Arch-based) box.
# Consumes the tarballs produced by migrate_bundle.sh. Run AS the target user (timb), from a
# directory containing bundle_<stamp>_main.tar.gz + bundle_<stamp>_secrets.tar.gz.
#
# PHASED + idempotent: run start-to-finish, or one PHASE at a time (env PHASE=deps|code|arma|
# db|secrets|venv|services|verify) while you watch. Nothing here touches the OLD box.
#
#   PHASE=deps     ./provision_cachyos.sh   # pacman packages + docker + steamcmd
#   PHASE=code     ./provision_cachyos.sh   # git clone main + doomba worktree
#   PHASE=arma     ./provision_cachyos.sh   # steamcmd arma3server + restore @extDB3/appid/keys
#   PHASE=db       ./provision_cachyos.sh   # mariadb container (CLEAN named volume) + restore dump
#   PHASE=secrets  ./provision_cachyos.sh   # place tokens / RCON / extDB3 creds / signing key / markers
#   PHASE=venv     ./provision_cachyos.sh   # recreate the bot venv from requirements.txt
#   PHASE=services ./provision_cachyos.sh   # install systemd units (loonybot, officer-maggot, docker)
#   PHASE=verify   ./provision_cachyos.sh   # sanity checks (no server launch — that's run-boot2)
set -euo pipefail

PROJ="$HOME/Documents/LooneyBin Altis Life"
A3SRV="$HOME/.local/share/Steam/steamapps/common/Arma 3 Server"
BUNDLE_DIR="${BUNDLE_DIR:-$PWD}"                 # where the two tarballs live
STAGE="$HOME/loonybin-migration/restore"        # where we extract them
PHASE="${PHASE:-all}"
run() { [ "$PHASE" = "all" ] || [ "$PHASE" = "$1" ]; }

# --- extract the bundle once (both tarballs -> $STAGE/bundle_*) ---------------------------
_ensure_extracted() {
  [ -d "$STAGE" ] && ls "$STAGE"/bundle_*/MANIFEST.txt >/dev/null 2>&1 && return
  mkdir -p "$STAGE"
  for t in "$BUNDLE_DIR"/bundle_*_main.tar.gz "$BUNDLE_DIR"/bundle_*_secrets.tar.gz; do
    [ -f "$t" ] && tar xzf "$t" -C "$STAGE"
  done
  ls "$STAGE"/bundle_*/MANIFEST.txt >/dev/null 2>&1 || { echo "!! no bundle found in $BUNDLE_DIR"; exit 1; }
}
_B() { _ensure_extracted; echo "$(ls -d "$STAGE"/bundle_* | head -1)"; }

# ========================================================================================
if run deps; then
  echo "== PHASE deps =="
  # CachyOS = Arch. Enable multilib in /etc/pacman.conf if not already (steam/arma libs).
  sudo pacman -Syu --needed --noconfirm docker docker-compose python git base-devel rsync jq
  # steamcmd: try repos, else AUR via paru (CachyOS ships paru).
  sudo pacman -S --needed --noconfirm steamcmd 2>/dev/null || paru -S --needed --noconfirm steamcmd
  # arma3server runtime libs commonly needed on Arch:
  sudo pacman -S --needed --noconfirm lib32-glibc lib32-gcc-libs 2>/dev/null || true
  sudo systemctl enable --now docker
  sudo usermod -aG docker "$USER" || true
  echo "  (log out/in for the docker group to take effect, or use 'sg docker')"
fi

if run code; then
  echo "== PHASE code =="
  mkdir -p "$HOME/Documents"
  [ -d "$PROJ/.git" ] || git clone https://github.com/doombadroid/LoonyBin.git "$PROJ"
  git -C "$PROJ" fetch origin
  git -C "$PROJ" checkout main && git -C "$PROJ" pull --ff-only
  # doomba worktree (dev branch)
  [ -d "$HOME/loonybin-doomba/.git" ] || git -C "$PROJ" worktree add "$HOME/loonybin-doomba" doomba 2>/dev/null \
    || git clone -b doomba https://github.com/doombadroid/LoonyBin.git "$HOME/loonybin-doomba" || true
fi

if run arma; then
  echo "== PHASE arma =="
  B="$(_B)"
  mkdir -p "$A3SRV"
  echo "  steamcmd: downloading Arma 3 Dedicated Server (app 233780) — ~6GB, this takes a while."
  echo "  You need a Steam account that owns Arma 3 (anonymous does NOT work for the server)."
  echo "  Run:  steamcmd +force_install_dir \"$A3SRV\" +login <steamuser> +app_update 233780 validate +quit"
  read -rp "  Run steamcmd now with a login you'll type? [y/N] " _go
  if [ "${_go,,}" = "y" ]; then
    read -rp "  Steam username: " _su
    steamcmd +force_install_dir "$A3SRV" +login "$_su" +app_update 233780 validate +quit
  else
    echo "  Skipped steamcmd — run it manually, then re-run PHASE=arma to place the custom parts."
  fi
  # restore the custom parts steamcmd does NOT provide
  cp -a "$B/arma/@extDB3"        "$A3SRV/"            2>/dev/null || true
  cp -a "$B/arma/steam_appid.txt" "$A3SRV/"           2>/dev/null || true
  cp -a "$B/arma/server_keys"    "$A3SRV/keys"        2>/dev/null || true
  cp -a "$B/arma"/libtbbmalloc.so* "$A3SRV/"          2>/dev/null || true
  echo "  placed @extDB3 + steam_appid.txt(107410) + keys + libtbbmalloc. (@AP_server + mission repack from source at boot.)"
fi

if run db; then
  echo "== PHASE db =="
  B="$(_B)"
  # CLEAN named volume (fixes the old hash-named volume; the TODO in run-boot2).
  docker volume create looneybin-db-data >/dev/null
  if ! docker ps -a --format '{{.Names}}' | grep -qx looneybin-db; then
    docker run -d --name looneybin-db --restart unless-stopped \
      -e MARIADB_ROOT_PASSWORD=looneybin -e MARIADB_DATABASE=looneybin \
      -e MARIADB_USER=looneybin -e MARIADB_PASSWORD=looneybin \
      -p 127.0.0.1:3306:3306 -v looneybin-db-data:/var/lib/mysql mariadb:11
  fi
  echo "  waiting for mariadb..."
  for _i in $(seq 1 40); do docker exec looneybin-db mariadb-admin ping -h127.0.0.1 --silent 2>/dev/null && break; sleep 1; done
  _dump="$(ls -t "$B"/db/looneybin_*.sql.gz 2>/dev/null | head -1)"
  echo "  restoring $_dump ..."
  gunzip -c "$_dump" | docker exec -i looneybin-db mariadb -ulooneybin -plooneybin looneybin
  _n=$(docker exec looneybin-db mariadb -ulooneybin -plooneybin -N -B -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='looneybin'" 2>/dev/null)
  echo "  restored -> $_n tables."
fi

if run secrets; then
  echo "== PHASE secrets =="
  B="$(_B)"; S="$B/secrets"
  cp -a "$S/config.json"          "$PROJ/loonybot/"        2>/dev/null || true
  cp -a "$S/enrique.config.json"  "$PROJ/loonybot/"        2>/dev/null || true
  cp -a "$S/latoya.config.json"   "$PROJ/loonybot/"        2>/dev/null || true
  cp -a "$S/clankr_state.json"    "$PROJ/loonybot/"        2>/dev/null || true
  cp -a "$S"/*.ranknicks.json     "$PROJ/loonybot/"        2>/dev/null || true
  mkdir -p "$PROJ/deploy/keys" "$PROJ/deploy/battleye"
  cp -a "$S/keys/"*               "$PROJ/deploy/keys/"     2>/dev/null || true
  cp -a "$S/beserver.cfg" "$S/beserver_x64.cfg" "$PROJ/deploy/battleye/" 2>/dev/null || true
  # extDB3 creds: the repo file is CHANGE_ME; run-boot2 injects the pass at boot, so we only need
  # the pass to match the container (default 'looneybin'). The deployed copy is also restored:
  cp -a "$S/extdb3-conf.ini.deployed" "$A3SRV/@extDB3/extdb3-conf.ini" 2>/dev/null || true
  cp -a "$S/extdb3-conf.ini.deployed" "$A3SRV/extdb3-conf.ini"         2>/dev/null || true
  # deploy state markers (so the one-time DB migrations do NOT re-run)
  cp -a "$B/state/".*_done "$PROJ/deploy/" 2>/dev/null || true
  chmod 600 "$PROJ/deploy/keys/"*.biprivatekey 2>/dev/null || true
  echo "  placed tokens, RCON cfg, signing key, extDB3 creds, and deploy markers."
fi

if run venv; then
  echo "== PHASE venv =="
  B="$(_B)"
  python -m venv "$PROJ/loonybot/venv"
  "$PROJ/loonybot/venv/bin/pip" install --upgrade pip
  "$PROJ/loonybot/venv/bin/pip" install -r "$B/requirements.txt"
  echo "  bot venv recreated ($("$PROJ/loonybot/venv/bin/pip" list 2>/dev/null | wc -l) packages)."
fi

if run services; then
  echo "== PHASE services =="
  # space-free launcher wrappers (systemd, like OpenRC, is happier without the space-path)
  sudo install -m0755 "$PROJ/deploy/systemd/loonybot-launch.sh"       /usr/local/bin/loonybot
  sudo install -m0755 "$PROJ/deploy/systemd/officer-maggot-launch.sh" /usr/local/bin/officer-maggot
  sudo install -m0644 "$PROJ/deploy/systemd/loonybot.service"         /etc/systemd/system/loonybot.service
  sudo install -m0644 "$PROJ/deploy/systemd/officer-maggot.service"   /etc/systemd/system/officer-maggot.service
  sudo systemctl daemon-reload
  sudo systemctl enable --now loonybot officer-maggot
  echo "  loonybot + officer-maggot installed as systemd services (Restart=always)."
  echo "  NOTE: clankr/lagwatch/ddos_watch/enrique/latoya/restart_watchdog are auto-launched by run-boot2.sh (setsid),"
  echo "        not services — they come up when you launch the server."
fi

if run verify; then
  echo "== PHASE verify =="
  echo -n "  docker DB: ";   docker ps --format '{{.Names}} {{.Status}}' | grep looneybin-db || echo "DOWN"
  echo -n "  DB tables: ";   docker exec looneybin-db mariadb -ulooneybin -plooneybin -N -B -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='looneybin'" 2>/dev/null || echo "?"
  echo -n "  players rows: ";docker exec looneybin-db mariadb -ulooneybin -plooneybin -N -B -e "SELECT COUNT(*) FROM players" looneybin 2>/dev/null || echo "?"
  echo    "  loonybot: $(systemctl is-active loonybot 2>/dev/null)   officer-maggot: $(systemctl is-active officer-maggot 2>/dev/null)"
  echo    "  arma install: $([ -x "$A3SRV/arma3server_x64" ] && echo present || echo MISSING)   @extDB3: $([ -d "$A3SRV/@extDB3" ] && echo present || echo MISSING)"
  echo    "  signing key: $([ -f "$PROJ/deploy/keys/looneybin.biprivatekey" ] && echo present || echo MISSING)"
  echo
  echo "  If all present: launch with  ->  cd \"$PROJ/deploy\" && ./run-boot2.sh"
  echo "  (run-boot2 repacks + signs the PBOs from source, injects the extDB3 pass, and starts the server + support bots.)"
fi

echo "[provision] PHASE=$PHASE done."
