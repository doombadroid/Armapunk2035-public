#!/usr/bin/env bash
# LooneyBin DDoS watcher (owner 2026-06-15). DETECT + ALERT ONLY -- no mitigation. Pings Discord via the
# loonybot outbox when inbound traffic on the WAN-facing iface shows flood signatures, so the owner can
# react if/when it becomes a real problem.
#
# What it samples every $INTERVAL s (all root-free via /proc):
#   - inbound packets/sec + Mbit/sec on the busiest physical iface (the one carrying game traffic)
#   - conntrack table fill % (flood = table exhaustion)
#   - UDP receive-buffer drops (kernel dropping datagrams = socket overwhelmed)
# Triggers on an absolute ceiling OR a sustained multiple over a rolling-calm baseline. Sustained for
# $SUSTAIN samples before it fires (anti-flap). Posts: ALERT once, an ONGOING line every $ONGOING_EVERY s,
# then CLEARED when back to normal. Best-effort top-source list IF conntrack -L is permitted (else it
# prints the command for you to run).
#
# Launch (survives the session; sandbox reaps Bash-tool bg procs):
#   setsid bash "$HOME/Documents/LooneyBin Altis Life/deploy/ddos_watch.sh" > /tmp/lb_ddoswatch.log 2>&1 < /dev/null &
# It is also auto-(re)launched by deploy/run-boot2.sh on every server boot.
set -u

# ---- tunables (override via env) ----------------------------------------------------------------
INTERVAL="${DDOS_INTERVAL:-5}"          # seconds between samples
SUSTAIN="${DDOS_SUSTAIN:-3}"            # consecutive bad samples before alerting (3*5s = 15s)
PPS_FLOOR="${DDOS_PPS_FLOOR:-15000}"    # never alert on a "spike" below this many pps (legit peaks)
PPS_SPIKE="${DDOS_PPS_SPIKE:-8}"        # pps >= baseline*this = anomaly
PPS_HARD="${DDOS_PPS_HARD:-60000}"      # absolute pps ceiling -> alert regardless of baseline
MBIT_HARD="${DDOS_MBIT_HARD:-250}"      # absolute inbound Mbit/s ceiling -> alert
CT_PCT="${DDOS_CT_PCT:-85}"             # conntrack table fill % -> alert
UDP_DROP="${DDOS_UDP_DROP:-800}"        # UDP RcvbufErrors delta/sample -> alert
ONGOING_EVERY="${DDOS_ONGOING_EVERY:-300}"   # seconds between "still ongoing" updates
IFACE_OVERRIDE="${DDOS_IFACE:-}"        # force an iface, else auto-detect busiest physical one
CHAN="${DDOS_CHANNEL:-100000000000000047}"  # status/admin channel (same as restart_watchdog)
GAME_PORTS="${DDOS_PORTS:-230}"         # dport prefix to attribute sources (2302-2306)

PROJ="$HOME/Documents/LooneyBin Altis Life"
OUTBOX="$PROJ/loonybot/outbox"

# ---- helpers ------------------------------------------------------------------------------------
phys_ifaces() { # physical NICs only (skip lo/docker/veth/wg/tun/tap). DDOS_IFACE overrides.
    [ -n "$IFACE_OVERRIDE" ] && { printf '%s\n' $IFACE_OVERRIDE; return; }
    # keep only internet-facing physical NICs; drop loopback, containers, VPN/overlay, CAN bus, etc.
    awk -F: '/:/{name=$1; gsub(/^[ \t]+/,"",name);
        if (name ~ /^(lo$|docker|veth|br-|wg|tun|tap|tailscale|can[0-9]|virbr|bond|dummy|sit|gre|ip6|ifb)/) next;
        print name}' /proc/net/dev 2>/dev/null
}
sum_rx() { # echo "sum_rx_bytes sum_rx_packets" across ALL physical NICs = total INBOUND to the box, so a
           # flood on EITHER NIC (WiFi port-forward or USB-eth) is caught regardless of which one it hits.
    local b=0 p=0 bb pp ifc
    for ifc in $(phys_ifaces); do
        read -r bb pp < <(grep -E "^[[:space:]]*$ifc:" /proc/net/dev | sed 's/.*://' | awk '{print $1, $2}')
        b=$(( b + ${bb:-0} )); p=$(( p + ${pp:-0} ))
    done
    echo "$b $p"
}
ct_count() { cat /proc/sys/net/netfilter/nf_conntrack_count 2>/dev/null || echo 0; }
ct_max()   { cat /proc/sys/net/netfilter/nf_conntrack_max   2>/dev/null || echo 0; }
udp_rcvbuf_err() { awk '/^Udp:/{if(h){print $f}else{for(i=1;i<=NF;i++)if($i=="RcvbufErrors")f=i; h=1}}' /proc/net/snmp 2>/dev/null; }

post() { # $1 = message
    mkdir -p "$OUTBOX"
    python3 - "$CHAN" "$OUTBOX" "$1" <<'PY' 2>/dev/null
import json, sys, time, os
chan, outbox, msg = sys.argv[1], sys.argv[2], sys.argv[3]
open(os.path.join(outbox, "ddos_%d.json" % int(time.time()*1000)), "w").write(
    json.dumps({"channel_id": int(chan), "content": msg}))
PY
}
top_sources() { # best-effort; needs conntrack tool + perms
    local out
    out=$(timeout 4 conntrack -L -p udp 2>/dev/null | grep -oE "dport=${GAME_PORTS}[0-9] .*src=[0-9.]+|src=[0-9.]+ .*dport=${GAME_PORTS}[0-9]" \
          | grep -oE 'src=[0-9.]+' | sed 's/src=//' | sort | uniq -c | sort -rn | head -8)
    if [ -n "$out" ]; then
        printf '%s\n' "$out" | awk '{printf "  %s pkts/flows  %s\\n", $1, $2}'
    else
        echo "  (top sources need root + the conntrack tool -- run: sudo conntrack -L -p udp | grep dport=2302)"
    fi
}

# ---- state --------------------------------------------------------------------------------------
echo "[ddoswatch] online $(date '+%F %T')"
IFACES="$(phys_ifaces | tr '\n' ' ')"; [ -z "${IFACES// }" ] && IFACES="wlp194s0"
echo "[ddoswatch] monitoring NICs: $IFACES  interval=${INTERVAL}s  pps_hard=$PPS_HARD mbit_hard=$MBIT_HARD"
read -r pbytes ppkts < <(sum_rx); : "${pbytes:=0}" "${ppkts:=0}"
perr="$(udp_rcvbuf_err)"; : "${perr:=0}"
baseline=1000          # rolling "calm" pps baseline (EWMA)
bad=0; good=0; alerting=0; last_ongoing=0

while true; do
    sleep "$INTERVAL"
    read -r nbytes npkts < <(sum_rx); : "${nbytes:=$pbytes}" "${npkts:=$ppkts}"
    nerr="$(udp_rcvbuf_err)"; : "${nerr:=$perr}"
    dpkts=$(( npkts - ppkts )); [ "$dpkts" -lt 0 ] && dpkts=0
    dbytes=$(( nbytes - pbytes )); [ "$dbytes" -lt 0 ] && dbytes=0
    derr=$(( nerr - perr )); [ "$derr" -lt 0 ] && derr=0
    pps=$(( dpkts / INTERVAL ))
    mbit=$(( (dbytes * 8) / (INTERVAL * 1000000) ))
    ctc="$(ct_count)"; ctm="$(ct_max)"; ctpct=0; [ "$ctm" -gt 0 ] && ctpct=$(( ctc * 100 / ctm ))
    pbytes="$nbytes"; ppkts="$npkts"; perr="$nerr"

    # reasons
    reasons=""
    [ "$pps"   -ge "$PPS_HARD" ]  && reasons="$reasons pps=$pps(>=hard $PPS_HARD)"
    [ "$mbit"  -ge "$MBIT_HARD" ] && reasons="$reasons in=${mbit}Mbit(>=hard $MBIT_HARD)"
    [ "$pps"   -ge "$PPS_FLOOR" ] && [ "$pps" -ge $(( baseline * PPS_SPIKE )) ] && reasons="$reasons pps=$pps(${PPS_SPIKE}x base $baseline)"
    [ "$ctpct" -ge "$CT_PCT" ]    && reasons="$reasons conntrack=${ctpct}%(${ctc}/${ctm})"
    [ "$derr"  -ge "$UDP_DROP" ]  && reasons="$reasons udp_drops=+$derr"

    if [ -n "$reasons" ]; then
        bad=$((bad+1)); good=0
    else
        good=$((good+1)); bad=0
        # update calm baseline only when clean (EWMA ~ baseline*0.8 + pps*0.2)
        baseline=$(( (baseline * 4 + pps) / 5 )); [ "$baseline" -lt 500 ] && baseline=500
    fi

    now=$(date +%s)
    if [ "$alerting" = "0" ] && [ "$bad" -ge "$SUSTAIN" ]; then
        alerting=1; last_ongoing="$now"
        srcs="$(top_sources)"
        post "🚨 **Possible DDoS on the server** ($(date '+%H:%M:%S' )) — iface \`$IFACES\`
sustained ${SUSTAIN}x: **$pps pps**, **${mbit} Mbit/s** in, conntrack ${ctpct}%, udp-drops +${derr}/s
triggers:$reasons
top sources:
$srcs
_(detector only — no mitigation applied. If real: cut the port-forward / enable the upstream scrubber.)_"
        echo "[ddoswatch] ALERT $(date '+%F %T') :$reasons"
    elif [ "$alerting" = "1" ]; then
        if [ "$good" -ge "$SUSTAIN" ]; then
            alerting=0
            post "✅ **DDoS signature cleared** ($(date '+%H:%M:%S')) — iface \`$IFACES\` back to normal (${pps} pps, ${mbit} Mbit/s)."
            echo "[ddoswatch] CLEARED $(date '+%F %T')"
        elif [ $(( now - last_ongoing )) -ge "$ONGOING_EVERY" ]; then
            last_ongoing="$now"
            post "⏳ **DDoS still ongoing** ($(date '+%H:%M:%S')) — \`$IFACES\` $pps pps, ${mbit} Mbit/s, conntrack ${ctpct}%."
        fi
    fi
done
