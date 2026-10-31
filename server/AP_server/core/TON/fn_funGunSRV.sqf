/*
    APS_fnc_funGunSRV  (LooneyBin -- admin-menu FUN GUN, server)
    Two actions, split by trust:

      GRANT/REVOKE (owner-only, level 5 -- re-queried NON-SPOOFABLY from players_global, never trusted from
      the client): remoteExec AP_fnc_funGunClient onto EVERY player.
        ["lynx"]      -> Lynx + unlimited ammo + rapid auto
        ["subcannon"] -> same, plus each shot fires a networked SDV submarine
        ["off"]       -> remove it

      SUB SPAWN (player-driven, NOT admin -- any player whose Fired EH the grant armed):
        ["spawnsub", _posASL, _dir] -> createVehicle a networked SDV at the muzzle + launch it.
        Gated on the server's active-cannon set (AP_funGunActive[uid]) + rate-limited, so a client can't
        forge sub spam without the owner having enabled the cannon for them.
*/
// grant form:  [_action, _scope]              _scope = "self" (caller only) | "all" (everyone)
// spawnsub:    ["spawnsub", _posASL, _dir]      (_p1/_p2 are arrays; scope ignored)
params [["_action", "", [""]], ["_p1", "", []], ["_p2", [], []]];
private _act = toLower _action;

private _src = remoteExecutedOwner;
private _caller = if (_src isEqualTo 0) then { objNull } else { (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
if (isNil "AP_funGunActive") then { AP_funGunActive = createHashMap; };
if (isNil "AP_funGunSubCD") then { AP_funGunSubCD = createHashMap; };

// ---------------- player-driven sub spawn (validated, not admin) ----------------
if (_act isEqualTo "spawnsub") exitWith {
    if (isNull _caller) exitWith {};                                        // server-internal has no muzzle
    private _uid = getPlayerUID _caller;
    if !(AP_funGunActive getOrDefault [_uid, false]) exitWith {};          // must currently hold the cannon
    if !(_p1 isEqualType [] && {count _p1 >= 3} && {_p2 isEqualType [] && {count _p2 >= 3}}) exitWith {};
    private _last = AP_funGunSubCD getOrDefault [_uid, -999];
    if ((diag_tickTime - _last) < 0.04) exitWith {};                        // 25 subs/sec cap -- above the Sting's ROF
    AP_funGunSubCD set [_uid, diag_tickTime];
    private _sub = "B_SDV_01_F" createVehicle (ASLToAGL _p1);
    _sub setPosASL _p1;
    _sub setVectorDirAndUp [_p2, [0, 0, 1]];
    _sub setVelocity (_p2 vectorMultiply 300);                             // ~12 m between back-to-back subs -> no muzzle pile-up
    _sub setVariable ["AP_funSub", true, true];
    [_sub] spawn { params ["_s"]; uiSleep 12; if (!isNull _s) then { deleteVehicle _s; }; };   // short life bounds the Sting's spam
};

// ---------------- owner grant/revoke: re-query adminlevel (flat, non-spoofable) ----------------
private _lvl = if (_src isEqualTo 0) then { 999 } else {if (isNull _caller) exitWith { -1 };
    private _rows = [format ["SELECT adminlevel FROM players_global WHERE playerid='%1'", getPlayerUID _caller], 2, true] call DB_fnc_asyncQuery;
    parseNumber format ["%1", (_rows param [0, [0]]) param [0, 0]]};
if (_lvl < 5) exitWith { ["-SEC-", _caller, format ["BLOCKED funGunSRV '%1' (admin %2 -- owner only)", _act, _lvl]] call APS_fnc_logIt; };
if !(_act in ["lynx", "subcannon", "off"]) exitWith {};

// scope: "self" = just the caller, "all" = everyone (default all)
private _scope  = if (_p1 isEqualType "") then { toLower _p1 } else { "all" };
if !(_scope in ["self", "all"]) then { _scope = "all"; };
private _targets = if (_scope isEqualTo "self") then { if (isNull _caller) exitWith {}; [_caller] } else { allPlayers };

// sub spawns are allowed ONLY while subcannon mode is active, and only for the targeted players
private _subMode = _act isEqualTo "subcannon";
{ AP_funGunActive set [getPlayerUID _x, _subMode]; } forEach _targets;

if (_scope isEqualTo "self") then {[[_action], "AP_fnc_funGunClient", _caller, false, false] spawn AP_fnc_MP;} else {
    [[_action], "AP_fnc_funGunClient", -2, false, false] spawn AP_fnc_MP;};
["-ADMINACTION-", _caller, (name _caller), format ["FUN GUN '%1' (%2)", _act, _scope]] call APS_fnc_logIt;
