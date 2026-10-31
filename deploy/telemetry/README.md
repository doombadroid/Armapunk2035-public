# deploy/telemetry — VictoriaMetrics + Grafana for the game's metrics

Design: `TELEMETRY_SPEC.md` (repo root). Game side: `tools/pysqf_modules/telemetry.py` (daemon
module), `server/AP_server/core/TON/fn_telemetry.sqf` (collector jobs),
`fn_telemetryBeat.sqf` on both sides (client beat).

## Files

| file | what |
|---|---|
| `docker-compose.live.yml` | `armapunk-vm` (VictoriaMetrics, `127.0.0.1:8428`) + `armapunk-grafana` (`127.0.0.1:3000`) |
| `up.sh` | sources `~/.config/armapunk/telemetry.env`, creates the data dirs, `compose up -d` (any other verb passes through: `up.sh down`, `up.sh logs -f grafana`) |
| `grafana/provisioning/datasources/vm.yaml` | the one datasource, uid `armapunk-vm` |
| `grafana/provisioning/dashboards/armapunk.yaml` | file provider over `grafana/dashboards` |
| `gen_dashboards.py` | **source** of the three dashboards; `--check` fails when the JSON is stale |
| `grafana/dashboards/*.json` | generated; Grafana re-reads them every 30 s |

## First run on a box

```bash
umask 077
printf 'GRAFANA_ADMIN_PASSWORD=%s\nTELEMETRY_DATA=/home/timb/telemetry\n' "$(openssl rand -hex 16)" \
    > ~/.config/armapunk/telemetry.env
deploy/telemetry/up.sh
curl -s 127.0.0.1:3000/api/health          # {"database":"ok",...}
curl -s 127.0.0.1:8428/health              # OK
```

Then the daemon: `AP_TELEMETRY_URL=http://127.0.0.1:8428/api/v1/import/prometheus` and
`AP_TELEMETRY_HOST=live` in `~/.config/armapunk/pysqfd.env`, `telemetry` in the unit's
`--modules`, restart `armapunk-pysqfd` **while the Arma server is stopped** (a daemon restart
under a running server fails every DB call in the gap).

Public access: ingress `grafana.armapunk.com -> http://127.0.0.1:3000` in
`~/.cloudflared/armapunk.yml` (before the 404 catch-all), DNS with
`cloudflared tunnel --origincert ~/.cloudflared/cert-armapunk.pem route dns armapunk grafana.armapunk.com`,
then `sudo systemctl restart armapunk-tunnel`. Grafana's own login is the gate; sign-up and
anonymous access are off.

## Local smoke (samurai; :3000 is taken here)

```bash
GRAFANA_ADMIN_PASSWORD=smoke TELEMETRY_DATA=$PWD/scratchpad/telemetry-smoke VM_PORT=18428 \
GRAFANA_PORT=13000 GRAFANA_ROOT_URL=http://127.0.0.1:13000 TELEMETRY_PROJECT=aptelemetry-smoke \
TELEMETRY_ENV=/dev/null deploy/telemetry/up.sh
curl -su admin:smoke 127.0.0.1:13000/api/search | python3 -m json.tool
TELEMETRY_PROJECT=aptelemetry-smoke TELEMETRY_ENV=/dev/null GRAFANA_ADMIN_PASSWORD=x deploy/telemetry/up.sh down -v
```

## Querying without Grafana

```bash
curl -s '127.0.0.1:8428/api/v1/query?query=ap_server_fps&latency_offset=1s'
curl -s '127.0.0.1:8428/api/v1/label/__name__/values' | grep -o '"ap_[a-z_]*"' | sort -u
```

`latency_offset` matters on the command line: the server runs with `-search.latencyOffset=1s`,
which applies to Grafana's queries too, but a raw query without the parameter would otherwise
hide the newest samples.

Retention is 90 days (`-retentionPeriod=90d`). The data is operational telemetry, not player
state, and is deliberately not in the NAS backup set.

## Running the database collector tests on the box

The DSN is a space-separated libpq string. Do **not** shell-source `pysqfd.env` for it (the
words after the first become separate variables and psycopg sees no user or password);
read the line whole:

```bash
export PYSQF_DB_DSN="$(grep '^PYSQF_DB_DSN=' ~/.config/armapunk/pysqfd.env | cut -d= -f2-)"
cd ~/Armapunk2035 && AP_TELEMETRY_COLLECTORS=0 /home/timb/pysqf-venv/bin/python -m unittest tools.pysqf_modules.test_telemetry_collectors
```

## Discord alerts

`grafana/provisioning/alerting/` holds the contact point (Discord webhook from
`DISCORD_ALERT_WEBHOOK` in `telemetry.env`), the root policy and the rules (see `TELEMETRY_SPEC.md`
§ Alerts for the table). Change a threshold → edit `rules.yaml` → `push-96.sh --no-reload` →
`up.sh restart grafana` (alerting provisioning is read only at start; dashboards are the ones
re-read every 30 s). New channel → new webhook URL in `telemetry.env` → `up.sh` (recreates the
Grafana container with the new env). Test the webhook itself (the Grafana receiver-test API changed shape in 13 and takes a full
receiver spec; a direct post proves the channel and URL, which is the part that can be wrong):

```bash
URL=$(grep DISCORD_ALERT_WEBHOOK ~/.config/armapunk/telemetry.env | cut -d= -f2-)
curl -s -o /dev/null -w '%{http_code}\n' -H 'Content-Type: application/json' "$URL" \
  -d '{"username":"Armapunk Alerts","content":"webhook test"}'      # 204
```

To see a real alert message once, run `deploy/telemetry/alert_smoke.sh` on samurai with
`DISCORD_ALERT_WEBHOOK` set to the live URL: it feeds a synthetic 9 FPS series to the local stack
for 200 s, so "Server FPS critical / low" fire and then resolve in the channel (labelled host=smoke).
