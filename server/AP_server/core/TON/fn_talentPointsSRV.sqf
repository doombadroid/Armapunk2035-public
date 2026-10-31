/*
    APS_fnc_talentPointsSRV  (LooneyBin, owner 2026-07-16) -- BUYABLE TALENT POINTS persistence.
      ["load"]   client asks for its purchased-point count at login -> pushed back via AP_fnc_talentPointsRecv
      ["buy"]    client bought one (money deducted client-side, the learnTalent/respec precedent) -> +1 in DB,
                 then the fresh count is pushed back so the client can't drift.
    The caller is resolved from remoteExecutedOwner (non-spoofable), never from passed args. Bodies run in
    spawned (scheduled) context -- the mode-2 DB reads block.
*/
if (!isServer) exitWith {};
params [["_mode", "", [""]]];

private _unit = (allPlayers select { owner _x isEqualTo remoteExecutedOwner }) param [0, objNull];
if (isNull _unit) exitWith {};
private _uid = getPlayerUID _unit;
if (_uid isEqualTo "") exitWith {};

switch (toLower _mode) do {case "load": {[_unit, _uid] spawn {params ["_unit", "_uid"];
            private _rows = [format ["SELECT points FROM talent_points WHERE pid='%1'", _uid], 2, true] call DB_fnc_asyncQuery;
            private _pts = ((_rows param [0, [0]]) param [0, 0]);
            if (!(_pts isEqualType 0)) then { _pts = parseNumber format ["%1", _pts]; };
            if (!isNull _unit) then { [[_pts], "AP_fnc_talentPointsRecv", _unit, false, false] spawn AP_fnc_MP; };};};
    case "buy": {[_unit, _uid] spawn {params ["_unit", "_uid"];
            [format ["INSERT INTO talent_points (pid, points) VALUES ('%1', 1) ON CONFLICT (pid) DO UPDATE SET points = talent_points.points + 1", _uid]] call DB_fnc_asyncQuery;
            uiSleep 1;
            private _rows = [format ["SELECT points FROM talent_points WHERE pid='%1'", _uid], 2, true] call DB_fnc_asyncQuery;
            private _pts = ((_rows param [0, [1]]) param [0, 1]);
            if (!(_pts isEqualType 0)) then { _pts = parseNumber format ["%1", _pts]; };
            if (!isNull _unit) then { [[_pts], "AP_fnc_talentPointsRecv", _unit, false, false] spawn AP_fnc_MP; };
            ["-TALENTS-", _unit, name _unit, format ["bought a talent point (now %1 purchased)", _pts]] call APS_fnc_logIt;};};};
