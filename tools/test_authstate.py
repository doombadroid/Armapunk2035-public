#!/usr/bin/env python3
"""Server authority state stays out of client-writable missionNamespace (audit Lsec-0-1).

A client's publicVariable overwrites a missionNamespace global on the SERVER too, so the server must
never decide anything off one of these names. Its own copy lives in localNamespace, which the network
cannot write; the global, where one exists, is only the published display copy for clients.

Rule checked, over every .sqf under server/AP_server/:
  * outside the WRITERS below, a guarded name may appear (in code or in a string) ONLY as
    `localNamespace getVariable [...]` / `localNamespace setVariable [...]`;
  * inside WRITERS, the bare global may be initialised, assigned and published, but never read
    through `missionNamespace getVariable`;
  * server_init.sqf's addPublicVariableEventHandler list covers every guarded name the server
    publishes (AP_hcOwner is deliberately absent: the headless client announces it legitimately);
  * a WRITER that publishes one of those names also writes its localNamespace copy -- the FREE BUILD
    toggle published only the display copy, so the server never saw it turn on (r2fab).
    publishes (AP_hcOwner is deliberately absent: the headless client announces it legitimately).
The vendored ArmaQuest tree gets the same rule for AQ_GUARDED (quest server state + settings root),
with no writers, and string literals holding whitespace are ignored there (log text, not lookups).
EXEMPT lists (file, name) pairs the read lint skips on purpose (condition code the server ships to clients); they are
tolerated, not required, so fixing one there never fails this test.

Run: python3 -m unittest tools/test_authstate.py   (run_checks.sh picks it up automatically)
"""
import pathlib
import re
import unittest

REPO = pathlib.Path(__file__).resolve().parent.parent
SERVER = REPO / "server" / "AP_server"

GUARDED = [
    "AP_dutyEnabled", "AP_dutyRoster", "AP_betaZeroCops", "AP_fabFreeBuild", "AP_priceOv",
    "AP_purgeZone", "AP_hcOwner", "AP_devAutoAdmin", "SRV_grantNewbieRoles",
    "SRV_dutyBuyoutMult", "SRV_dutyBountyGate", "AP_slotsJackpotNerf",
    # uid/netId-keyed server copies (audit 2026-09-26, mints2). These used to be UNPUBLISHED object vars, and a client's
    # public setVariable of the same name overwrites those on the server as well -- so they may not be object vars.
    "AP_fabLevelSrv", "AP_fabXpSrv", "AP_fabSchemSrv", "AP_wreckLedger", "APS_rigKind_",
    # uid -> gang id; gang-HQ storage (fn_houseRights) and align: contracts (AP_fnc_aqFactionOf) gate on it (r2gangmap)
    "APS_gangOfUid",
    # furniture caches + light table (r2furn): as globals, a published copy made the server createVehicle any class
    # and deleteVehicle any object. The AP_ names are the retired globals, kept so they cannot come back.
    "APS_furnCache", "APS_suiteFurnCache", "APS_furnLights", "AP_furnCache", "AP_suiteFurnCache", "AP_furnLights",
    # furniture class whitelist: AP_furnitureClasses is the CLIENT list (nil on the server, set by publicVariableServer)
    "APS_furnClasses", "AP_furnitureClasses",
    # governor seat + race (audit 2026-09-26, r2gov): a forged SRV_governorData passed every governor gate (laws,
    # the gang-50000 treasury, the gov broadcast) and a forged race picked the next governor.
    "SRV_governorData", "SRV_govCandidates", "SRV_govTermGen", "SRV_govElectionArmed",
    "AP_fabLevelSrv", "AP_fabXpSrv", "AP_fabSchemSrv", "AP_wreckLedger", "APS_rigKind_", "APS_rigPersist_",
    # r2items: the foreskin registry feeds fn_virtItemCfg's item rows on the server
    "AP_foreskinReg",
]
# mission files whose code runs on the server and reads a GUARDED name
MISSION_SERVER_READERS = ["mission/Armapunk2035.Malden/core/quests/fn_aqProfile.sqf"]
# The vendored ArmaQuest server's state and settings root (audit r2aq): every machine, same rule.
AQ = REPO / "mission" / "Armapunk2035.Malden" / "ArmaQuest"
AQ_GUARDED = ["aq_srvReady", "aq_srvEpochBase", "aq_srvPlayers", "aq_srvBoard", "aq_srvSeq",
              "aq_srvFactRate", "aq_srvStoreDirty", "aq_storeSqlEscMode", "aq_cfg"]
# published by the server -> must be restored by the server_init.sqf PVEH guard
PUBLISHED = {"AP_dutyEnabled", "AP_betaZeroCops", "AP_fabFreeBuild", "AP_priceOv", "AP_purgeZone",
             "AP_devAutoAdmin", "SRV_grantNewbieRoles", "SRV_governorData", "AP_foreskinReg"}

# files that assign + publicVariable the display copy (relative to server/AP_server)
WRITERS = {
    "server_init.sqf", "init.sqf", "vars.sqf",
    "core/TON/fn_economySRV.sqf", "core/TON/fn_eventPurgeSRV.sqf", "core/TON/fn_fedOverrideSRV.sqf",
    "core/TON/fn_toggleNewbieRoles.sqf", "core/TON/fn_fabDebugSRV.sqf", "core/TON/fn_govSystemSRV.sqf", "core/TON/fn_registerForeskin.sqf",
}
# (file, name) that publish without a localNamespace write, and why that is safe
PUBLISH_ONLY = {
    ("vars.sqf", "AP_priceOv"),   # the boot default [], the same as every localNamespace read's default
}

# heist state (audit r2heist): the server's copies live in localNamespace; the globals are display copies, or gone
# (allLocalMapEntities is now APS_fnc_mapLoad's localNamespace APS_mapEntities, so the old name may not come back).
GUARDED += ["AP_lbState", "SRV_loonyBinData", "SRV_maldenFed", "AP_fedOverride", "AP_fedInternalKey",
            "AP_fedBootAllowed", "allLocalMapEntities"]
WRITERS |= {"core/TON/fn_loonyBinSRV.sqf", "core/TON/fn_maldenFedSRV.sqf", "core/system/fn_resetFed.sqf"}
# condition code the server SHIPS to clients (handleMessage countdown bars): it runs there, on the display copy
CLIENT_EVAL = {("core/TON/fn_maldenFedSRV.sqf", "SRV_maldenFed")}
EXEMPT = set(CLIENT_EVAL)   # (file, name) pairs the read lint skips


# r2items: config caches the SERVER builds through mission fns (item weights/prices, vehicle sell-back, fab recipes,
# schematics). They live in localNamespace on every machine, so anywhere in mission/ they may appear only there.
MISSION = REPO / "mission" / "Armapunk2035.Malden"
CONFIG_CACHES = [
    "AP_virtItemArr", "AP_virtItemIdx", "AP_virtItemIdxLife", "AP_virtItemRegSnap", "AP_vehConfigTable",
    "AP_vehConfigNonSrt", "AP_fabMap", "AP_fabDurations", "AP_fabXpCurve", "AP_fabSchemMap", "AP_fabShardMap",
]


def cache_violations(rel, code):
    found = []
    for name in CONFIG_CACHES:
        word = re.compile(r"(?<![A-Za-z0-9_])" + name + r"(?![A-Za-z0-9_])")
        local = re.compile(r'localNamespace\s+[gs]etVariable\s*\[?\s*"' + name + '"')
        for ln, line in enumerate(code.split("\n"), 1):
            if word.search(local.sub("", line)):
                found.append(f"{rel}:{ln}: {name} outside localNamespace")
    return found


def strip_comments(src):
    """Drop // and /* */ comments; keep strings verbatim. SQF escapes a quote by doubling it."""
    out, i, n = [], 0, len(src)
    while i < n:
        c = src[i]
        if c in "\"'":
            j = i + 1
            while j < n:
                if src[j] == c:
                    if j + 1 < n and src[j + 1] == c:
                        j += 2
                        continue
                    break
                j += 1
            out.append(src[i:j + 1])
            i = j + 1
        elif src.startswith("//", i):
            while i < n and src[i] != "\n":
                i += 1
        elif src.startswith("/*", i):
            end = src.find("*/", i + 2)
            nl = src.count("\n", i, n if end < 0 else end)
            out.append("\n" * nl)
            i = n if end < 0 else end + 2
        else:
            out.append(c)
            i += 1
    return "".join(out)


def drop_prose(code):
    """Blank string literals holding whitespace: text that mentions a name, not a variable lookup."""
    return re.sub(r'"(?:[^"]|"")*"', lambda m: m.group(0) if not re.search(r"\s", m.group(0))
                  else '""' + "\n" * m.group(0).count("\n"), code)


def violations(rel, code, names=GUARDED, writers=WRITERS):
    found = []
    for name in names:
        if (rel, name) in EXEMPT:
            continue
        word = re.compile(r"(?<![A-Za-z0-9_])" + name + r"(?![A-Za-z0-9_])")
        local = re.compile(r'localNamespace\s+[gs]etVariable\s*\[?\s*"' + name + '"')
        bad_read = re.compile(r'missionNamespace\s+getVariable\s*\[?\s*"' + name + '"')
        for ln, line in enumerate(code.split("\n"), 1):
            if rel in writers:
                if bad_read.search(line):
                    found.append(f"{rel}:{ln}: {name} read from missionNamespace")
            elif word.search(local.sub("", line)):
                found.append(f"{rel}:{ln}: {name} outside localNamespace")
    return found


class AuthStateTest(unittest.TestCase):
    def test_strip_comments(self):
        self.assertEqual(strip_comments('a = "x // y"; // c\nb'), 'a = "x // y"; \nb')
        self.assertEqual(strip_comments('a /* AP_x\n */ b "q""//" c'), 'a \n b "q""//" c')

    def test_detector_catches_the_class(self):
        self.assertTrue(violations("core/x.sqf", 'if (missionNamespace getVariable ["AP_dutyEnabled", false]) then {};'))
        self.assertTrue(violations("core/x.sqf", "_uid in AP_dutyRoster"))
        self.assertTrue(violations("init.sqf", '_z = missionNamespace getVariable ["AP_purgeZone", []];'))
        self.assertTrue(violations("core/x.sqf", 'if (isNil "AP_purgeZone") exitWith {};'))
        self.assertTrue(violations("core/x.sqf", 'private _k = _p getVariable ["AP_fabSchemSrv", []];'))
        self.assertTrue(violations("core/x.sqf", '_truck getVariable ["APS_rigKind_" + netId _truck, ""]'))
        self.assertFalse(violations("core/x.sqf", 'localNamespace getVariable ["APS_rigKind_" + netId _truck, ""]'))
        self.assertFalse(violations("core/x.sqf", 'localNamespace getVariable ["AP_hcOwner", 0]'))
        self.assertFalse(violations("init.sqf", 'AP_betaZeroCops = true; publicVariable "AP_betaZeroCops";'))

    def test_server_reads_only_localnamespace(self):
        found = []
        for p in sorted(SERVER.rglob("*.sqf")):
            rel = p.relative_to(SERVER).as_posix()
            found += violations(rel, strip_comments(p.read_text(encoding="utf-8", errors="replace")))
        for rel in MISSION_SERVER_READERS:
            found += violations(rel, strip_comments((REPO / rel).read_text(encoding="utf-8", errors="replace")))
        self.assertEqual(found, [], "\n" + "\n".join(found))

    def test_armaquest_state_only_localnamespace(self):
        # r2aq: the vendored quest server's own state and settings root (LOCAL PATCH, ArmaQuest/VENDORED.txt)
        self.assertTrue(violations("x.sqf", drop_prose('if (isNil "aq_srvReady" || {!aq_srvReady}) exitWith {};'), AQ_GUARDED, set()))
        self.assertTrue(violations("x.sqf", drop_prose('a = "b c"; _t = aq_srvBoard getOrDefault ["g", []];'), AQ_GUARDED, set()))
        self.assertFalse(violations("x.sqf", drop_prose('_s = "aq_srvPlayers (server)"; localNamespace getVariable ["aq_cfg", 0]'), AQ_GUARDED, set()))
        found = []
        for p in sorted(AQ.rglob("*.sqf")):
            code = drop_prose(strip_comments(p.read_text(encoding="utf-8", errors="replace")))
            found += violations(p.relative_to(AQ).as_posix(), code, AQ_GUARDED, set())
        self.assertEqual(found, [], "\n" + "\n".join(found))

    def test_queryrequest_seeds_fab_maps_once(self):
        # mints2 round 2: queryRequest is client-callable and its row read is stale by the time it writes, so a
        # write over a live entry resurrected a burned schematic. Every map write there must be seed-if-absent.
        code = strip_comments((SERVER / "core/DB/fn_queryRequest.sqf").read_text(encoding="utf-8"))
        lines = [l for l in code.split("\n") if re.search(r"AP_fab\w*Srv|_(lvl|xp|schem)Map\s+set\b", l)]
        sets = [l for l in lines if re.search(r"\bset\s*\[", l)]
        self.assertTrue(sets, "fab map seeding not found in fn_queryRequest.sqf")
        for l in sets:
            self.assertRegex(l, r"if\s*!\s*\(_uid in _(lvl|schem)Map\)", "unguarded fab map write: " + l.strip())

    def test_writers_publish_the_local_copy_too(self):
        found = []
        for rel in sorted(WRITERS):
            code = strip_comments((SERVER / rel).read_text(encoding="utf-8", errors="replace"))
            for name in sorted(PUBLISHED):
                if (rel, name) in PUBLISH_ONLY or f'publicVariable "{name}"' not in code:
                    continue
                if not re.search(r'localNamespace\s+setVariable\s*\[\s*"' + name + '"', code):
                    found.append(f"{rel}: publishes {name} but never sets its localNamespace copy")
        self.assertEqual(found, [], "\n" + "\n".join(found))
    def test_govsystem_reads_only_the_server_copy(self):
        # r2gov: fn_govSystemSRV is a WRITER only to publish the display copy; every read there is localNamespace.
        code = strip_comments((SERVER / "core/TON/fn_govSystemSRV.sqf").read_text(encoding="utf-8"))
        code = re.sub(r'localNamespace\s+[gs]etVariable\s*\[?\s*"SRV_gov\w*"', "", code)
        code = re.sub(r'\bSRV_governorData\s*=\s*_g\b|publicVariable\s+"SRV_governorData"', "", code)
        self.assertNotRegex(code, r"\bSRV_gov\w*")
    def test_rig_registers_only_through_its_craft(self):
        # r2rig: vehicleCreate is CfgRE 2 and rigSRV "craft" calls it inside the client's remote-executed frame, so only
        # craft's one-shot token tells them apart. It must be consumed before any exit and gate the live-rig refusal.
        vc = strip_comments((SERVER / "core/system/fn_vehicleCreate.sqf").read_text(encoding="utf-8"))
        eat = vc.find('localNamespace setVariable ["APS_rigPersist_" + netId _vehicle, nil]')
        self.assertTrue(-1 < eat < vc.find("exitWith"), "vehicleCreate must consume the craft token before any exit")
        self.assertIn('if (_rigKind isNotEqualTo "" && {!_rigCraft}) exitWith', vc)
        rig = strip_comments((SERVER / "core/TON/fn_rigSRV.sqf").read_text(encoding="utf-8"))
        tok = rig.find('localNamespace setVariable ["APS_rigPersist_" + netId _truck, true]')
        self.assertTrue(-1 < tok < rig.find("call APS_fnc_vehicleCreate"), "craft must set the token before vehicleCreate")
    def test_config_caches_are_local(self):
        self.assertTrue(cache_violations("x.sqf", 'if (isNil "AP_fabMap") then {AP_fabMap = createHashMap};'))
        self.assertTrue(cache_violations("x.sqf", 'missionNamespace setVariable ["AP_virtItemIdx", _idx];'))
        self.assertFalse(cache_violations("x.sqf", 'localNamespace setVariable ["AP_virtItemIdx", _idx];'))
        found = []
        for p in sorted(MISSION.rglob("*.sqf")):
            src = p.read_text(encoding="utf-8", errors="replace")
            if any(n in src for n in CONFIG_CACHES):
                found += cache_violations(p.relative_to(MISSION).as_posix(), strip_comments(src))
        self.assertEqual(found, [], "\n" + "\n".join(found))

    def test_pveh_guard_covers_published_names(self):
        code = strip_comments((SERVER / "server_init.sqf").read_text(encoding="utf-8"))
        m = re.search(r"addPublicVariableEventHandler.*?\}\s*forEach\s*\[([^\]]*)\]", code, re.S)
        self.assertIsNotNone(m, "server_init.sqf lost its authority-state PVEH guard")
        self.assertEqual(set(re.findall(r'"([A-Za-z0-9_]+)"', m.group(1))), PUBLISHED)


if __name__ == "__main__":
    unittest.main()
