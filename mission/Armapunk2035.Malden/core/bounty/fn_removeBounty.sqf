if (!hasInterface) exitWith {};   // LooneyBin: client-only fn -- legacy server senders use target `true` (= server too) -> undefined AP_* vars spammed the RPT (wanted_remove/wantedPardon/playerDisconnected)
params[["_bountyUID", "", [""]], ["_dropped", false, [false]]];
if (isNil "AP_bounty_list") then { AP_bounty_list = [] };   // owner 2026-06-25: nil-guard -- findIf below threw "Undefined variable AP_bounty_list" (JIP/early-call edge, ~2x/restart)
if (isNil "AP_effSide") then { AP_effSide = playerSide };   // PR10: same JIP/early-call edge -- fn_playerDisconnected broadcasts this to every client, including one still loading (before initPlayerLocal:4 defines AP_effSide), and line 4 below raised on it
if (AP_effSide isEqualTo west && !(_dropped) && _bountyUID isEqualTo(AP_allPointsBulletin param[1, "haha"])) exitWith {
    deleteMarkerLocal "bounty_apb";
    deleteMarkerLocal "bounty_dot_apb";
    ["BountyUpdate", [format["Your APB target, %1, is no longer available.", AP_allPointsBulletin select 0]]] call BIS_fnc_showNotification;
};
private _bountyArrayIdx = AP_bounty_list findIf {_bountyUID in _x};
if (_bountyArrayIdx isEqualTo - 1 || _bountyUID isEqualTo "") exitWith {};
// owner 2026-06-20 (#447 BH softlog -- "constant recurring ping"): a short/malformed AP_bounty_list entry left
// _bountyName UNDEFINED, so the BIS_fnc_showNotification line below threw "Undefined variable: _bountyName"
// (live: player020, fn_removeBounty.sqf:16) BEFORE the `deleteAt` further down -> removeBounty aborted ->
// the bounty was NEVER removed from the list -> it kept getting re-processed and re-notifying = the recurring ping.
// Defaults guarantee the vars are always defined so removal completes even on a malformed entry.
// owner 2026-06-20 (b0082 follow-up -- the params-default alone did NOT fix it): `params` with defaults only fires
// when the left side is an ARRAY. A non-array/malformed entry slipped into AP_bounty_list (findIf still matched it),
// and `<non-array> params [...]` assigns NOTHING -- not even the defaults -- so _bountyName stayed undefined and the
// notification below still threw (recurring ping). PREDEFINE the vars so they are always defined, then let params
// overwrite them only when the entry really is an array.
private _bountyPID = ""; private _bountyName = "target"; private _lastTracked = 0;
if ((AP_bounty_list select _bountyArrayIdx) isEqualType []) then {
    (AP_bounty_list select _bountyArrayIdx) params[["_bountyPID", ""], ["_bountyName", "target"], ["_lastTracked", 0]];};
if (_dropped) then {
    ["BountyUpdate", [format["Your bounty target, %1, has been successfully dropped. You may now request a new bounty task.", _bountyName]]] call BIS_fnc_showNotification;
} else {
    ["BountyUpdate", [format["Your bounty target, %1, is no longer available. Request a new bounty task.", _bountyName]]] call BIS_fnc_showNotification;
};
AP_bounty_list deleteAt _bountyArrayIdx;
if !(isNil "bounty_task") then {player removeSimpleTask bounty_task};
if (11 in AP_honor_talents) then {(findDisplay 12 displayCtrl 51) ctrlRemoveEventHandler["Draw", bounty_line]};
for "_i"
from 0 to 5 do {deleteMarkerLocal format["bounty_%1", _i];
    deleteMarkerLocal format["bounty_dot_%1", _i];}; for "_q"
from 0 to(count AP_bounty_list - 1) do {
    // owner 2026-06-20 (#447): defaults + a markerCenter validity guard so a malformed AP_bounty_list entry can't
    // throw here (createMarkerLocal on a non-position errors) and abort the marker rebuild mid-loop. Skip a bad entry
    // instead of leaving the whole list's markers half-rebuilt.
    (AP_bounty_list select _q) params[["_PID", ""], ["_name", "target"], ["_trackedTime", 0], ["_markerCenter", []]];
    if (_markerCenter isEqualType [] && {count _markerCenter >= 2}) then {
        private _marker = createMarkerLocal[format["bounty_%1", _q], _markerCenter];
        _marker setMarkerShapeLocal "ELLIPSE";
        _marker setMarkerSizeLocal[AP_track_radius, AP_track_radius];
        _marker setMarkerTypeLocal "mil_dot";
        _marker setMarkerBrushLocal "DiagGrid";
        _marker setMarkerColorLocal "ColorRed";
        _marker setMarkerTextLocal format["Fugitive %1", _name];
        private _marker2 = createMarkerLocal[format["bounty_dot_%1", _q], _markerCenter];
        _marker2 setMarkerShapeLocal "ICON";
        _marker2 setMarkerTypeLocal "mil_dot";
        _marker2 setMarkerColorLocal "ColorRed";
        _marker2 setMarkerTextLocal format["Fugitive %1", _name];};}; private _bounties = player getVariable["AP_myBounties", []];
if !((_bounties findIf {_bountyUID in _x}) isEqualTo - 1) then {_bounties deleteAt(_bounties findIf {_bountyUID in _x});
    player setVariable["AP_myBounties", _bounties, true];};
[] call AP_fnc_hudUpdate;
if (AP_bounty_list isEqualTo[]) then {if (player getVariable["AP_activeBounty", false]) then {
        player setVariable["AP_activeBounty", nil, true];};};