"""Smoke: push a full synthetic sample set through the real module, then run every dashboard
expression through Grafana's datasource proxy and report PromQL errors / empty results."""
import base64, glob, json, os, sys, time, urllib.request
sys.path.insert(0, os.getcwd())
from tools.pysqf_modules import telemetry as t

VM = os.environ.get("SMOKE_VM", "http://127.0.0.1:18428"); GF = os.environ.get("SMOKE_GF", "http://127.0.0.1:13000"); AUTH = "Basic " + base64.b64encode(b"admin:smoke").decode()

def samples(k):
    s = [["ap_server_fps",[["machine","server"]],40+k],["ap_server_fps_min",[["machine","server"]],20+k],
         ["ap_players_total",[],3],["ap_hc_online",[],1],["ap_db_rtt_ms",[],12+k],["ap_process_uptime_s",[],3600+k*60],
         ["ap_mission_time_s",[],100+k],["ap_server_time_s",[],100+k],["ap_sqf_scripts_active",[],30],["ap_telemetry_tick_ms",[],4],
         ["ap_objects_total",[],9000],["ap_census_ms",[],120],["ap_sched_jobs_enabled",[],22]]
    for side,n in (("civ",2),("west",1),("guer",0)): s.append(["ap_players",[["side",side]],n])
    for kind,n in (("units",40),("vehicles",60),("dead",2),("groups",9),("simple",300),("mission_objects",9000),("weapon_holders",5),("mines",0)): s.append(["ap_entities",[["kind",kind]],n+k])
    for kind,n in (("spawn",20),("execvm",1),("exec",0),("fsm",3)): s.append(["ap_scripts",[["kind",kind]],n])
    for job in ("telemetryServer","marketTick","dutySweep"): s += [["ap_sched_last_ms",[["job",job]],3+k],["ap_sched_errors",[["job",job]],1 if job=="dutySweep" else 0]]
    for st,n in (("issued",1000),("completed_ok",990),("completed_err",2),("pending",1),("refused",0),("dropped_late",0),("evicted_pending",0),("evicted_complete",1)): s.append(["ap_pysqf",[["stat",st]],n+k*10])
    for cls,n in (("Land_Cargo20_blue_F",500),("B_MRAP_01_F",30),("_other",8000),("Rocket_MLRS",1200)): s.append(["ap_objects",[["class",cls]],n+k])
    for uid,name,m in (("1","Alice","client"),("2","Bob \"B\"","client"),("hc","HC","hc")):
        l=[["machine",m],["uid",uid],["name",name]]
        s += [["ap_client_fps",l,50+k],["ap_client_fps_min",l,25],["ap_client_view_distance",l,2500],["ap_client_near_objects",l,300+k],["ap_client_in_vehicle",l,1 if uid=="1" else 0]]
        # phase 2 client + network
        for n,v in (("ap_client_frame_ms",18.5),("ap_client_object_view_distance",1600),("ap_client_terrain_grid",25),("ap_client_shadow_distance",100),
                    ("ap_client_near_players",2),("ap_client_near_vehicles",7),("ap_client_speed",42),("ap_client_pos_x",7263),("ap_client_pos_y",7931),
                    ("ap_client_displays",3),("ap_client_scripts_spawn",40+k),("ap_client_scripts_execvm",2),("ap_client_in_menu",0),("ap_client_alive",1),
                    ("ap_client_res_w",2560),("ap_client_res_h",1440),("ap_client_fov",0.75),("ap_client_build",154045),
                    ("ap_player_ping_ms",35+k),("ap_player_bandwidth",120000),("ap_player_desync",0),("ap_player_client_state",10),("ap_player_admin",0),("ap_player_session_s",600+k*60)):
            s.append([n,l,v])
        s.append(["ap_client_info", l+[["branch","main"],["lang","English"]], 1])
    # phase 2 server
    s += [["ap_frame_ms",[["machine","server"]],20+k],["ap_frame_no",[["machine","server"]],100000+k],["ap_mission_fsms",[],2],
          ["ap_groups_empty",[],1],["ap_markers",[],120],["ap_wanted",[],3],["ap_wanted_bounty_total",[],45000],["ap_bank_funds",[],1e7],["ap_event_queue",[],1],
          ["ap_env_daytime",[],13.5],["ap_env_overcast",[],0.3],["ap_env_rain",[],0.1],["ap_env_fog",[],0.05],["ap_env_wind",[],4.2],["ap_env_sun",[],1],["ap_env_time_multiplier",[],1],
          ["ap_pysqf_ready",[],1],["ap_telemetry_beats_total",[],10*k],["ap_telemetry_beats_unmatched_total",[],0]]
    for kind,n in (("player",3),("ai",40)): s.append(["ap_units",[["kind",kind]],n])
    for side,n in (("west",5),("east",0),("guer",10),("civ",25)): s.append(["ap_units_ai",[["side",side]],n])
    for kind,n in (("men",2),("vehicles",1)): s.append(["ap_dead",[["kind",kind]],n])
    for fam,n in (("tank",0),("car",40),("air",5),("ship",3),("other",2)): s.append(["ap_vehicles",[["family",fam]],n])
    for o,n in (("server",30),("hc",10),("player",10)): s.append(["ap_vehicles_owner",[["owner",o]],n])
    for st,n in (("empty",35),("damaged",2),("destroyed",1)): s.append(["ap_vehicles_state",[["state",st]],n])
    for kind,n in (("particle",4),("light",12),("sound",1)): s.append(["ap_effects",[["kind",kind]],n])
    for kind,n in (("ground",3),("simulated",2)): s.append(["ap_weapon_holders",[["kind",kind]],n])
    for st,n in (("downed",0),("restrained",1),("in_vehicle",1),("dead",0)): s.append(["ap_players_state",[["state",st]],n])
    for f,n in (("maxsec",1),("trauma",0)): s.append(["ap_duty",[["faction",f]],n])
    for t,n in (("connect",5),("disconnect",4),("death_player",2),("death_ai",9),("vehicle_destroyed",1),("pvp_kill",1),("wanted",6),("restrain",2),("robbery_bank",1),("robbery_fed",0),("robbery_jewelry",1)):
        s.append(["ap_events_total",[["type",t]],n+k*2])
    for nm,n in (("fn_mapTick.sqf",12),("fn_scheduler.sqf",1),("fn_telemetry.sqf",1),("_other",30)): s.append(["ap_sqf_scripts",[["name",nm]],n])
    # phase 2 daemon collectors
    s += [["ap_host_cpu_pct",[],12.5+k],["ap_host_uptime_s",[],86400+k*60],["ap_telemetry_collector_errors_total",[["collector","host"]],0],
          ["ap_host_net_bytes_total",[["dir","rx"]],10**9+k*10**6],["ap_host_net_bytes_total",[["dir","tx"]],5*10**8+k*10**6]]
    for per,v in (("1",0.5),("5",0.6),("15",0.7)): s.append(["ap_host_load",[["period",per]],v])
    for kind,v in (("total",12*2**30),("used",5*2**30),("free",4*2**30),("available",7*2**30),("cached",2*2**30)): s.append(["ap_host_mem_bytes",[["kind",kind]],v])
    for kind,v in (("total",2**31),("used",0)): s.append(["ap_host_swap_bytes",[["kind",kind]],v])
    for kind,v in (("total",900*2**30),("free",850*2**30)): s.append(["ap_host_disk_bytes",[["path","/home"],["kind",kind]],v])
    for pr in ("arma","hc","pysqfd","postgres"):
        l=[["proc",pr]]
        s += [["ap_proc_running",l,1],["ap_proc_count",l,1],["ap_proc_rss_bytes",l,3*2**30],["ap_proc_cpu_pct",l,8.0+k],["ap_proc_threads",l,40],["ap_proc_fds",l,200],["ap_proc_uptime_s",l,3600+k*60]]
    s += [["ap_pg_backends",[],5],["ap_pg_db_bytes",[],2*2**30],["ap_pg_query_ms",[],3.2],["ap_econ_query_ms",[],1.1]]
    for c in ("xact_commit","xact_rollback","blks_read","blks_hit","tup_returned","tup_fetched","tup_inserted","tup_updated","tup_deleted","deadlocks","temp_bytes"):
        s.append(["ap_pg_%s_total"%c,[],1000+k*50])
    for st,n in (("active",1),("idle",4),("none",0)): s.append(["ap_pg_activity",[["state",st]],n])
    for t,n in (("players",570),("vehicles",800),("houses",120),("log",500000+k*100),("map_objects",13877)):
        s += [["ap_pg_table_rows",[["table",t]],n],["ap_pg_table_dead_rows",[["table",t]],n//10]]
    s += [["ap_econ_players_total",[],570],["ap_econ_players_active_24h",[],3],["ap_econ_players_active_7d",[],20],["ap_econ_cash_total",[],5e6],["ap_econ_bank_total",[],4.8e9],
          ["ap_econ_gangs",[],12],["ap_econ_gang_bank_total",[],4.9e8],["ap_econ_money_supply",[],5e6+4.8e9+4.9e8],["ap_econ_houses",[],120],["ap_econ_exchange_listings",[],30]]
    for st,n in (("total",800),("alive",700),("active",50)): s.append(["ap_econ_vehicles",[["state",st]],n])
    return s

base = int(time.time()*1000)
for k, off in ((0,-90000),(1,-45000),(2,0)):
    t._now_ms = lambda off=off: base+off
    t.push(samples(k)); st = t.flush()
    assert st["failed_posts"]==0 and st["bad_samples"]==0, st
print("pushed 3 rounds, sent_lines", st["sent_lines"])
time.sleep(3)

def q(expr, instant):
    body = {"queries":[{"refId":"A","datasource":{"uid":"armapunk-vm"},"expr":expr,"instant":instant,"range":not instant,"format":"time_series","intervalMs":5000,"maxDataPoints":500}],"from":str(base-300000),"to":str(base+1000)}
    req = urllib.request.Request(GF+"/api/ds/query", data=json.dumps(body).encode(), headers={"Content-Type":"application/json","Authorization":AUTH})
    try:
        with urllib.request.urlopen(req, timeout=10) as r: d=json.load(r)
    except urllib.error.HTTPError as e:
        return "HTTP %s %s" % (e.code, e.read()[:200])
    a = d["results"]["A"]
    if "error" in a: return "ERROR " + a["error"]
    fr = a.get("frames", [])
    n = sum(len(f["data"]["values"][0]) for f in fr if f["data"]["values"])
    return "ok frames=%d points=%d" % (len(fr), n)

bad = 0
for f in sorted(glob.glob("deploy/telemetry/grafana/dashboards/*.json")):
    d = json.load(open(f))
    for p in d["panels"]:
        for tg in p["targets"]:
            res = q(tg["expr"], bool(tg.get("instant")))
            flag = "" if res.startswith("ok") and "points=0" not in res else "  <-- CHECK"
            if flag: bad += 1
            print("%-22s %-45s %-60s %s%s" % (d["uid"], p["title"][:44], tg["expr"][:60], res, flag))
print("problems:", bad)
