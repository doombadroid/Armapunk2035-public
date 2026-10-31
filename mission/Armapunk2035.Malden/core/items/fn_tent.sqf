params[["_item", "", [""]]];
private _class =
switch (_item) do {case "tent1": {"Land_TentA_F"}; case "tent2": {"Land_TentDome_F"};}; private _vcap =
switch (_item) do {case "tent1": {150}; case "tent2": {200};
}; if ([200] call AP_fnc_nearTown) exitWith {
    ["You are too close to a populated city to place a tent.", "basic"] spawn AP_fnc_handleMessage};
if ((player distance(getMarkerPos "fed_reserve")) < 700) exitWith {
    ["The Federal Reserve guards do not like you camping so close.", "basic"] spawn AP_fnc_handleMessage};
if !([false, _item, 1] call AP_fnc_handleInv) exitWith {};
closeDialog 0;
player playMove "AinvPknlMstpSnonWnonDnon_medic_1";
uiSleep 1.5;
private _tent = _class createVehicle(player modelToWorld[0, 3, 0]);
_tent setVariable["AP_vinv", [[], 0], true];
_tent setVariable["AP_owner", player, true];
_tent setVariable["AP_placedItem", true, true];
_tent setVariable["AP_vehOwners", [[getPlayerUID player, profileName]], true];
_tent setVariable["AP_vcap", _vcap, true];
// LooneyBin: tag the reaper-checked bare `owner` var. fn_cleanup.sqf:154 instant-deletes objects in `vehicles` with no `owner`
// var while idleTime==0; the tent sets AP_owner (namespaced) but NOT `owner`, and nothing stamps idleTime on a tent, so without
// this it + its AP_vinv contents get reaped on the first ~5-min cleanup sweep (the "tent-shed" vanish -- same class as the
// revive-drone fix #126 / the ownerless-reap convention). Value is nil-checked only by the reaper.
_tent setVariable["owner", getPlayerUID player, true];
[["-TENTDEPLOY-", player, (profileName), format["pitched a tent (%1 | NetID: %2) at POS: %3", _item, netId _tent, getPosATL _tent]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
titleText["You pitch a tent nearby.", "PLAIN"];
AP_side_exp = AP_side_exp + 15;