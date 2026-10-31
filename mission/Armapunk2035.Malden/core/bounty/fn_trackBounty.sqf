#include "..\..\macro.h"
params[["_bountyIndex", -1, [0]]];
if (_bountyIndex isEqualTo - 1) exitWith {};
if !(isNull objectParent player) exitWith {["You can't track a bounty from within a vehicle!", "basic"] spawn AP_fnc_handleMessage};
private _searchTime =
switch (true) do {case (12 in AP_cop_talents): {120};
    case (11 in AP_cop_talents): {180};
    case (10 in AP_cop_talents): {360};
    case (9 in AP_cop_talents): {480};
    case (AP_effSide isEqualTo west): {540};
    case (6 in AP_honor_talents && 8 in AP_side_talents): {120};
    case (5 in AP_honor_talents && 8 in AP_side_talents): {150};
    default {180};};
( AP_bounty_list select _bountyIndex) params["_bountyPID", "_bountyName", "_lastTracked"];
private _count =
if (7 in AP_honor_talents && 8 in AP_side_talents) then {{serverTime - (_x select 2) < 120}
    count AP_bounty_list;} else {0};
if (_count >= 2) exitWith {private _recentTracked = []; {if (serverTime - (_x select 2) < 120) then {_recentTracked pushBack(_x select 2)};
    }
    forEach AP_bounty_list;
    [format["You can only track two unique targets every 2 minutes, you can track a target again in %1 seconds.", round(_searchTime - (serverTime - (selectMin _recentTracked)))], "basic"] spawn AP_fnc_handleMessage;
};
if ((serverTime - _lastTracked) < _searchTime) exitWith {
    [format["You must wait %1 seconds before tracking this target again.", round((_searchTime + _lastTracked) - serverTime)], "basic"] spawn AP_fnc_handleMessage
};
private _bounty = allPlayers param[allPlayers findIf {_bountyPID isEqualTo(getPlayerUID _x)}, objNull];
if (!isNull _bounty && {_bounty distance getMarkerPos "respawn_civilian" < 750}) exitWith {
    ["The target is currently dead. Please wait a short while and try again.", "basic"] spawn AP_fnc_handleMessage};
deleteMarkerLocal format["bounty_%1", _bountyIndex];
deleteMarkerLocal format["bounty_dot_%1", _bountyIndex];
if (isNull _bounty || {_bounty getVariable["AP_arrested", false] || _bounty getVariable["AP_invisOn", false]}) exitWith {
    [_bountyPID, false] call AP_fnc_removeBounty};
private _trackRadius =
switch (true) do {case (4 in AP_honor_talents && 8 in AP_side_talents): {175};
    case (3 in AP_honor_talents && 8 in AP_side_talents): {210};
    case (2 in AP_honor_talents && 8 in AP_side_talents): {250};
    case (AP_effSide isEqualTo west): {AP_track_radius};
    default {300};}; AP_track_radius = _trackRadius;
private _markerCenter = _bounty getPos[[1, AP_track_radius] call BIS_fnc_randomInt, [0, 359] call BIS_fnc_randomInt];
(AP_bounty_list select _bountyIndex) set[2, serverTime];
(AP_bounty_list select _bountyIndex) set[3, _markerCenter];
if (isNil "bounty_task") then {bounty_task = player createSimpleTask["Bounty Target"];
    player setCurrentTask bounty_task;};
if (11 in AP_honor_talents && 8 in AP_side_talents) then {bounty_pos = _markerCenter;
    bounty_task setSimpleTaskDestination _markerCenter;
    (findDisplay 12 displayCtrl 51) ctrlRemoveEventHandler["Draw", bounty_line];
    bounty_line = (findDisplay 12 displayCtrl 51) ctrlAddEventHandler["Draw", "
		(_this select 0) drawLine [
			getPos player,
			bounty_pos,
			[0,0,1,1]
		];
	"];};
private _marker = createMarkerLocal[format["bounty_%1", _bountyIndex], _markerCenter];
_marker setMarkerShapeLocal "ELLIPSE";
_marker setMarkerSizeLocal[_trackRadius, _trackRadius];
_marker setMarkerTypeLocal "mil_dot";
_marker setMarkerBrushLocal "DiagGrid";
_marker setMarkerColorLocal "ColorRed";
_marker setMarkerTextLocal format["Fugitive %1", name _bounty];
private _marker2 = createMarkerLocal[format["bounty_dot_%1", _bountyIndex], _markerCenter];
_marker2 setMarkerShapeLocal "ICON";
_marker2 setMarkerTypeLocal "mil_dot";
_marker2 setMarkerColorLocal "ColorRed";
_marker2 setMarkerTextLocal format["Fugitive %1", name _bounty];
if (AP_effSide isEqualTo civilian) then {private _toSend = units group player - [player];
    if !(_toSend isEqualTo[]) then {[
            [true, _bounty, _markerCenter, AP_track_radius], "AP_fnc_setGroupMarker", _toSend] spawn AP_fnc_MP;};};
private _distance = str(round(player distance(getMarkerPos _marker2)) / 1000) + " km";
if (round((player distance(getMarkerPos _marker2)) / 1000) < 1) then {_distance = str(round(player distance _bounty)) + " Meters"};
systemChat format["Your bounty target, %1, is now located %3, %4 away.", name _bounty, (getMarkerPos _marker2) call BIS_fnc_locationDescription, _distance];