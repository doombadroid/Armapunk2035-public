/*
    APS_fnc_bonesDM  (LooneyBin, owner 2026-07-15) -- Ben Bones DM router.
      ["send", _msg]   client -> server (CfgRE 2). Queue the player's text for the bones.py daemon (bones_dm),
                       which generates an in-character Grok reply the delivery poll (init.sqf) hands back in-game.
    Identity from remoteExecutedOwner (never trusted). Rate-limited + length-capped; parameterized-safe (scrub quotes).
*/
if (!isServer) exitWith {};
params [["_mode", "", [""]], ["_msg", "", [""]]];
if ((toLower _mode) isNotEqualTo "send") exitWith {};
private _unit = (allPlayers select { owner _x isEqualTo remoteExecutedOwner }) param [0, objNull];
if (isNull _unit) exitWith {};
private _uid = getPlayerUID _unit;
if (_uid isEqualTo "") exitWith {};
if (isNil "AP_bonesDMLast") then { AP_bonesDMLast = createHashMap; };
if ((serverTime - (AP_bonesDMLast getOrDefault [_uid, -999])) < 15) exitWith {
    [["Ben Bones is on the other line (bunker signal is bad). Give it a moment.", "basic"], "AP_fnc_handleMessage", _unit, false, false] spawn AP_fnc_MP;
};
AP_bonesDMLast set [_uid, serverTime];
_msg = _msg select [0, 500];   // owner 2026-07-17: 200 -> 500 char cap on texts to Ben Bones
private _clean = ((_msg splitString "'""`\") joinString "");
private _nm = ((name _unit) splitString "'""`\") joinString "";
if ((count _nm) > 28) then { _nm = _nm select [0, 28]; };
[format ["INSERT INTO bones_dm (uid, name, message) VALUES ('%1','%2','%3')", _uid, _nm, _clean]] call DB_fnc_asyncQuery;
["-BONESDM-", _unit, _nm, format ["-> Bones: %1", _clean]] call APS_fnc_logIt;
