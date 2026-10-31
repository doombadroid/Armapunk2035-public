#!/usr/bin/env python3
"""Generate the three provisioned Grafana dashboards (TELEMETRY_SPEC.md).

    python3 deploy/telemetry/gen_dashboards.py          # writes grafana/dashboards/*.json
    python3 deploy/telemetry/gen_dashboards.py --check  # exit 1 if the JSON on disk is stale

The JSON is the artefact Grafana loads; this file is the source. Hand-editing the
JSON is a change that the next run silently reverts, so edit here and re-run.

Design rules applied (dataviz skill, validated 2026-09-09 against the dark surface):
  - one y-axis per panel, never a dual axis; two scales -> two panels
  - fixed categorical colours per ENTITY (side, kind, stat), assigned in a fixed
    order, so a series keeps its colour when its neighbours come and go; open
    entity sets (players, classes) use Grafana's by-name palette for the same reason
  - 2 px lines, no fill except the one stacked panel, legends for >= 2 series
  - status colours only on stat tiles that carry their own label
"""

from __future__ import annotations

import json
import os
import sys

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "grafana", "dashboards")
DS = {"type": "prometheus", "uid": "armapunk-vm"}

# Dark-mode categorical slots (dataviz reference palette; validator: all six checks PASS).
BLUE, ORANGE, AQUA, YELLOW, MAGENTA, GREEN, VIOLET, RED = (
    "#3987e5", "#d95926", "#199e70", "#c98500", "#d55181", "#008300", "#9085e9", "#e66767")

# Entity -> colour, fixed. Order here is the assignment order; never cycle.
COLORS = {
    # sides
    "civ": BLUE, "west": ORANGE, "guer": AQUA,
    # entity kinds
    "units": BLUE, "vehicles": ORANGE, "dead": AQUA, "groups": YELLOW, "simple": MAGENTA,
    "mission_objects": GREEN, "weapon_holders": VIOLET, "mines": RED,
    # script kinds
    "spawn": BLUE, "execvm": ORANGE, "exec": AQUA, "fsm": YELLOW, "sqf active": MAGENTA,
    # pysqf stats
    "issued": BLUE, "completed_ok": AQUA, "completed_err": RED, "evicted": VIOLET, "refused": ORANGE,
    # fps
    "fps": BLUE, "fps min": ORANGE, "mean": BLUE, "min": ORANGE, "hc": AQUA,
    # db / self
    "db rtt": BLUE, "tick": ORANGE, "queue": BLUE, "dropped/s": RED, "failed posts/s": ORANGE,
    "total": BLUE, "_other": "#8a8a85",
    # vehicles
    "tank": BLUE, "car": ORANGE, "air": AQUA, "ship": YELLOW, "static": GREEN, "motorcycle": VIOLET, "land_other": RED, "thing": "#8a8a85", "other": MAGENTA,
    "server": BLUE, "player": AQUA, "empty": BLUE, "damaged": ORANGE, "destroyed": RED,
    # env
    "rain": BLUE, "overcast": ORANGE, "fog": AQUA, "sun": YELLOW,
    # states / duty
    "downed": ORANGE, "restrained": VIOLET, "in_vehicle": BLUE, "maxsec": BLUE, "trauma": AQUA,
    # host / procs
    "arma": BLUE, "pysqfd": AQUA, "postgres": YELLOW, "rx": BLUE, "tx": ORANGE,
    "used": ORANGE, "available": BLUE, "cpu": BLUE, "1": BLUE, "5": ORANGE, "15": AQUA,
    # pg
    "commit": BLUE, "rollback": RED, "inserted": BLUE, "updated": ORANGE, "deleted": RED, "hit ratio": BLUE,
    "active": BLUE, "idle": AQUA, "idle in transaction": ORANGE, "none": "#8a8a85",
    # econ
    "cash": ORANGE, "bank": BLUE, "gang bank": AQUA, "supply": VIOLET, "alive": BLUE, "24h": BLUE, "7d": ORANGE,
    "houses": BLUE, "listings": ORANGE, "bank funds": BLUE, "wanted bounty": ORANGE,
    # events
    "connect": BLUE, "disconnect": ORANGE, "death_player": RED, "death_ai": AQUA, "vehicle_destroyed": YELLOW,
    "pvp_kill": MAGENTA, "wanted": VIOLET, "restrain": GREEN, "robbery_bank": RED, "robbery_fed": ORANGE, "robbery_jewelry": YELLOW,
}

_pid = [0]


def _next_id() -> int:
    _pid[0] += 1
    return _pid[0]


def target(expr: str, legend: str, ref: str = "A", instant: bool = False, fmt: str = "time_series") -> dict:
    t = {"datasource": DS, "expr": expr, "legendFormat": legend, "refId": ref, "format": fmt}
    if instant:
        t["instant"] = True
        t["range"] = False
    return t


def override(name: str, color: str) -> dict:
    return {"matcher": {"id": "byName", "options": name},
            "properties": [{"id": "color", "value": {"mode": "fixed", "fixedColor": color}}]}


def timeseries(title: str, targets: list, grid: dict, unit: str = "short", colors: dict | None = None,
               by_name: bool = False, stacked: bool = False, decimals: int | None = None,
               min_zero: bool = True, description: str = "") -> dict:
    single = len(targets) == 1 and not by_name and "{{" not in targets[0]["legendFormat"]
    defaults = {
        "color": {"mode": "palette-classic-by-name" if by_name else "palette-classic"},
        "unit": unit,
        "custom": {
            "lineWidth": 2, "fillOpacity": 25 if stacked else 0, "showPoints": "never", "pointSize": 5,
            "spanNulls": 15000, "drawStyle": "line", "lineInterpolation": "linear",
            "stacking": {"mode": "normal" if stacked else "none", "group": "A"},
            "axisPlacement": "auto", "gradientMode": "none",
        },
    }
    if min_zero:
        defaults["min"] = 0
    if decimals is not None:
        defaults["decimals"] = decimals
    overrides = [override(n, c) for n, c in (colors or {}).items()]
    return {
        "id": _next_id(), "type": "timeseries", "title": title, "description": description,
        "datasource": DS, "gridPos": grid, "targets": targets,
        "fieldConfig": {"defaults": defaults, "overrides": overrides},
        "options": {
            "legend": {"displayMode": "list", "placement": "bottom", "showLegend": not single, "calcs": []},
            "tooltip": {"mode": "multi", "sort": "desc"},
        },
    }


def stat(title: str, expr: str, grid: dict, unit: str = "short", thresholds: list | None = None,
         mappings: list | None = None, decimals: int | None = 0, description: str = "") -> dict:
    steps = [{"color": "text", "value": None}]
    if thresholds:
        steps = thresholds
    defaults = {"unit": unit, "color": {"mode": "thresholds"},
                "thresholds": {"mode": "absolute", "steps": steps}}
    if decimals is not None:
        defaults["decimals"] = decimals
    if mappings:
        defaults["mappings"] = mappings
    return {
        "id": _next_id(), "type": "stat", "title": title, "description": description,
        "datasource": DS, "gridPos": grid,
        "targets": [target(expr, "", instant=False)],
        "fieldConfig": {"defaults": defaults, "overrides": []},
        "options": {"reduceOptions": {"calcs": ["lastNotNull"], "fields": "", "values": False},
                    "colorMode": "value", "graphMode": "area", "textMode": "value",
                    "justifyMode": "center", "orientation": "auto", "wideLayout": True},
    }


def bargauge(title: str, expr: str, legend: str, grid: dict, unit: str = "short", description: str = "") -> dict:
    return {
        "id": _next_id(), "type": "bargauge", "title": title, "description": description,
        "datasource": DS, "gridPos": grid,
        "targets": [target(expr, legend, instant=True)],
        "fieldConfig": {"defaults": {"unit": unit, "decimals": 0, "min": 0,
                                     "color": {"mode": "fixed", "fixedColor": BLUE}},
                        "overrides": []},
        "options": {"reduceOptions": {"calcs": ["lastNotNull"], "fields": "", "values": False},
                    "orientation": "horizontal", "displayMode": "basic", "showUnfilled": True,
                    "namePlacement": "left", "sizing": "auto", "valueMode": "color", "minVizHeight": 16},
    }


def clients_table(grid: dict) -> dict:
    cols = [("A", "ap_client_fps", "fps"), ("B", "ap_client_fps_min", "fps min"),
            ("C", "ap_player_ping_ms", "ping"), ("D", "ap_player_desync", "desync"),
            ("E", "ap_client_view_distance", "view dist"), ("F", "ap_client_near_objects", "near objs"),
            ("G", "ap_client_near_players", "near players"), ("H", "ap_client_near_vehicles", "near vehicles"),
            ("I", "ap_client_speed", "speed"), ("J", "ap_client_in_vehicle", "in vehicle"),
            ("K", "ap_client_build", "build"), ("L", "ap_player_session_s", "session")]
    targets = [target(m, "", ref=r, instant=True, fmt="table") for r, m, _ in cols]
    rename = {"Value #%s" % r: label for r, _, label in cols}
    rename.update({"name": "player", "machine": "machine", "uid": "uid"})
    exclude = {"Time": True, "__name__": True, "host": True}
    return {
        "id": _next_id(), "type": "table", "title": "Clients right now",
        "description": "One row per connected client (players and the headless client); values are the last beat, at most 30 s old.",
        "datasource": DS, "gridPos": grid, "targets": targets,
        "transformations": [
            {"id": "merge", "options": {}},
            {"id": "organize", "options": {"excludeByName": exclude, "renameByName": rename,
                                            "indexByName": {"player": 0, "machine": 1, "fps": 2, "fps min": 3, "ping": 4, "desync": 5,
                                                            "view dist": 6, "near objs": 7, "near players": 8, "near vehicles": 9,
                                                            "speed": 10, "in vehicle": 11, "session": 12, "build": 13, "uid": 14}}},
            {"id": "sortBy", "options": {"sort": [{"field": "fps", "desc": False}]}},
        ],
        "fieldConfig": {"defaults": {"custom": {"align": "auto", "cellOptions": {"type": "auto"}, "filterable": False},
                                     "decimals": 0},
                        "overrides": [
                            {"matcher": {"id": "byName", "options": "fps"},
                             "properties": [{"id": "custom.cellOptions", "value": {"type": "color-text"}},
                                            {"id": "color", "value": {"mode": "thresholds"}},
                                            {"id": "thresholds", "value": {"mode": "absolute", "steps": [
                                                {"color": "red", "value": None}, {"color": "orange", "value": 20},
                                                {"color": "green", "value": 40}]}}]},
                            {"matcher": {"id": "byName", "options": "session"},
                             "properties": [{"id": "unit", "value": "dtdurations"}]},
                            {"matcher": {"id": "byName", "options": "ping"},
                             "properties": [{"id": "unit", "value": "ms"}, {"id": "custom.cellOptions", "value": {"type": "color-text"}},
                                            {"id": "color", "value": {"mode": "thresholds"}},
                                            {"id": "thresholds", "value": {"mode": "absolute", "steps": [
                                                {"color": "green", "value": None}, {"color": "orange", "value": 120},
                                                {"color": "red", "value": 250}]}}]},
                            {"matcher": {"id": "byName", "options": "in vehicle"},
                             "properties": [{"id": "mappings", "value": [
                                 {"type": "value", "options": {"0": {"text": "on foot"}, "1": {"text": "vehicle"}}}]}]},
                        ]},
        "options": {"showHeader": True, "cellHeight": "sm", "footer": {"show": False, "reducer": ["sum"], "countRows": False}},
    }


def dashboard(uid: str, title: str, panels: list, description: str) -> dict:
    return {
        "uid": uid, "title": title, "description": description, "tags": ["armapunk", "telemetry"],
        "editable": True, "graphTooltip": 1, "refresh": "5s", "schemaVersion": 39, "version": 1,
        "time": {"from": "now-1h", "to": "now"}, "timezone": "browser", "timepicker": {},
        "templating": {"list": []}, "annotations": {"list": []}, "links": [
            {"title": "Server", "type": "link", "url": "/d/ap-server", "icon": "dashboard"},
            {"title": "Clients", "type": "link", "url": "/d/ap-clients", "icon": "dashboard"},
            {"title": "Entities", "type": "link", "url": "/d/ap-entities", "icon": "dashboard"},
            {"title": "Host", "type": "link", "url": "/d/ap-host", "icon": "dashboard"},
            {"title": "Database", "type": "link", "url": "/d/ap-db", "icon": "dashboard"},
            {"title": "Economy", "type": "link", "url": "/d/ap-econ", "icon": "dashboard"},
            {"title": "Events", "type": "link", "url": "/d/ap-events", "icon": "dashboard"},
        ],
        "panels": panels,
    }


def g(x: int, y: int, w: int, h: int) -> dict:
    return {"x": x, "y": y, "w": w, "h": h}


FPS_STEPS = [{"color": "red", "value": None}, {"color": "orange", "value": 15}, {"color": "green", "value": 30}]
RTT_STEPS = [{"color": "green", "value": None}, {"color": "orange", "value": 50}, {"color": "red", "value": 250}]
ONOFF = [{"type": "value", "options": {"0": {"text": "OFFLINE", "color": "red"}, "1": {"text": "ONLINE", "color": "green"}}}]


def server_dashboard() -> dict:
    p = [
        stat("Server FPS", "ap_server_fps", g(0, 0, 4, 4), thresholds=FPS_STEPS),
        stat("Players", "ap_players_total", g(4, 0, 4, 4)),
        stat("Headless client", "ap_hc_online", g(8, 0, 4, 4), mappings=ONOFF,
             thresholds=[{"color": "red", "value": None}, {"color": "green", "value": 1}]),
        stat("Mission objects", 'ap_entities{kind="mission_objects"}', g(12, 0, 4, 4)),
        stat("DB round trip", "ap_db_rtt_ms", g(16, 0, 4, 4), unit="ms", thresholds=RTT_STEPS),
        stat("Process uptime", "ap_process_uptime_s", g(20, 0, 4, 4), unit="dtdurations", decimals=None),

        timeseries("Server FPS", [target("ap_server_fps", "fps"), target("ap_server_fps_min", "fps min", "B")],
                   g(0, 4, 12, 8), colors={"fps": BLUE, "fps min": ORANGE},
                   description="diag_fps and diag_fpsMin on the dedicated server, every 5 s."),
        timeseries("Players by side", [target("ap_players", "{{side}}")], g(12, 4, 12, 8),
                   colors={k: COLORS[k] for k in ("civ", "west", "guer")}, decimals=0),

        timeseries("Entities by kind", [target("ap_entities", "{{kind}}")], g(0, 12, 12, 8),
                   colors={k: COLORS[k] for k in ("units", "vehicles", "dead", "groups", "simple",
                                                  "mission_objects", "weapon_holders", "mines")}, decimals=0,
                   description="Engine-wide counts. mission_objects is everything the mission created; the census dashboard breaks it down by class."),
        timeseries("Scripts", [target("ap_scripts", "{{kind}}"), target("ap_sqf_scripts_active", "sqf active", "B")],
                   g(12, 12, 12, 8), colors={k: COLORS[k] for k in ("spawn", "execvm", "exec", "fsm", "sqf active")}, decimals=0,
                   description="diag_activeScripts by kind, plus the count of diag_activeSQFScripts."),

        timeseries("Scheduler jobs: last run (ms), top 10", [target("topk(10, ap_sched_last_ms)", "{{job}}")],
                   g(0, 20, 12, 8), unit="ms", by_name=True,
                   description="Wall time of each job's last run on the server scheduler wheel."),
        timeseries("Scheduler jobs: consecutive errors", [target("ap_sched_errors > 0", "{{job}}")],
                   g(12, 20, 12, 8), by_name=True, decimals=0,
                   description="Only jobs currently in an error streak appear; the wheel disables a job after 5."),

        timeseries("pysqf tickets per second",
                   [target('rate(ap_pysqf{stat="issued"}[1m])', "issued"),
                    target('rate(ap_pysqf{stat="completed_ok"}[1m])', "completed_ok", "B"),
                    target('rate(ap_pysqf{stat="completed_err"}[1m])', "completed_err", "C"),
                    target('rate(ap_pysqf{stat="refused"}[1m])', "refused", "D"),
                    target('sum(rate(ap_pysqf{stat=~"evicted_.*"}[1m]))', "evicted", "E")],
                   g(0, 28, 12, 8), unit="ops", decimals=2,
                   colors={k: COLORS[k] for k in ("issued", "completed_ok", "completed_err", "refused", "evicted")},
                   description="Extension call rate as seen by the C core. Any evicted or refused rate above zero is a leak or a wedge."),
        timeseries("DB round trip and collector cost",
                   [target("ap_db_rtt_ms", "db rtt"), target("ap_telemetry_tick_ms", "tick", "B")],
                   g(12, 28, 12, 8), unit="ms", colors={"db rtt": BLUE, "tick": ORANGE},
                   description="SELECT 1 through the whole DB path, and how long the 5 s collector job itself took."),

        timeseries("Frame time", [target("ap_frame_ms", "server frame ms")], g(0, 42, 12, 8), unit="ms", decimals=1,
                   description="diag_deltaTime on the server; the inverse of FPS, but it shows hitches that a 5 s FPS average hides."),
        timeseries("Vehicles by family", [target("ap_vehicles", "{{family}}")], g(12, 42, 12, 8), decimals=0,
                   colors={k: COLORS[k] for k in ("tank", "car", "air", "ship", "static", "motorcycle", "land_other", "thing", "other")}),
        timeseries("Vehicles by owner and state",
                   [target("ap_vehicles_owner", "{{owner}}"), target("ap_vehicles_state", "{{state}}", "B")],
                   g(0, 50, 12, 8), decimals=0, colors={k: COLORS[k] for k in ("server", "hc", "player", "empty", "damaged", "destroyed")},
                   description="Who simulates each vehicle (server / headless client / a player) and how many are empty, damaged (>50 %) or wrecks."),
        timeseries("Leak detectors",
                   [target("ap_groups_empty", "empty groups"), target("ap_markers", "markers", "B"),
                    target("ap_effects", "{{kind}} sources", "C"), target("ap_weapon_holders", "{{kind}} holders", "D")],
                   g(12, 50, 12, 8), decimals=0, by_name=True,
                   description="Numbers that should stay flat. A climbing line is a script that creates and never deletes."),
        timeseries("Units", [target("ap_units", "{{kind}}"), target("ap_units_ai", "ai {{side}}", "B")], g(0, 58, 12, 8), decimals=0, by_name=True),
        timeseries("Weather (0-1) and sun",
                   [target("ap_env_rain", "rain"), target("ap_env_overcast", "overcast", "B"), target("ap_env_fog", "fog", "C"),
                    target("ap_env_sun", "sun", "D")],
                   g(12, 58, 6, 8), decimals=2, colors={k: COLORS[k] for k in ("rain", "overcast", "fog", "sun")},
                   description="Overlay this on client FPS: rain and night cost frames on every client at once."),
        timeseries("Wind", [target("ap_env_wind", "wind m/s")], g(18, 58, 6, 8), unit="velocityms", decimals=1),
        timeseries("Active SQF scripts by name, top 10", [target('topk(10, ap_sqf_scripts{name!="_other"})', "{{name}}")],
                   g(0, 66, 12, 8), decimals=0, by_name=True,
                   description="diag_activeSQFScripts grouped by script name, every 60 s. One name with hundreds of copies is a leak."),
        timeseries("Game state",
                   [target("ap_wanted", "wanted"), target("ap_players_state", "{{state}}", "B"),
                    target("ap_duty", "{{faction}}", "C"), target("ap_event_queue", "event queue", "D")],
                   g(12, 66, 12, 8), decimals=0, by_name=True),
        timeseries("Events per minute", [target("rate(ap_events_total[5m]) * 60", "{{type}}")], g(0, 74, 24, 8), decimals=2,
                   colors={k: COLORS[k] for k in ("connect", "disconnect", "death_player", "death_ai", "vehicle_destroyed", "pvp_kill",
                                                  "wanted", "restrain", "robbery_bank", "robbery_fed", "robbery_jewelry")},
                   description="Counters since boot turned into rates: connects, deaths, PvP kills, wanted charges, restraints, robberies."),
        timeseries("Telemetry pipeline",
                   [target("ap_telemetry_queue_lines", "queue"),
                    target("rate(ap_telemetry_dropped_lines_total[5m])", "dropped/s", "B"),
                    target("rate(ap_telemetry_failed_posts_total[5m])", "failed posts/s", "C")],
                   g(0, 82, 24, 6), decimals=2, colors={"queue": BLUE, "dropped/s": RED, "failed posts/s": ORANGE},
                   description="The daemon module's own health. Sustained drops or failed posts mean VictoriaMetrics is unreachable."),
    ]
    return dashboard("ap-server", "Armapunk Server", p, "Dedicated server health: FPS, players, entities, scripts, scheduler, database.")


def clients_dashboard() -> dict:
    p = [
        timeseries("Client FPS by player", [target('ap_client_fps{machine="client"}', "{{name}}")],
                   g(0, 0, 24, 10), by_name=True, decimals=0,
                   description="Each connected player's diag_fps, reported every 10 s. Colour follows the player, not the position in the list."),
        clients_table(g(0, 10, 24, 10)),
        timeseries("Fleet FPS",
                   [target('avg(ap_client_fps{machine="client"})', "mean"),
                    target('min(ap_client_fps{machine="client"})', "min", "B"),
                    target('ap_client_fps{machine="hc"}', "hc", "C")],
                   g(0, 20, 12, 8), colors={"mean": BLUE, "min": ORANGE, "hc": AQUA}, decimals=0,
                   description="Mean and worst client FPS across everyone connected, plus the headless client."),
        timeseries("Objects within 300 m, by player", [target('ap_client_near_objects{machine="client"}', "{{name}}")],
                   g(12, 20, 12, 8), by_name=True, decimals=0,
                   description="count (player nearObjects 300) on each client -- a crowded spot shows here before it shows in FPS."),
        timeseries("Ping by player", [target('ap_player_ping_ms{machine="client"}', "{{name}}")], g(0, 28, 12, 8), unit="ms", by_name=True, decimals=0,
                   description="Server-side view (getUserInfo), so it needs no cooperation from the client."),
        timeseries("Desync by player", [target('ap_player_desync{machine="client"}', "{{name}}")], g(12, 28, 12, 8), by_name=True, decimals=0),
        timeseries("Bandwidth by player", [target('ap_player_bandwidth{machine="client"}', "{{name}}")], g(0, 36, 12, 8), by_name=True, decimals=0),
        timeseries("Frame time by player", [target('ap_client_frame_ms{machine="client"}', "{{name}}")], g(12, 36, 12, 8), unit="ms", by_name=True, decimals=1),
        timeseries("Client script load", [target('ap_client_scripts_spawn{machine="client"}', "{{name}} spawn"),
                                          target('ap_client_displays{machine="client"}', "{{name}} displays", "B")],
                   g(0, 44, 12, 8), by_name=True, decimals=0,
                   description="Spawned scripts and open displays per client; both should be flat while idle."),
        timeseries("Players near each player", [target('ap_client_near_players{machine="client"}', "{{name}}")], g(12, 44, 12, 8), by_name=True, decimals=0),
    ]
    return dashboard("ap-clients", "Armapunk Clients", p, "Every connected player's FPS, view distance and surroundings.")


def entities_dashboard() -> dict:
    p = [
        stat("Mission objects", "ap_objects_total", g(0, 0, 4, 4)),
        stat("Census cost", "ap_census_ms", g(4, 0, 4, 4), unit="ms",
             thresholds=[{"color": "green", "value": None}, {"color": "orange", "value": 250}, {"color": "red", "value": 1000}]),
        stat("Vehicles", 'ap_entities{kind="vehicles"}', g(8, 0, 4, 4)),
        stat("Units", 'ap_entities{kind="units"}', g(12, 0, 4, 4)),
        stat("Dead", 'ap_entities{kind="dead"}', g(16, 0, 4, 4)),
        stat("Weapon holders", 'ap_entities{kind="weapon_holders"}', g(20, 0, 4, 4)),
        timeseries("Top 8 classes over time", [target('topk(8, ap_objects{class!="_other"})', "{{class}}")],
                   g(0, 4, 24, 12), by_name=True, decimals=0,
                   description="typeOf histogram over allMissionObjects, every 60 s, top classes. A class that climbs on its own is the '1200 rockets' signal."),
        bargauge("Top 20 classes right now", 'topk(20, ap_objects{class!="_other"})', "{{class}}", g(0, 16, 12, 12)),
        timeseries("Entities by kind", [target("ap_entities", "{{kind}}")], g(12, 16, 12, 12),
                   colors={k: COLORS[k] for k in ("units", "vehicles", "dead", "groups", "simple",
                                                  "mission_objects", "weapon_holders", "mines")}, decimals=0),
    ]
    return dashboard("ap-entities", "Armapunk Entities", p, "What the mission has spawned, by class and by kind.")


def host_dashboard() -> dict:
    p = [
        stat("CPU", "ap_host_cpu_pct", g(0, 0, 4, 4), unit="percent",
             thresholds=[{"color": "green", "value": None}, {"color": "orange", "value": 70}, {"color": "red", "value": 90}]),
        stat("Load (1 m)", 'ap_host_load{period="1"}', g(4, 0, 4, 4), decimals=2),
        stat("Memory used", 'ap_host_mem_bytes{kind="used"}', g(8, 0, 4, 4), unit="bytes"),
        stat("Free on /home", 'ap_host_disk_bytes{path="/home",kind="free"}', g(12, 0, 4, 4), unit="bytes"),
        stat("Arma RSS", 'ap_proc_rss_bytes{proc="arma"}', g(16, 0, 4, 4), unit="bytes"),
        stat("Host uptime", "ap_host_uptime_s", g(20, 0, 4, 4), unit="dtdurations", decimals=None),
        timeseries("CPU: host and processes",
                   [target("ap_host_cpu_pct", "host"), target("ap_proc_cpu_pct", "{{proc}}", "B")],
                   g(0, 4, 12, 8), unit="percent", decimals=1, by_name=True,
                   description="Host CPU % (all cores) and each tracked process's share. Arma is single-thread-bound: 100 % of one core on a 12-core box reads as ~8."),
        timeseries("Memory", [target('ap_host_mem_bytes{kind=~"used|available"}', "{{kind}}"),
                              target("ap_proc_rss_bytes", "{{proc}} rss", "B")],
                   g(12, 4, 12, 8), unit="bytes", by_name=True),
        timeseries("Network", [target("rate(ap_host_net_bytes_total[1m])", "{{dir}}")], g(0, 12, 12, 8), unit="Bps",
                   colors={"rx": BLUE, "tx": ORANGE}, decimals=0),
        timeseries("Load", [target("ap_host_load", "{{period}} m")], g(12, 12, 12, 8), decimals=2, by_name=True),
        timeseries("Threads and file descriptors", [target("ap_proc_threads", "{{proc}} threads"), target("ap_proc_fds", "{{proc}} fds", "B")],
                   g(0, 20, 12, 8), decimals=0, by_name=True),
        timeseries("Process uptime", [target("ap_proc_uptime_s", "{{proc}}")], g(12, 20, 12, 8), unit="dtdurations", by_name=True,
                   description="A sawtooth is a restart. arma drops every soft/hard restart; pysqfd should not."),
    ]
    return dashboard("ap-host", "Armapunk Host", p, "The .96 box and its processes: CPU, memory, network, arma / hc / pysqfd / postgres.")


def db_dashboard() -> dict:
    p = [
        stat("Backends", "ap_pg_backends", g(0, 0, 4, 4)),
        stat("Database size", "ap_pg_db_bytes", g(4, 0, 4, 4), unit="bytes"),
        stat("Deadlocks", "ap_pg_deadlocks_total", g(8, 0, 4, 4),
             thresholds=[{"color": "green", "value": None}, {"color": "red", "value": 1}]),
        stat("Game DB round trip", "ap_db_rtt_ms", g(12, 0, 4, 4), unit="ms", thresholds=RTT_STEPS),
        stat("log rows", 'ap_pg_table_rows{table="log"}', g(16, 0, 4, 4)),
        stat("players rows", 'ap_pg_table_rows{table="players"}', g(20, 0, 4, 4)),
        timeseries("Transactions per second", [target("rate(ap_pg_xact_commit_total[1m])", "commit"), target("rate(ap_pg_xact_rollback_total[1m])", "rollback", "B")],
                   g(0, 4, 12, 8), unit="ops", decimals=2, colors={"commit": BLUE, "rollback": RED}),
        timeseries("Buffer cache hit ratio", [target("rate(ap_pg_blks_hit_total[5m]) / clamp_min(rate(ap_pg_blks_hit_total[5m]) + rate(ap_pg_blks_read_total[5m]), 1)", "hit ratio")],
                   g(12, 4, 12, 8), unit="percentunit", decimals=3, min_zero=True,
                   description="Below ~0.99 the working set no longer fits shared_buffers."),
        timeseries("Tuples per second", [target("rate(ap_pg_tup_inserted_total[1m])", "inserted"), target("rate(ap_pg_tup_updated_total[1m])", "updated", "B"),
                                         target("rate(ap_pg_tup_deleted_total[1m])", "deleted", "C")],
                   g(0, 12, 12, 8), unit="ops", decimals=2, colors={"inserted": BLUE, "updated": ORANGE, "deleted": RED}),
        timeseries("Connections by state", [target("ap_pg_activity", "{{state}}")], g(12, 12, 12, 8), decimals=0, by_name=True),
        timeseries("Table rows (except log)", [target('ap_pg_table_rows{table!="log"}', "{{table}}")], g(0, 20, 12, 8), decimals=0, by_name=True),
        timeseries("log table rows", [target('ap_pg_table_rows{table="log"}', "log")], g(12, 20, 12, 8), decimals=0,
                   description="The audit log only grows. Its slope is the write load the game puts on the database."),
        timeseries("Dead rows (vacuum pressure)", [target("ap_pg_table_dead_rows", "{{table}}")], g(0, 28, 12, 8), decimals=0, by_name=True),
        timeseries("Stats query cost", [target("ap_pg_query_ms", "pg stats"), target("ap_econ_query_ms", "economy", "B"), target("ap_db_rtt_ms", "game rtt", "C")],
                   g(12, 28, 12, 8), unit="ms", decimals=1, by_name=True),
    ]
    return dashboard("ap-db", "Armapunk Database", p, "PostgreSQL as the game sees it: throughput, cache, connections, table growth.")


def econ_dashboard() -> dict:
    p = [
        stat("Money supply", "ap_econ_money_supply", g(0, 0, 4, 4), unit="currencyUSD", decimals=0,
             description="cash + bank + gang banks. A jump nobody can explain is a dupe."),
        stat("Cash", "ap_econ_cash_total", g(4, 0, 4, 4), unit="currencyUSD", decimals=0),
        stat("Bank", "ap_econ_bank_total", g(8, 0, 4, 4), unit="currencyUSD", decimals=0),
        stat("Gang banks", "ap_econ_gang_bank_total", g(12, 0, 4, 4), unit="currencyUSD", decimals=0),
        stat("Players (registered)", "ap_econ_players_total", g(16, 0, 4, 4)),
        stat("Active 24 h", "ap_econ_players_active_24h", g(20, 0, 4, 4)),
        timeseries("Money supply", [target("ap_econ_money_supply", "supply"), target("ap_econ_cash_total", "cash", "B"),
                                    target("ap_econ_bank_total", "bank", "C"), target("ap_econ_gang_bank_total", "gang bank", "D")],
                   g(0, 4, 24, 8), unit="currencyUSD", decimals=0, colors={"supply": VIOLET, "cash": ORANGE, "bank": BLUE, "gang bank": AQUA},
                   description="Sampled every 60 s from the database. Watch the supply line: legitimate play moves it slowly."),
        timeseries("Money supply change per hour", [target("delta(ap_econ_money_supply[1h])", "supply / h")], g(0, 12, 12, 8), unit="currencyUSD", decimals=0,
                   description="Positive = money entering the economy (payouts, sales to NPCs); negative = money leaving (purchases, fines)."),
        timeseries("Bank funds and wanted bounty", [target("ap_bank_funds", "bank funds"), target("ap_wanted_bounty_total", "wanted bounty", "B")],
                   g(12, 12, 12, 8), unit="currencyUSD", decimals=0, colors={"bank funds": BLUE, "wanted bounty": ORANGE}),
        timeseries("Players", [target("ap_econ_players_active_24h", "24h"), target("ap_econ_players_active_7d", "7d", "B"),
                               target("ap_players_total", "online", "C")],
                   g(0, 20, 12, 8), decimals=0, colors={"24h": BLUE, "7d": ORANGE, "online": AQUA}),
        timeseries("Vehicles in the database", [target("ap_econ_vehicles", "{{state}}")], g(12, 20, 12, 8), decimals=0, by_name=True),
        timeseries("Houses and exchange listings", [target("ap_econ_houses", "houses"), target("ap_econ_exchange_listings", "listings", "B")],
                   g(0, 28, 12, 8), decimals=0, colors={"houses": BLUE, "listings": ORANGE}),
        timeseries("Gangs", [target("ap_econ_gangs", "gangs")], g(12, 28, 12, 8), decimals=0),
    ]
    return dashboard("ap-econ", "Armapunk Economy", p, "Money supply and ownership from the database, sampled every minute.")


def events_dashboard() -> dict:
    def inc(t: str) -> str:
        return 'increase(ap_events_total{type="%s"}[1h])' % t
    p = [
        stat("Connects (1 h)", inc("connect"), g(0, 0, 4, 4)),
        stat("Disconnects (1 h)", inc("disconnect"), g(4, 0, 4, 4)),
        stat("Player deaths (1 h)", inc("death_player"), g(8, 0, 4, 4)),
        stat("PvP kills (1 h)", inc("pvp_kill"), g(12, 0, 4, 4)),
        stat("Wanted charges (1 h)", inc("wanted"), g(16, 0, 4, 4)),
        stat("Robberies (1 h)", 'sum(increase(ap_events_total{type=~"robbery_.*"}[1h]))', g(20, 0, 4, 4)),
        timeseries("Events per minute, all types", [target("rate(ap_events_total[5m]) * 60", "{{type}}")], g(0, 4, 24, 10), decimals=2,
                   colors={k: COLORS[k] for k in ("connect", "disconnect", "death_player", "death_ai", "vehicle_destroyed", "pvp_kill",
                                                  "wanted", "restrain", "robbery_bank", "robbery_fed", "robbery_jewelry")}),
        timeseries("Connections", [target('rate(ap_events_total{type="connect"}[5m]) * 60', "connect"),
                                   target('rate(ap_events_total{type="disconnect"}[5m]) * 60', "disconnect", "B"),
                                   target("ap_players_total", "online", "C")],
                   g(0, 14, 12, 8), decimals=2, colors={"connect": BLUE, "disconnect": ORANGE, "online": AQUA}),
        timeseries("Violence", [target('rate(ap_events_total{type="death_player"}[5m]) * 60', "death_player"),
                                target('rate(ap_events_total{type="pvp_kill"}[5m]) * 60', "pvp_kill", "B"),
                                target('rate(ap_events_total{type="death_ai"}[5m]) * 60', "death_ai", "C"),
                                target('rate(ap_events_total{type="vehicle_destroyed"}[5m]) * 60', "vehicle_destroyed", "D")],
                   g(12, 14, 12, 8), decimals=2, colors={"death_player": RED, "pvp_kill": MAGENTA, "death_ai": AQUA, "vehicle_destroyed": YELLOW}),
        timeseries("Crime", [target('rate(ap_events_total{type="wanted"}[5m]) * 60', "wanted"),
                             target('rate(ap_events_total{type="restrain"}[5m]) * 60', "restrain", "B"),
                             target('rate(ap_events_total{type=~"robbery_.*"}[5m]) * 60', "{{type}}", "C")],
                   g(0, 22, 12, 8), decimals=2, by_name=True),
        timeseries("Session length", [target('ap_player_session_s{machine="client"}', "{{name}}")], g(12, 22, 12, 8), unit="dtdurations", by_name=True),
    ]
    return dashboard("ap-events", "Armapunk Events", p, "What happened, as rates: connects, deaths, PvP, crime, robberies.")


def _validate(d: dict) -> None:
    ids = [p["id"] for p in d["panels"]]
    assert len(ids) == len(set(ids)), "duplicate panel id in %s" % d["uid"]
    for p in d["panels"]:
        gp = p["gridPos"]
        assert 0 <= gp["x"] and gp["x"] + gp["w"] <= 24, "panel %s off-grid in %s" % (p["title"], d["uid"])
        for t in p["targets"]:
            assert t["expr"], "empty expr in %s" % p["title"]


def render() -> dict:
    _pid[0] = 0
    out = {}
    for build in (server_dashboard, clients_dashboard, entities_dashboard, host_dashboard, db_dashboard, econ_dashboard, events_dashboard):
        d = build()
        _validate(d)
        out["%s.json" % d["uid"].replace("ap-", "armapunk-")] = json.dumps(d, indent=2, sort_keys=True) + "\n"
    return out


def main(argv: list) -> int:
    files = render()
    files2 = render()
    assert files == files2, "generator is not deterministic"
    if "--check" in argv:
        stale = [n for n, body in files.items()
                 if not os.path.exists(os.path.join(OUT_DIR, n)) or open(os.path.join(OUT_DIR, n)).read() != body]
        if stale:
            print("stale dashboards: %s -- run gen_dashboards.py" % ", ".join(stale))
            return 1
        print("dashboards up to date (%d files)" % len(files))
        return 0
    os.makedirs(OUT_DIR, exist_ok=True)
    for n, body in files.items():
        with open(os.path.join(OUT_DIR, n), "w") as f:
            f.write(body)
        print("wrote %s (%d bytes)" % (n, len(body)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
