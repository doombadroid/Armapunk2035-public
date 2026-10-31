#include "..\..\macro.h"
if ((AP_effSide isEqualTo civilian && !(license_civ_bounty)) || (AP_effSide isEqualTo west && !(AP_copRole in ["all", "warrant"])) || AP_effSide isEqualTo independent) exitWith {};
if (scriptAvailable(5)) exitWith {["You must wait 5 seconds to request another bounty.", "basic"] spawn AP_fnc_handleMessage;};
private _maxBountyAmount =
switch (true) do {case (8 in AP_side_talents || AP_effSide isEqualTo west): {5000000};
    case (3 in AP_side_talents): {150000};
    case (2 in AP_side_talents): {100000};
    case (1 in AP_side_talents): {50000};
    default {0};}; private _maxBounties =
switch (true) do {case (4 in AP_side_talents): {4};
    case (AP_effSide isEqualTo civilian): {2};
    case (AP_effSide isEqualTo west): {1};
    default {0};}; if (_maxBountyAmount isEqualTo 0 || _maxBounties isEqualTo 0) exitWith {};
if (count AP_bounty_list >= _maxBounties) exitWith {
    [format["You already have a maximum of %1 bounties.", _maxBounties], "basic"] spawn AP_fnc_handleMessage};
private _initPossibleBounties = (allPlayers - allDeadMen) select {(side _x isEqualTo civilian) && {
        _x getVariable["AP_wantedAmt", -1] <= _maxBountyAmount} && (_x getVariable["AP_wantedAmt", -1] >= 25000)};
if (_initPossibleBounties isEqualTo[]) exitWith {
    ["No bounties are currently available. Please try again later.", "basic"] spawn AP_fnc_handleMessage};
private _finalPossibleBounties = [];
private _weights = []; {private _person = _x;
    private _failedCount = {!(_x)}
    count[!isNull _person, !(AP_allPointsBulletin param[1, "hehe"] isEqualTo(getPlayerUID _person)), (_person getVariable["AP_wantedAmt", 0]) >= 25000, (_person getVariable["AP_wantedAmt", 0]) <= _maxBountyAmount, !((getPlayerUID player) isEqualTo(getPlayerUID _person)), !(_person getVariable["AP_arrested", false]), (_person distance(getMarkerPos "respawn_civilian")) >= 750, (AP_bounty_list findIf {
        getPlayerUID _person in _x}
    isEqualTo - 1), [getPlayerUID _person] call AP_fnc_isUIDActive, !((group _person) isEqualTo(group player)), !(_person getVariable["AP_invisOn", false]), !((_person getVariable["gang_data", [-123]] select 0) isEqualTo(player getVariable["gang_data", [-321]] select 0))];
    if (_failedCount isEqualTo 0) then {_finalPossibleBounties pushBack _person;
        _weights pushBack((_person getVariable "AP_wantedAmt") / 25000);};}
forEach _initPossibleBounties;
if (_finalPossibleBounties isEqualTo[]) exitWith {
    ["No bounties are currently available. Please try again later.", "basic"] spawn AP_fnc_handleMessage};
private _bounty = objNull;
private _dropped = [];
private _exitTime = time + 5;
while {true}
do {if (_finalPossibleBounties isEqualTo[] || !(isNull _bounty) || time > _exitTime) exitWith {};
    private _randomBounty = _finalPossibleBounties selectRandomWeighted _weights;
    if (getPlayerUID _randomBounty in AP_dropped_bounties) then {_dropped pushBack _randomBounty;
        private _bountyIndex = _finalPossibleBounties findIf {_x isEqualTo _randomBounty};
        _finalPossibleBounties deleteAt _bountyIndex;
        _weights deleteAt _bountyIndex;} else {_bounty = _randomBounty;};}; if (isNull _bounty && !(_dropped isEqualTo[])) then {
    _bounty = selectRandom _dropped};
if (isNull _bounty) exitWith {["No bounties are currently available. Please try again later.", "basic"] spawn AP_fnc_handleMessage};
private _trackRadius =
switch (true) do {case (4 in AP_honor_talents && 8 in AP_side_talents): {175};
    case (3 in AP_honor_talents && 8 in AP_side_talents): {210};
    case (2 in AP_honor_talents && 8 in AP_side_talents): {250};
    case (AP_effSide isEqualTo west): {AP_track_radius};
    default {300};}; AP_track_radius = _trackRadius;
private _bountyIndex = count AP_bounty_list;
bounty_task = player createSimpleTask["Bounty Target"];
player setCurrentTask bounty_task;
private _markerCenter = _bounty getPos[[1, AP_track_radius] call BIS_fnc_randomInt, [0, 359] call BIS_fnc_randomInt];
AP_bounty_list pushBack[getPlayerUID _bounty, name _bounty, -2400, _markerCenter];
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
["BountyUpdate", [format["You have been tasked to track and arrest %1.", name _bounty]]] call BIS_fnc_showNotification;
systemChat format["Your new bounty target, %1, is currently wanted for $%2. Located %3, %4 away.", name _bounty, [_bounty getVariable["AP_wantedAmt", -1]] call AP_fnc_numberText, (getMarkerPos _marker2) call BIS_fnc_locationDescription, _distance];
private _bounties = player getVariable["AP_myBounties", []];
_bounties pushBack[getPlayerUID _bounty, _markerCenter];
player setVariable["AP_myBounties", _bounties, true];
AP_bounty_uid pushBack(getPlayerUID _bounty);
[] call AP_fnc_hudUpdate;