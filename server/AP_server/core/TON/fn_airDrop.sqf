/*
    APS_fnc_airDrop  (LooneyBin -- implemented from stub 2026-06-09)
    Cartel-capture reward. Client (core/gangs/fn_captureCartel.sqf) sends [gangID] on a finished capture.
    Drops a loot crate by parachute at the cartel the capturing gang is standing on (the gang's members'
    position picks the cartel -- the client doesn't transmit which one was taken).
*/
params [["_gangID", -1, ["", 0]]];
private _idStr = format ["%1", _gangID];
// find an online member of that gang (group var gang_id, set by initGang/setGangTagSRV)
private _member = allPlayers param [allPlayers findIf { format ["%1", (group _x) getVariable ["gang_id", -1]] isEqualTo _idStr }, objNull];
if (isNull _member) exitWith { diag_log format ["[LooneyBin][airDrop] no online member found for gang %1", _idStr]; };
// owner 2026-06-15 (#247): drop at the cartel this gang actually CAPPED, resolved from the FLAG whose
// AP_capData gang matches. The old code searched for a cartel marker within 300m of a random online gang
// member and, if that member (often the LEADER) had walked off, fell back to getPosATL _member -> the crate
// parachuted "onto the gang leader wherever he is on the map". Resolve it deterministically from the flag.
private _cartels = ["arms_cartel", "drug_cartel", "oil_cartel", "wongs_cartel"];
private _flags   = ["arms_flag",   "drug_flag",   "oil_flag",   "wongs_flag"];
private _ci = _flags findIf {private _f = missionNamespace getVariable [_x, objNull];
    !isNull _f && {format ["%1", ((_f getVariable ["AP_capData", [0]]) param [0, 0])] isEqualTo _idStr}};
if (_ci < 0) exitWith { diag_log format ["[LooneyBin][airDrop] gang %1 controls no cartel flag -- no drop", _idStr]; };
private _pos = getMarkerPos (_cartels select _ci);
// owner 2026-06-14 (#199): push the drop a fixed 20m off the flag BEFORE safe-pos snapping. The capper
// stands ON the flag to finish the capture, and BIS_fnc_findSafePos centred on the flag falls back to the
// flag itself when it can't find a clear spot (the cartel is packed with bag-fences/H-barriers from
// fn_spawnCaptures) -> the parachuted crate dropped straight onto the player. Offsetting first, then
// snapping a small radius around THAT point, keeps the drop ~20m clear even when safe-pos fails.
private _dropDir = random 360;
_pos = [(_pos select 0) + 20 * sin _dropDir, (_pos select 1) + 20 * cos _dropDir, 0];
_pos = [_pos, 0, 8, 3, 0, 0.5, 0] call BIS_fnc_findSafePos;

private _chute = "B_Parachute_02_F" createVehicle [_pos select 0, _pos select 1, 120];
private _crate = "B_supplyCrate_F" createVehicle [_pos select 0, _pos select 1, 118];
_crate enableRopeAttach false;   // owner 2026-06-16 (#276): no helicopter slingload -- crates were hooked away to dupe the cap loot
_crate attachTo [_chute, [0, 0, -1.2]];
_crate setVariable ["owner", "cartel_drop", true];   // cleanup-sweep spare
clearWeaponCargoGlobal _crate; clearItemCargoGlobal _crate; clearMagazineCargoGlobal _crate; clearBackpackCargoGlobal _crate;
// modest randomized prize: arms + meds
{ _crate addWeaponCargoGlobal _x; } forEach (selectRandom [
    [["arifle_Katiba_F", 2]], [["srifle_EBR_F", 1], ["hgun_ACPC2_F", 1]], [["LMG_Mk200_F", 1]], [["arifle_MX_F", 2]]]);
{ _crate addMagazineCargoGlobal _x; } forEach [["30Rnd_65x39_caseless_green", 8], ["20Rnd_762x51_Mag", 6]];
{ _crate addItemCargoGlobal _x; } forEach [["FirstAidKit", 5], ["optic_Hamr", 1]];
[_chute, _crate] spawn {params ["_chute", "_crate"];
    waitUntil { uiSleep 1; isNull _chute || {(getPosATL _crate) select 2 < 2} };
    detach _crate;
    // owner 2026-06-16 (#285 regression of #271/#276): both earlier anti-dupe locks broke the crate --
    // `enableSimulationGlobal false` killed cargo streaming (#271, loot vanished), and attaching it to an
    // anchor blocked opening its inventory entirely (#285, "won't let me take anything out"). Keep the crate
    // FREE + SIMULATED so its loot menu works, block the helicopter hook via `enableRopeAttach false` (set at
    // creation), and run a SNAP-BACK watcher: if anyone VIV-loads or shoves the crate off its landing spot it's
    // yanked straight back -> moving/duping it is pointless while the loot stays fully accessible.
    private _home = getPosATL _crate;
    [_crate, _home] spawn {params ["_c", "_home"];
        while { !isNull _c } do {uiSleep 3;
            if (!isNull _c) then {if (!isNull (attachedTo _c)) then { detach _c; };           // un-sling / un-VIV
                if ((getPosATL _c) distance _home > 6) then {_c setPosATL _home;
                    _c setVelocity [0, 0, 0];};};};};
    // owner 2026-06-14 (#180): delete the spent parachute the moment the crate lands instead of leaving it
    // as litter. B_Parachute_02_F is an "Air"-class object; left sitting near a cartel it tripped the garage
    // vehicle-pull occupancy check (`nearestObjects [pos,["Air"],14]`) -> "a vehicle is blocking the spawn
    // point" with no car anywhere in sight (the Wongs-cartel pull report). Sibling of #199.
    if (!isNull _chute) then { deleteVehicle _chute; };
    private _smoke = "SmokeShellGreen" createVehicle (getPosATL _crate);
    uiSleep 1200; { if (!isNull _x) then { deleteVehicle _x; }; } forEach [_crate, _smoke];   // 20-min despawn (snap-back watcher ends when _crate goes null)
};
[[0, "A cartel supply drop is inbound at the captured cartel!"], "AP_fnc_broadcast", civilian, false, false] spawn AP_fnc_MP;
diag_log format ["[LooneyBin][airDrop] crate for gang %1 at %2 (%3)", _idStr, _pos, _marker];
