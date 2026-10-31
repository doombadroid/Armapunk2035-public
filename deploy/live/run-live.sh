#!/usr/bin/env bash
# Armapunk 2035 LIVE launcher (10.1.24.96). Exec'd by armapunk-arma.service; do not run by hand while the
# unit is active (its ExecStartPre guard would then refuse the next start).
set -u
LIVE=/home/timb/arma3server_live
# MUST match ~/.config/armapunk/pysqfd.env -- see deploy/systemd/pysqfd.env.example.
export PYSQF_SOCKET=/run/user/1000/pysqf.sock
cd "$LIVE"
exec ./arma3server_x64 \
  -config=server.cfg -cfg=basic.cfg \
  -profiles="$LIVE/profiles" \
  -name=armapunk -port=2302 \
  -bepath="$LIVE/battleye" \
  -serverMod="@AP_server" \
  -mod="@Armapunk2035" \
  -filePatching -autoInit
