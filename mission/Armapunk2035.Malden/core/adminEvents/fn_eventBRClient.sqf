if !(AP_effSide isEqualTo civilian) exitWith {};
if (AP_adminEvent select 1) exitWith {["You cannot join the admin event in progress.", "basic"] spawn AP_fnc_handleMessage;};
if (player getVariable["AP_downed", false] || player getVariable["AP_restrained", false] || ((AP_is_arrested param [0,0]) isEqualTo 1)) exitWith {
    ["You cannot join the admin event at this time.", "basic"] spawn AP_fnc_handleMessage;}; [
    [true, player], "APS_fnc_eventParticipants", 2] spawn AP_fnc_MP;
AP_inEvent = true;
private _preEventLoadout = getUnitLoadout player;
private _preEventSkins = AP_uniformBackpack_skins;
private _preEventPos =
if (surfaceIsWater(getPosATL player)) then {getPosASL player} else {getPosATL player};
private _plb_player = player;
private _location = (["getLocationByID", (AP_adminEvent select 3)] call AP_fnc_eventCfg) select 2; {_x params["_item"];
    private _num = missionNamespace getVariable(format["AP_inv_%1", _item]);
    if (_num > 0) then {[false, _item, _num] call AP_fnc_handleInv};}
forEach["defib", "bloodbag", "smash", "redgull"];
if !(isNull objectParent player) then {moveOut player;};
[_location, 0, {AP_adminEvent select 1}, "Battle Royale Admin Event"] spawn AP_fnc_uavCinematic;
titleText["Welcome to the Battle Royale Admin Event<br/>To win, you must be the last survivor<br/>The event zone will shrink forcing you toward the center<br/>You must stay within this zone to stay alive<br/>May the best shooter win!", "PLAIN", -1, true, true];
disableUserInput true;
AP_old_group = group player;
[player] join grpNull;
uiSleep 2;
private _plb_pos = _location;
while {_plb_pos isEqualTo _location}
do {_plb_pos = [(_location), 1, 250, 1, 0, 0, 0, [], _location] call BIS_fnc_findSafePos;}; player setPos _plb_pos;
private _centerPosition = _location;
private _eventLoadout = [["arifle_MX_Black_F", "", "acc_flashlight", "optic_Arco_blk_F", ["30Rnd_65x39_caseless_black_mag", 30], [], ""],
    [], [], ["U_O_Wetsuit", [["30Rnd_65x39_caseless_black_mag", 5, 30]]], ["V_TacVest_blk", [["30Rnd_65x39_caseless_black_mag", 10, 30]]],
    [], "", "G_Aviator", [], ["ItemMap", "ItemGPS", "", "ItemCompass", "ItemWatch", "Integrated_NVG_F"]];
player setUnitLoadout _eventLoadout;
player addBackpack "B_Parachute";
player action["SwitchWeapon", player, player, 100];
uiSleep 2.5;
private _plb_pos = _location;
while {_plb_pos isEqualTo _location}
do {_plb_pos = [_location, 1, 250, 1, 0, 0, 0, [], _location] call BIS_fnc_findSafePos;}; _plb_pos set[2, 600];
waitUntil {AP_adminEvent select 1};
disableUserInput false;
if (sunOrMoon < 0.5) then {player action["nvGoggles", player];};
[true, "firstAidKit", 2] call AP_fnc_handleInv;
uiSleep 1;
player setPos _plb_pos;
player setDir((direction player) + (player getRelDir _centerPosition));
player setDamage 0;
[] spawn {uiSleep 0.25;
    player playActionNow "halofreefall_non";
    player switchCamera "EXTERNAL";};
private _task = player createSimpleTask["AE_BattleRoyale_Task"];
_task setSimpleTaskDescription["", "Battle Royale", ""];
_task setSimpleTaskDestination _centerPosition;
_task setTaskState "Assigned";
player setCurrentTask _task;
["AE_BattleRoyale_Zone"] spawn {_this params[["_safeZoneMarker", ""]];
    if (_safeZoneMarker isEqualTo "") exitWith {};
    for "_i"
    from 0 to 1 step 0 do {if ((markerPos _safeZoneMarker) isEqualTo[0, 0, 0]) exitWith {};
        if !((backpack player) isEqualTo "B_Parachute") exitWith {};
        if (AP_isDead || !(AP_inEvent)) exitWith {AP_inEvent = false};
        private _forceDeployAltitude = 100;
        if (((position player) select 2) <= _forceDeployAltitude) then {player action["OpenParachute", player];};
        uiSleep 0.25;};};
["AE_BattleRoyale_Zone"] spawn {_this params[["_safeZoneMarker", ""]];
    if (_safeZoneMarker isEqualTo "") exitWith {};
    private _handle = ppEffectCreate["ColorCorrections", 25000];
    _handle ppEffectEnable true;
    for "_i"
    from 0 to 1 step 0 do {if ((markerPos _safeZoneMarker) isEqualTo[0, 0, 0]) exitWith {};
        if (AP_isDead || !(AP_inEvent)) exitWith {AP_inEvent = false};
        if !((position player) inArea _safeZoneMarker) then {player setDamage((damage player) + 0.005);
            _handle ppEffectAdjust[1, 1, 0, [1, 1, 1, 0], [1, 0, 0, 0.75], [0.75, 0.25, 0, 1.0]];
            [500] call BIS_fnc_bloodEffect;} else {
            _handle ppEffectAdjust[1, 1, 0, [0, 0, 0, 0], [1, 1, 1, 1], [0.299, 0.587, 0.114, 0], [-1, -1, 0, 0, 0, 0, 0]];};
        _handle ppEffectCommit 0.50;
        uiSleep 0.50;}; ppEffectDestroy _handle;};
waitUntil {!AP_inEvent}; [[false, player], "APS_fnc_eventParticipants", 2] spawn AP_fnc_MP;
["Respawn to be sent back to your previous position with your gear", "warning"] spawn AP_fnc_handleMessage;
waitUntil {!AP_isDead && !(player distance(getMarkerPos "respawn_civilian") < 1000)};
uiSleep 10;
if (AP_isDead) then {
    ["You have 45 seconds to respawn, in order to keep your pre-event position and loadout!", "basic"] spawn AP_fnc_handleMessage;
    uiSleep 45;};
player removeSimpleTask _task;
player setUnitLoadout _preEventLoadout;
AP_uniformBackpack_skins = _preEventSkins;
if (surfaceIsWater _preEventPos) then {player setPosASL _preEventPos} else {player setPosATL _preEventPos};
_plb_player setDamage 0;
[player] joinSilent AP_old_group;
titleText["You have been given back your previous loadout", "PLAIN"];
[] spawn {uiSleep 0.5;
    [uniform player, "setUniform", ""] call AP_fnc_clothingTextures;
    [backpack player, "setBackpack", ""] call AP_fnc_clothingTextures;
    [] call AP_fnc_hudUpdate;};