params[["_retrack", false, [false]]];
if (AP_allPointsBulletin isEqualTo[]) exitWith {};
if (_retrack && !(isNull objectParent player)) exitWith {
    ["You can't track a bounty from within a vehicle!", "basic"] spawn AP_fnc_handleMessage};
private _searchTime =
switch (true) do {case (12 in AP_cop_talents): {120};
    case (11 in AP_cop_talents): {180};
    case (10 in AP_cop_talents): {360};
    case (9 in AP_cop_talents): {480};
    case (AP_effSide isEqualTo west): {540};
    default {180};}; AP_allPointsBulletin params["_bountyName", ["_bountyPID", "doodoo"], "_bountyPrice", ["_lastTracked", -2400]];
if ((serverTime - _lastTracked) < _searchTime) exitWith {
    [format["You must wait %1 seconds before tracking this target again.", round((_searchTime + _lastTracked) - serverTime)], "basic"] spawn AP_fnc_handleMessage
};
private _bounty = allPlayers param[allPlayers findIf {_bountyPID isEqualTo(getPlayerUID _x)}, objNull];
if (!isNull _bounty && {_bounty distance getMarkerPos "respawn_civilian" < 750}) exitWith {
    ["The target is currently dead. Please wait a short while and try again.", "basic"] spawn AP_fnc_handleMessage};
deleteMarkerLocal "bounty_apb";
deleteMarkerLocal "bounty_dot_apb";
if (isNull _bounty || {_bounty getVariable["AP_arrested", false]}) exitWith {[_bountyPID, false] call AP_fnc_removeBounty};
private _trackRadius = AP_track_radius;
private _markerCenter = _bounty getPos[[1, AP_track_radius] call BIS_fnc_randomInt, [0, 359] call BIS_fnc_randomInt];
if (_retrack) then {AP_allPointsBulletin set[3, serverTime];};
private _marker = createMarkerLocal["bounty_apb", _markerCenter];
_marker setMarkerShapeLocal "ELLIPSE";
_marker setMarkerSizeLocal[_trackRadius, _trackRadius];
_marker setMarkerTypeLocal "mil_dot";
_marker setMarkerBrushLocal "DiagGrid";
_marker setMarkerColorLocal "ColorRed";
_marker setMarkerTextLocal format["Fugitive %1", name _bounty];
private _marker2 = createMarkerLocal["bounty_dot_apb", _markerCenter];
_marker2 setMarkerShapeLocal "ICON";
_marker2 setMarkerTypeLocal "mil_dot";
_marker2 setMarkerColorLocal "ColorRed";
_marker2 setMarkerTextLocal format["Fugitive %1", name _bounty];
private _distance = str(round(player distance(getMarkerPos _marker2)) / 1000) + " km";
if (round((player distance(getMarkerPos _marker2)) / 1000) < 1) then {_distance = str(round(player distance _bounty)) + " Meters"};
systemChat format["Your bounty target, %1, is now located %3, %4 away.", name _bounty, (getMarkerPos _marker2) call BIS_fnc_locationDescription, _distance];