/*
    debug/exchangesite.sqf -- confirm the Grand Exchange NPC is standing on the ground.

        [] execVM "debug\exchangesite.sqf";

    The site was picked from mapData: 4 m off the genstore/market pair at Sofia, which sit 3.9 m
    apart sharing z = 22.600 exactly. That shared z is real evidence the ground there is flat --
    but it is still a proxy, and a mapData z-spread proxy is exactly what put a building 1.7 m out
    once when it predicted 0.2. Only getTerrainHeightASL is truth, so measure it.

    Reports the spread across the NPC position and four corners 2 m out. Anything over ~0.15 m and
    the NPC will float or sink; move the row in core/config/fn_mapData.sqf (or drag it in 3DEN via
    `python3 tools/npc_eden.py stage`, which is what that tool exists for).
*/
private _spots = missionNamespace getVariable ["AP_exchangeSpots", []];
if (_spots isEqualTo []) exitWith {
    hint "AP_exchangeSpots is empty -- no civExchange row found in mapData.";
    diag_log "[AP-PROBE] exchangesite: no civExchange rows in allLocalMapEntities";
};

{
    private _p = _x;
    private _hs = [];
    { _hs pushBack (getTerrainHeightASL [(_p select 0) + (_x select 0), (_p select 1) + (_x select 1)]); }
        forEach [[0,0], [2,0], [-2,0], [0,2], [0,-2]];
    private _spread = (selectMax _hs) - (selectMin _hs);
    private _msg = format ["[AP-PROBE] exchangesite %1: authored z=%2 terrain=%3 spread=%4 %5",
        _forEachIndex, (_p select 2) toFixed 3, (_hs select 0) toFixed 3, _spread toFixed 3,
        if (_spread > 0.15) then {"<-- TOO STEEP, MOVE IT"} else {"ok"}];
    diag_log _msg;
    systemChat _msg;
} forEach _spots;

hint format ["Probed %1 Exchange site(s) -- see the RPT / system chat.", count _spots];
