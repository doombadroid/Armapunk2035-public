/*
    APS_fnc_fetchLoadouts  (LooneyBin: load a player's saved loadouts) -- runs on the SERVER.
    2020 caller (fn_loadoutMenu): [_player, playerSide, 1]
    Was a logging-only STUB, so fn_loadoutMenu's `waitUntil {AP_loadoutRequested}` never returned and the
    loadout dialog never opened ("click loadout, nothing happens"). Reads the player's rows for this side
    from the loadouts table and ships the 6-slot AP_loadoutHolder back to their client via AP_fnc_netSetVar
    (server is the only allowed setter; both vars are whitelisted there), then flips AP_loadoutRequested.
    DB layout: one row per loadout -- slot column holds the client's uniqueID (used for UPDATE/DELETE WHERE),
    gear column is the mres-encoded [type, name, loadout, virtualInv, skins]. Holder entry that the menu wants:
    [uniqueID, type, name, loadout, virtualInv, skins]; empty slots are [].
*/
params [["_player", objNull, [objNull]], ["_side", civilian, [civilian]]];
if (isNull _player) exitWith {};
private _uid = getPlayerUID _player;
if (_uid isEqualTo "") exitWith {};
private _sideStr = str _side;

private _dec = {params [["_v", "", [""]]];
    if (isNil "_v" || {_v isEqualTo ""} || {_v isEqualTo "NULL"}) exitWith {[]};
    private _a = [_v] call DB_fnc_mresToArray;
    if (typeName _a == "STRING") then { _a = parseSimpleArray (format ["%1", _a]); };   // SECURITY: PARSE, never call compile -- a loadout name with a backtick decodes to a " that would break out and execute as SQF on the server (Lystic compile-RCE class). parseSimpleArray only builds data.
    if (isNil "_a") then { _a = []; };
    _a};

private _rows = [format ["SELECT slot, gear FROM loadouts WHERE pid='%1' AND side='%2' ORDER BY id ASC", _uid, _sideStr], 2, true] call DB_fnc_asyncQuery;
private _holder = [[], [], [], [], [], [], [], []];   // 8 slots, matching the configuration.sqf default
if (_rows isEqualType []) then {private _i = 0; {if (_i > 7) exitWith {};
        private _slotUid = _x select 0;
        private _g = [_x select 1] call _dec;   // [type, name, loadout, virtualInv, skins]
        if (_g isEqualType [] && {count _g >= 5}) then {_g params ["_type", "_name", "_loadout", "_virtualInv", "_skins"];
            _holder set [_i, [_slotUid, _type, _name, _loadout, _virtualInv, _skins]];
            _i = _i + 1;};} forEach _rows;};

// hand the holder to the requesting client, THEN release its waitUntil. MUST be `call` not `spawn`:
// two spawns race in the scheduler, so the requested-flag could be remoteExec'd before the holder ->
// client's waitUntil{AP_loadoutRequested} releases against a still-empty holder -> loadouts "vanish"
// on relog. Sequential `call` issues the two remoteExecs in order, and same-target delivery is ordered.
[["AP_loadoutHolder", _holder], "AP_fnc_netSetVar", _player, false, false] call AP_fnc_MP;
[["AP_loadoutRequested", true], "AP_fnc_netSetVar", _player, false, false] call AP_fnc_MP;
