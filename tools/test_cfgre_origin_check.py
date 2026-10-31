#!/usr/bin/env python3
"""Self-test for tools/cfgre_origin_check.py: the guard detector accepts the repo's guard idioms and
rejects guards that come too late, compare the wrong way, or sit inside a nested block."""
from cfgre_origin_check import has_guard

GOOD = [
    'if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};\nparams ["_a"];',
    '/* hdr */\n#include "x.h"\nparams [["_a", 0]];\nif (remoteExecutedOwner != 2) exitWith {}; // c\n_a call f;',
    'disableSerialization;\nif (!hasInterface) exitWith {};\nif (remoteExecutedOwner isNotEqualTo 2) exitWith { diag_log "x;y"; };',
    'params ["_p"];\nif (!(remoteExecutedOwner in [0, 2])) exitWith {};',
    'if (isRemoteExecuted && {!isRemoteExecutedJIP} && {remoteExecutedOwner != 2}) exitWith {};',
]
BAD = [
    'params ["_a"];\nAP_atmcash = _a;',                                                  # no guard
    'AP_x = 1;\nif (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};',          # too late
    'if (remoteExecutedOwner == 2) exitWith {};\nAP_x = 1;',                                # wrong way round
    'if ((remoteExecutedOwner isEqualTo clientOwner) && !isServer) exitWith {};',          # old medicFire test
    'if (true) then { if (remoteExecutedOwner != 2) exitWith {}; };\nAP_x = 1;',            # nested: exits the then-block only
    'if (remoteExecutedOwner != 20) exitWith {};',                                          # not the server id
    '// if (remoteExecutedOwner != 2) exitWith {};\nAP_x = 1;',                             # commented out
]
for s in GOOD:
    assert has_guard(s), "should pass:\n" + s
for s in BAD:
    assert not has_guard(s), "should fail:\n" + s
print("ok  cfgre_origin_check self-test (%d good, %d bad)" % (len(GOOD), len(BAD)))
