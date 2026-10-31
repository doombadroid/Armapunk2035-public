// Altis Life game mechanic — fictional in-game "quickhack" ability, game logic only
/*
    File: fn_cyberdeck.sqf
    LooneyBin 2026-07-18: Cyberdeck launcher. Routes a hack by whatever the player is aiming at.
    Replaces the lockpick + drill.
      * Vehicle    -> Sequence Breach (via the lockpick path).
      * House      -> Terminal Breach -> unlock all doors 3 min. ALWAYS: $10k Breaking & Entering
                      charge + owner toast + MaxSec alert (win or fail).
      * Crypto rig -> Terminal Breach -> full takeover. ALWAYS: $10k Cyber Crime charge (win or fail).
    Heavy targets (fed dome, bank vault) land in Phase 4.
*/
params [["_target", objNull, [objNull]]];
if (isNull _target) then { _target = cursorObject; };

if !((call AP_fnc_hasDeck)) exitWith {["You don't have a Cyberdeck.", "basic"] spawn AP_fnc_handleMessage;};
if (AP_effSide isEqualTo west) exitWith {
    ["The Cyberdeck's ICE locks out law enforcement credentials.", "basic"] spawn AP_fnc_handleMessage;};
// QUEST HOOKS. These lived in fn_qhConsoleFire.sqf, which called itself "the single
// place all four breach tools route through" -- true only of that console, which had
// no opener, so `qhbreach` could never actually fire. The console was deleted
// 2026-09-04 with the rest of the retired cyberdeck cluster; the hooks move HERE, to
// where a breach is actually attempted, so every surface (visor, launcher router,
// world action, keybind) counts rather than one retired dialog.
// Placed AFTER the gates on purpose: a refused attempt is not a breach.
// NOTE: the generic verb only. The old per-tool counters breach_unlock / breach_house
// are NOT restored here -- this sits above the type routing, so the tool id is not
// known yet, and re-deriving them per branch changes what those counters mean.
["action", "qhbreach", 1] spawn AP_fnc_handleQuest;
["qhbreach", [1]] call aq_fnc_event;   // ArmaQuest: aq_fx2_breach


// ---- CRYPTO MINING RIG -> Terminal Breach -> full takeover ----
if (_target getVariable ["AP_cryptoRig", false]) exitWith {private _uid = getPlayerUID player;
    if ((_target getVariable ["AP_rigOwner", ""]) isEqualTo _uid) exitWith {
        ["This is your own rig.", "basic"] spawn AP_fnc_handleMessage;};
    if (player distance _target > 8) exitWith {["Get closer to the rig to jack in.", "basic"] spawn AP_fnc_handleMessage;};
    private _r = [1] call AP_fnc_cyberdeckTerm;
    if (_r in [0, 1]) then {[[112, player], "APS_fnc_wantedAdd", false, false] spawn AP_fnc_MP;   // Cyber Crime -- regardless
    };
    if (_r isEqualTo 1) then {[["cryptoTakeover", _target, player], "APS_fnc_cyberdeckSRV", 2] spawn AP_fnc_MP;
        titleText ["Rig hijacked -- the coin stream is yours now.", "PLAIN"];
        [5] call AP_fnc_addInfamy;};};

// ---- HOUSE DOOR -> Terminal Breach ----
if (_target isKindOf "House_F" && {(typeOf _target) in AP_houseTypes}) exitWith {private _uid = getPlayerUID player;
    if (((_target getVariable ["AP_homeOwner", ""]) isEqualTo _uid) ||
        {_target in AP_vehicles} ||
        {[_target, _uid, "accessLock"] call AP_fnc_keyHolderStatus}) exitWith {
        ["You already have access to this property.", "basic"] spawn AP_fnc_handleMessage;};
    if (player distance _target > 14) exitWith {["Get closer to the door to jack in.", "basic"] spawn AP_fnc_handleMessage;};
    private _r = [1] call AP_fnc_cyberdeckTerm;   // 3-command Terminal Breach
    if (_r in [0, 1]) then {
        // Breaking & Entering charge + owner/MaxSec notify -- fires whether you got in or not
        [[111, player], "APS_fnc_wantedAdd", false, false] spawn AP_fnc_MP;
        [["houseBreach", _target, player, (_r isEqualTo 1)], "APS_fnc_cyberdeckSRV", 2] spawn AP_fnc_MP;};
    if (_r isEqualTo 1) then {
        // root access -> throw every door open (client-side global, like fn_boltcutter)
        private _nd = getNumber (configFile >> "CfgVehicles" >> typeOf _target >> "numberOfDoors");
        private _shop = (typeOf _target) in ["Land_i_Shop_01_V1_F", "Land_i_Shop_01_V2_F", "Land_i_Shop_01_V3_F"];
        for "_i" from 1 to _nd do {if !(_shop && {_i in [1, 3]}) then {_target setVariable [format ["bis_disabled_Door_%1", _i], 0, true];
                _target animate [format ["door_%1_rot", _i], 1];};};
        _target setVariable ["AP_buildingLocked", false, true];
        titleText ["Locks bypassed. Doors open for 3 minutes.", "PLAIN"];
        [5] call AP_fnc_addInfamy;};};

// ---- VEHICLE / restrained -> Sequence Breach (lockpick path) ----
if (_target isKindOf "LandVehicle" ||
    _target isKindOf "Air" ||
    _target isKindOf "Ship" ||
    {_target getVariable ["AP_restrained", false]}) exitWith {[_target, false, true] spawn AP_fnc_lockpick;};

["No hackable target under your cursor. Aim at a vehicle, a house door, or a mining rig.", "basic"] spawn AP_fnc_handleMessage;
