#!/usr/bin/env bash
# Armapunk 2035 — local Arma3 test server. Same box/port/DB as run-loonydev.sh but loads
# @AP_server (this project) instead of @life_server (the frozen LooneyBin Altis build). Port 2342, DB looneybin_test, BattlEye/signing OFF.
# Isolated from the live stack + lb_v2_dev. Stop with: pkill -f 'name=loonydev'  (NEVER a blanket pkill arma3server_x64).

# Mission HTTP download (server.cfg missionHTTPDownloadBaseURL = http://10.1.24.221:8092/).
# Started here so it comes back with the dev server after a host reboot -- nothing else launches it.
# Idempotent: only starts if 8092 is not already listening.
# NOTE: this replaced `python -m http.server`, which does NOT implement HTTP Range. Arma's mission
# downloader issues ranged requests; a server answering those with "200 + whole file" makes the
# client abandon HTTP and fall back to the slow in-game transfer, silently.
if ! ss -tln 2>/dev/null | grep -q ':8092 '; then
    nohup python3 /home/timb/arma3server_dev/tools/pbo_http.py 8092 \
        > /home/timb/arma3server_dev/pbo_http.log 2>&1 &
    echo "[dev] mission HTTP download started on :8092 (Range enabled)"
fi

set -u
DEV=/home/timb/arma3server_dev
export HOME=/home/timb/lb_v2_dev/steamhome           # isolated Steam ctx -> runs alongside your client
# extDB3 removed 2026-08-20 (owner: PySQF/PostgreSQL only). LD_LIBRARY_PATH export dropped with it.
# PySQF socket. MUST be identical here and in /etc/conf.d/pysqfd (pysqf.md:125).
# Do NOT rely on the default: pysqfd's default_socket_path() returns
# $XDG_RUNTIME_DIR/pysqf.sock when that dir exists and /tmp/pysqf-<uid>.sock otherwise.
# This process inherits XDG_RUNTIME_DIR from the login session; the OpenRC daemon has no
# session and gets none -- so the two sides silently resolved DIFFERENT paths, the
# extension found no socket, apdb fell back to extDB3, and every query died (2026-08-21).
export PYSQF_SOCKET=/tmp/pysqf-1000.sock
cd "$DEV"
exec ./arma3server_x64 \
  -config=server.cfg -cfg=basic.cfg \
  -profiles="$DEV/profiles" \
  -name=loonydev -port=2342 \
  -serverMod="@AP_server" \
  -filePatching -autoInit
