if !(backpack player isEqualTo "") exitWith {
    ["You can't be wearing a backpack when you skydive. Parachutes are somewhat essential!", "basic"] spawn AP_fnc_handleMessage};
if (player getVariable["AP_restrained", false]) exitWith {
    ["You probably want your hands unbound to pull a parachute cord.", "basic"] spawn AP_fnc_handleMessage};
private _cops = allPlayers select {(player distance _x) <= 1000 && side _x isEqualTo west};
if ((A_stats_crimes select 0) > 0 && !(_cops isEqualTo[])) exitWith {
    ["You cannot skydive when there is a cop within one kilometre and you're actively wanted by the police.", "basic"] spawn AP_fnc_handleMessage
};
if !([200] call AP_fnc_debitCard) exitWith {};
private _dropPosition = position player;
_dropPosition set[2, 5000];
cutText["", "BLACK OUT", 3];
uiSleep 3;
if (isWeaponDeployed player) then {player playMove ""};
cutText["You are approaching the drop zone.  Get ready!", "BLACK FADED"];
0 cutFadeOut 999999;
private _plb_pos = getMarkerPos "sky_dive";
player setPos _plb_pos;
player addBackpack "B_Parachute";
0 fadeSound 0;
2 fadeSound 1;
for "_i"
from 0 to 5 do {playSound "airplane";
    uiSleep 2.2;
    switch (_i) do {case 3: {playSound "racebeep1"};
        case 4: {playSound "racebeep1"};
        case 5: {playSound "racebeep2"};};};
["action", "skydive", 1 ] spawn AP_fnc_handleQuest;
player setPosASL _dropPosition;
private _draw = viewDistance;
setViewDistance 6000;
if (cameraView isEqualTo "EXTERNAL") then {player switchCamera "INTERNAL"};
cutText["", "BLACK IN", 0.75];
private "_newDistance";
while {(getPos player) select 2 > 100}
do {uiSleep 1;
    _newDistance = (((getPos player) select 2) + 1000);
    if (_newDistance > _draw) then {setViewDistance _newDistance};}; waitUntil {(getPos player) select 2 < 10;};
setViewDistance _draw;