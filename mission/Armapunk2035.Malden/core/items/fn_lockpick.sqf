params[["_unit", objNull, [objNull]], ["_boltcut", false, [false]], ["_useDeck", false, [false]]];
if !(AP_effSide isEqualTo civilian) exitWith {["You must be a civilian.", "basic"] spawn AP_fnc_handleMessage;};
// LooneyBin 2026-07-18: Cyberdeck hacks ANY vehicle -- the "too advanced" (O_Truck_03) block + the heavy/air talent gates are gone.
if !(isNull objectParent player) exitWith {["You cannot lockpick while inside a vehicle.", "basic"] spawn AP_fnc_handleMessage;};
if (player distance getmarkerPos "courtroom" < 75 || AP_action_in_use) exitWith {};
if !(_unit isKindOf "LandVehicle" || _unit isKindOf "Air" || _unit isKindOf "Ship" || _unit getVariable["AP_restrained", false]) exitWith {
    ["You cannot lockpick this unit.", "basic"] spawn AP_fnc_handleMessage;};
// LooneyBin: distance is to the vehicle CENTER, so huge vehicles (Blackfish ~15m) put you >7m
// away even while standing at the door -> un-lockpickable. Scale the reach by the vehicle's size.
if (player distance _unit > (7 + (0.5 * sizeOf (typeOf _unit)))) exitWith {
    ["You need to be closer to the vehicle!", "basic"] spawn AP_fnc_handleMessage;};
if (player getVariable["AP_surrendered", false]) exitWith {
    ["You probably need your hands free to lockpick this!", "basic"] spawn AP_fnc_handleMessage;};
if (_unit getVariable["AP_side", ""] isEqualTo "med") exitWith {["Medical vehicles are unable to be stolen!", "basic"]};
if (_unit in AP_vehicles) exitWith {["This vehicle is already in your keychain.", "basic"] spawn AP_fnc_handleMessage;};
// (heavy-vehicle talent 58 + helicopter talent 59 gates removed 2026-07-18 -- the Cyberdeck hacks any vehicle; lock tier sets difficulty)
if (_boltcut && (_unit isKindOf "LandVehicle" || _unit isKindOf "Air" || _unit isKindOf "Ship")) exitWith {};
if ((player getVariable["AP_adminRestrain", false]) || (player getVariable["AP_restrained", false])) exitWith {
    ["You cannot do that while restrained!", "basic"] spawn AP_fnc_handleMessage;};
if (_boltcut && !(AP_inv_boltCutter >= 1)) exitWith {};
if (_useDeck && !(call AP_fnc_hasDeck)) exitWith {};   // 0.2.0: deck is FIRMWARE (AP_cdMods id 0), not the retired AP_inv_cyberdeck item -- the item->firmware migration zeroed that counter so the old gate killed every deck unlock
if (!_boltcut && !_useDeck) exitWith {};   // lockpick item retired -- deck (or boltcutter) only
closeDialog 0;
private _owners = _unit getVariable["AP_vehOwners", []];
private _isMilitary = (typeOf _unit) in ["O_MRAP_02_F", "B_MRAP_01_F", "I_MRAP_03_F", "O_APC_Wheeled_02_rcws_v2_F"];
private _isBountyVehicle = !((AP_bounty_list findIf {((_owners select 0) select 0) in _x}) isEqualTo - 1);
private _dice = random 100;
private _alarmSound =
if !(_unit isKindOf "Air") then {"airalarm"} else {"caralarm"};
private _chance = 20;
if (_isMilitary) then {_chance = 5;};
if (_unit isKindOf "Air") then {_chance = 10;};
if (_unit isKindOf "CAManBase" && (454 in AP_completedLifetimeQuests)) then {_chance = _chance + 10;};
if ((_unit getVariable["AP_side", ""] isEqualTo "cop") && (459 in AP_completedLifetimeQuests)) then {_chance = _chance + 10;};
if (57 in AP_side_talents) then {_chance = _chance + 10;};
if (15 in AP_honor_talents && license_civ_bounty && 8 in AP_side_talents) then {_chance = _chance + 10;};
if (5 in AP_infamy_talents && license_civ_rebel) then {_chance = _chance + 10;};
if (_boltcut) then {_chance = _dice;};
private _vehicleMods = _unit getVariable["AP_mods", [0, 0, 0, 0, 0, 0, 0, 0, 0]];
disableSerialization;
private _success = false;
// owner 2026-07-21: DEADBOLT CHIP (Ghost Key counter). A deadbolted vehicle has no electronic lock left to
// breach at all, so the deck refuses outright and the thief is pushed onto the boltcutter -- slower, louder,
// and it wakes the neighbourhood. Deliberately NOT a fail roll: it is a hard wall you route around.
if (_useDeck && {_unit getVariable ["AP_deadbolt", false]} && {!(_unit isKindOf "CAManBase")}) exitWith {AP_action_in_use = false;
    ["<t color='#ff3b1e'>DEADBOLT</t> -- mechanical lock, no electronics to breach. Boltcutters or nothing.", "basic"] spawn AP_fnc_handleMessage;
};
if (_useDeck) then {
    // LooneyBin 2026-07-18: Cyberdeck -- SEQUENCE BREACH. Buffer length = the lock tier AP_mods[7] (0/1/2/3 -> 4/6/10/12)
    private _bufLen = switch (_vehicleMods select 7) do { case 1: { 6 }; case 2: { 10 }; case 3: { 12 }; default { 4 } };
    AP_action_in_use = true;
    private _res = [_bufLen] call AP_fnc_cyberdeckSeq;
    AP_action_in_use = false;
    _success = (_res isEqualTo 1);
    if (_res isEqualTo 1) then {_dice = 0;   // a clean breach guarantees keys (skip the legacy break roll)
    };
    if (_res isEqualTo 0) then {
        // trace landed -> the car alarm blares to everyone nearby (owner decision)
        if !(_unit isKindOf "CAManBase") then {private _toSend = (allPlayers - allDeadMen) select { (_x distance _unit) <= 80 };
            [[_unit, "jewelryAlarm"], "AP_fnc_playSound", _toSend] spawn AP_fnc_MP;};};};
if (!_useDeck) then {5 cutRsc["AP_progress", "PLAIN"];
private _text =
if (_boltcut) then {"Boltcutting..."} else {"Lockpicking..."};
private _ui = uiNamespace getVariable "AP_progress";
private _progress = _ui displayCtrl 38201;
private _pgText = _ui displayCtrl 38202;
_pgText ctrlSetText format["%2 (1%1)...", "%", _text];
_progress progressSetPosition 0.01;
private _cP = 0.01;
AP_action_in_use = true;
_success = false;
private _delay = 0.06;
if (13 in AP_honor_talents && license_civ_bounty && 8 in AP_side_talents) then {_delay = _delay - 0.01;};
if (14 in AP_honor_talents && license_civ_bounty && 8 in AP_side_talents) then {_delay = _delay - 0.01;};
if (2 in AP_infamy_talents && license_civ_rebel) then {_delay = _delay - 0.006;};
if (3 in AP_infamy_talents && license_civ_rebel) then {_delay = _delay - 0.006;};
if (4 in AP_infamy_talents && license_civ_rebel) then {_delay = _delay - 0.006;};
if ((_vehicleMods select 7) isEqualTo 1) then {_delay = _delay + 0.02;};
if ((_vehicleMods select 7) isEqualTo 2) then {_delay = _delay + 0.035;};
if ((_vehicleMods select 7) isEqualTo 3) then {_delay = _delay + 0.05;};
if (_boltcut) then {_delay = 0.15};
if !(_unit isKindOf "CAManBase") then {if ((_vehicleMods select 0) isEqualTo 1) then {private _toSend = (allPlayers - allDeadMen) select {
            (_x distance player) <= 50}; [[_unit, _alarmSound], "AP_fnc_playSound", _toSend] spawn AP_fnc_MP;};};
["AinvPknlMstpSnonWnonDnon_medic_1", 1.5] spawn AP_fnc_handleAnim;
for "_i"
from 0 to 1 step 0 do {uiSleep _delay;
    _cP = _cP + 0.01;
    _progress progressSetPosition _cP;
    _pgText ctrlSetText format["%3 (%1%2)...", round(_cP * 100), "%", _text];
    if (!AP_action_in_use || player distance _unit > 10) exitWith {};
    if (player distance _unit > 10) exitWith {};
    if (isWeaponDeployed player) exitWith {};
    if (!alive player || player getVariable["AP_downed", false]) exitWith {};
    if (player getVariable["AP_adminRestrain", false] || player getVariable["AP_restrained", false] || player getVariable["AP_surrendered", false]) exitWith {
        ["You probably need your hands free to lockpick this!", "basic"] spawn AP_fnc_handleMessage;};
    if (_cp >= 1) exitWith {_success = true;};}; 5 cutText["", "PLAIN"];};
AP_action_in_use = false;
[] spawn AP_fnc_handleAnim;
if !(_success) exitWith {};
if (!_useDeck) then {if (_boltcut) then {[false, "boltCutter", 1] call AP_fnc_handleInv;} else {
        [false, "lockpick", 1] call AP_fnc_handleInv;};};
if (_unit isKindOf "CAManBase") then {if (_dice <= _chance) then {titleText["You have unrestrained this player.", "PLAIN"];
        [_unit] spawn AP_fnc_unrestrain; [[24, player], "APS_fnc_wantedAdd", false, false] spawn AP_fnc_MP;
        AP_side_exp = AP_side_exp + 30; [
            ["-LOCKPICKED-", player, (profileName), format["successfully lockpicked player %1 at POS: %2", name _unit, getPosATL player]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
        if (_boltcut) then {["boltcutted", 1] call AP_fnc_statArrUpdate;} else {["picksuccess", 1] call AP_fnc_statArrUpdate;};
        if (!_boltcut) then {["action", "lockpickplayer", 1] call AP_fnc_handleQuest;};} else {titleText["The lockpick broke.", "PLAIN"];
        ["pickfail", 1] call AP_fnc_statArrUpdate;};} else {if (_dice <= _chance) then {["picksuccess", 1] call AP_fnc_statArrUpdate;
        titleText["You now have keys to this vehicle.", "PLAIN"];
        AP_vehicles pushBack _unit;
        _owners pushBack[getPlayerUID player, profileName];
        _unit setVariable["AP_vehOwners", _owners, true];
        if !(AP_effSide isEqualTo west) then {private _chance = 0;
            private _ownerPID = (_owners select 0) select 0;
            private _idx = AP_bounty_list findIf {_ownerPID in _x};
            if !(_idx isEqualTo - 1) then {_chance =
                switch (true) do {case (21 in AP_honor_talents && 126 in AP_side_talents): {30};
                    case (20 in AP_honor_talents && 126 in AP_side_talents): {20};
                    case (19 in AP_honor_talents && 126 in AP_side_talents): {10};};};
            if (random 100 < _chance) exitWith {}; [[21, player], "APS_fnc_wantedAdd", false, false] spawn AP_fnc_MP;};
        [_unit, 900] call AP_fnc_setVehicleIdle;
        AP_side_exp = AP_side_exp + 40; [
            ["-LOCKPICKED-", player, (profileName), format["successfully lockpicked vehicle %1 at POS: %2", typeOf _unit, getPosATL player]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
        ["action", "lockpickvehicle", 1] call AP_fnc_handleQuest;
        if (_unit getVariable["AP_side", ""] isEqualTo "cop") then {["action", "lockpickcopvehicle", 1] call AP_fnc_handleQuest;};
        // owner 2026-07-21 (Ghost Key spec): a DECK breach is silent -- no alarm -- but it leaves a log the
        // owner can follow. The server pushes the intrusion + 10s trace window to any online keyholder, so
        // stealing a car now carries the same trace-back risk every other quickhack does. Boltcutting stays
        // loud-but-untraceable: the two theft routes trade noise against forensics.
        if (_useDeck) then {[["ghostkey", _unit, player], "APS_fnc_cyberdeckSRV", 2] spawn AP_fnc_MP;};
        [5] call AP_fnc_addInfamy;} else {if !(AP_effSide isEqualTo west) then {[
                [16, player], "APS_fnc_wantedAdd", false, false] spawn AP_fnc_MP;};
        titleText["The lockpick broke.", "PLAIN"];
        [_unit, 900] call AP_fnc_setVehicleIdle;
        ["pickfail", 1] call AP_fnc_statArrUpdate;};};