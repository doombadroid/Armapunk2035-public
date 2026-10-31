/*
    APS_fnc_economySRV  (LooneyBin Economy -- owner request 2026-06-11)
    Owner-only live price overrides, persisted in `price_overrides` + broadcast as AP_priceOv.
    Client (AP_fnc_economyMenu) sends:
      ["set", family, key, p0, p1, p2, displayName, caller]  upsert + apply live
      ["reset", family, key, caller]                          delete override (back to config default)
      ["load"]                              (server boot)      DB -> AP_priceOv -> publicVariable
    Owner gate: the CALLER's players_global.adminlevel must be >= 5 (owner). Re-checked here from the
    DB every call -- the client gate is never trusted. (Beta auto-admin is level 4, so testers can't.)
*/
params [["_mode", "", [""]]];
// THE SERVER'S LIST IS THE localNamespace ONE (audit Lsec-0-1). AP_priceOv in missionNamespace is only the
// copy published to client shop UIs: a client's publicVariable overwrites it on the server too, and
// AP_fnc_priceOv prices vehicle sell-back (ND included) off whatever it holds. Every server-side read goes
// through AP_fnc_priceOv, which reads this copy on the server; every write below republishes it.
private _ov = localNamespace getVariable ["AP_priceOv", []];
localNamespace setVariable ["AP_priceOv", _ov];

// owner 2026-06-23 SECURITY (security.md §2.2 — owner check was on a PASSED object, spoofable): the owner
// gate re-queried adminlevel by getPlayerUID of a client-supplied _caller arg, so an attacker could pass a
// real owner's object (if online) and pass the check. Derive the actor from the NON-SPOOFABLE
// remoteExecutedOwner instead (0 = server-internal boot "load" = trusted). _realCaller / _callerUID below
// replace every use of the passed _caller arg.
private _src = remoteExecutedOwner;
private _realCaller = if (_src isEqualTo 0) then { objNull } else { (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
private _callerUID = getPlayerUID _realCaller;
private _isOwner = {if (_src isEqualTo 0) exitWith { true };   // server-internal (boot load) always passes
    if (_callerUID isEqualTo "") exitWith { false };
    private _lr = [format ["SELECT adminlevel FROM players_global WHERE playerid='%1'", _callerUID], 2, true] call DB_fnc_asyncQuery;
    (parseNumber format ["%1", (_lr param [0, [0]]) param [0, 0]]) >= 5};

switch (toLower _mode) do {case "load": {
        // QUOTE the string columns: DB_fnc_asyncQuery call-compiles the result, so bare family/key
        // (e.g. veh, O_MRAP_02_hmg_F) parsed as undefined variables and the whole load threw.
        private _rows = ["SELECT family, item_key, p0, p1, p2 FROM price_overrides", 2, true] call DB_fnc_asyncQuery;
        _ov resize 0;   // in place: one array for the server's life, so no in-flight call holds a stale one
        if (_rows isEqualType []) then {{_x params [["_f", ""], ["_k", ""], ["_p0", -1], ["_p1", -1], ["_p2", -1]];
                _ov pushBack [format ["%1", _f], format ["%1", _k], parseNumber format ["%1", _p0], parseNumber format ["%1", _p1], parseNumber format ["%1", _p2]];
            } forEach _rows;};
        AP_priceOv = _ov; publicVariable "AP_priceOv";
        diag_log format ["[LooneyBin][economy] loaded %1 override(s)", count _ov];};
    case "set": {
        params ["", ["_family", "", [""]], ["_key", "", [""]], ["_p0", -1, [0]], ["_p1", -1, [0]], ["_p2", -1, [0]], ["_dn", "", [""]]];   // client _caller arg ignored -- use the non-spoofable _realCaller
        if (_family isEqualTo "" || {_key isEqualTo ""}) exitWith {};
        if !(call _isOwner) exitWith { ["-SEC-", _realCaller, format ["BLOCKED economySRV set by %1", _callerUID]] call APS_fnc_logIt; };
        private _bad = toString [39, 96, 34];   // ' ` "  -- strip SQL-breakers
        private _sf = _family splitString _bad joinString "";
        private _sk = _key splitString _bad joinString "";
        private _sdn = _dn splitString _bad joinString "";
        [format ["INSERT INTO price_overrides (family,item_key,p0,p1,p2,display_name,updated_by) VALUES ('%1','%2',%3,%4,%5,'%6','%7') ON CONFLICT (family, item_key) DO UPDATE SET p0=%3, p1=%4, p2=%5, display_name='%6', updated_by='%7'",
            _sf, _sk, round _p0, round _p1, round _p2, _sdn, _callerUID]] call DB_fnc_asyncQuery;
        private _i = _ov findIf { ((_x select 0) isEqualTo _sf) && {(_x select 1) isEqualTo _sk} };
        if (_i isEqualTo -1) then { _ov pushBack [_sf, _sk, round _p0, round _p1, round _p2]; }
        else { _ov set [_i, [_sf, _sk, round _p0, round _p1, round _p2]]; };
        AP_priceOv = _ov; publicVariable "AP_priceOv";
        [777, _realCaller, format ["ECON set %1/%2 = [%3,%4,%5]", _sf, _sk, round _p0, round _p1, round _p2]] call APS_fnc_logIt;
        [[format ["Economy: %1 price saved (live).", _sk], "success"], "AP_fnc_handleMessage", _realCaller, false, false] spawn AP_fnc_MP;
    };
    case "reset": {
        params ["", ["_family", "", [""]], ["_key", "", [""]]];   // client _caller arg ignored -- use the non-spoofable _realCaller
        if !(call _isOwner) exitWith { ["-SEC-", _realCaller, format ["BLOCKED economySRV reset by %1", _callerUID]] call APS_fnc_logIt; };
        private _bad = toString [39, 96, 34];
        private _sf = _family splitString _bad joinString "";
        private _sk = _key splitString _bad joinString "";
        [format ["DELETE FROM price_overrides WHERE family='%1' AND item_key='%2'", _sf, _sk]] call DB_fnc_asyncQuery;
        private _i = _ov findIf { ((_x select 0) isEqualTo _sf) && {(_x select 1) isEqualTo _sk} };
        if (_i isNotEqualTo -1) then { _ov deleteAt _i; };
        AP_priceOv = _ov; publicVariable "AP_priceOv";
        [[format ["Economy: %1 reset to default.", _sk], "success"], "AP_fnc_handleMessage", _realCaller, false, false] spawn AP_fnc_MP;
    };};
