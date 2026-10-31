#!/usr/bin/env bash
# Alert smoke on the local stack (samurai): continuous low-fps feed -> FPS rules fire; healthy feed -> resolve; no feed -> Telemetry silent.
# With DISCORD_ALERT_WEBHOOK exported to the live URL the firing/resolved messages land in the real channel (host=smoke).
set -u
cd ~/Armapunk2035
export GRAFANA_ADMIN_PASSWORD=smoke TELEMETRY_DATA=$PWD/scratchpad/telemetry-smoke VM_PORT=18428 GRAFANA_PORT=13000 GRAFANA_ROOT_URL=http://127.0.0.1:13000 TELEMETRY_PROJECT=aptelemetry-smoke TELEMETRY_ENV=/dev/null DISCORD_ALERT_WEBHOOK="${DISCORD_ALERT_WEBHOOK:-https://discord.com/api/webhooks/0/smoke}"
deploy/telemetry/up.sh >/dev/null 2>&1      # recreates grafana with the edited rules
curl -sf --retry 40 --retry-delay 1 --retry-all-errors 127.0.0.1:13000/api/health >/dev/null
states() { curl -su admin:smoke '127.0.0.1:13000/api/prometheus/grafana/api/v1/rules' | python3 -c 'import sys,json; d=json.load(sys.stdin); print(", ".join("%s=%s" % (r["name"].replace("Server FPS ","FPS "), r["state"]) for g in d["data"]["groups"] for r in g["rules"] if r["name"] in ("Server FPS low","Server FPS critical","Telemetry silent")))'; }
feed() { curl -s -o /dev/null -X POST --data-binary "ap_server_fps{machine=\"server\",host=\"smoke\"} $1 $(date +%s%3N)" 127.0.0.1:18428/api/v1/import/prometheus; }
echo "== phase 1: fps=9 for 200 s"; for i in $(seq 1 20); do feed 9; sleep 10; [ $((i%3)) -eq 0 ] && echo "t+$((i*10))s: $(states)"; done
echo "== phase 2: fps=50 for 120 s (expect resolve)"; for i in $(seq 1 12); do feed 50; sleep 10; [ $((i%3)) -eq 0 ] && echo "t+$((i*10))s: $(states)"; done
echo "== phase 3: no feed for 300 s (expect Telemetry silent)"; for i in $(seq 1 30); do sleep 10; [ $((i%6)) -eq 0 ] && echo "t+$((i*10))s: $(states)"; done
echo "== notifier lines:"; docker logs armapunk-grafana 2>&1 | grep -E 'ap-server-fps|ap-telemetry-silent' | grep -iE 'Sending|error' | tail -4 | cut -c1-160
deploy/telemetry/up.sh down -v >/dev/null 2>&1; rm -rf scratchpad/telemetry-smoke; echo "== torn down"
