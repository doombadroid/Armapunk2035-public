#!/usr/bin/env python3
"""Every admin-menu event starter must re-check the caller's admin level ON THE SERVER.

The admin event menu (core/config/fn_eventCfg.sqf) remoteExecs one APS_fnc_event*SRV per row, and each
is CfgRE-whitelisted, so any client can call it directly. Only GunGame/Gridrunner were gated until
2026-09-26 (audit admin-0-0: a self-started Battle Royale paid $250k). A new row whose SRV forgets the
gate fails here. The gate must be a FLAT top-level line: an exitWith nested in a then-block only leaves
that block. Also pins AP_fnc_botKick to server->client (audit registry-0-2).
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
MISSION = ROOT / "mission/Armapunk2035.Malden"
TON = ROOT / "server/AP_server/core/TON"

cfg = (MISSION / "core/config/fn_eventCfg.sqf").read_text()
starters = sorted(set(re.findall(r'"APS_fnc_(event\w+SRV)"', cfg)))
assert len(starters) >= 13, starters

FLAT_GATE = re.compile(r"^if !\(\[\d, \"\w+ START\"\] call APS_fnc_isAdminCaller\) exitWith \{\};", re.M)
FLAT_DB_GATE = re.compile(r"^\s*if \(_lvl < \d\) exitWith", re.M)   # the older inline form (GunGame/Gridrunner)
bad = [s for s in starters
       if not (FLAT_GATE.search(t := (TON / f"fn_{s}.sqf").read_text())
               or ("SELECT adminlevel" in t and FLAT_DB_GATE.search(t)))]
assert not bad, f"admin event starters with no server-side admin gate: {bad}"

cfgre = (MISSION / "CfgRE.hpp").read_text()
assert re.search(r"class AP_fnc_botKick \{allowedTargets = 1;\};", cfgre), "AP_fnc_botKick must be allowedTargets = 1"
kick = (MISSION / "core/functions/network/fn_botKick.sqf").read_text()
assert "if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};" in kick, "fn_botKick needs the server-origin guard"

br = (TON / "fn_eventBRSRV.sqf").read_text()
prune = br.find("AP_event_queue = AP_event_queue select { !isNull _x && {alive _x} && {isPlayer _x} };")
assert -1 < prune < br.find("count AP_event_queue < 2"), "BR lock must prune dead/null/non-player entries before the 2-fighter check"

print(f"ok: {len(starters)} admin event starters gated; botKick server->client only")
sys.exit(0)
