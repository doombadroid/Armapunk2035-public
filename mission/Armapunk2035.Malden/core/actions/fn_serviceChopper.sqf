disableSerialization;
if (AP_action_in_use) exitWith {["You are already doing an action. Please wait for it to end.", "basic"] spawn AP_fnc_handleMessage};
// LooneyBin 2026-06-09: `air_sp` was never defined anywhere -> fn errored. Service pad = the cop
// Air-HQ helipad (inside AP_air_hq_poly); fall back to the poly centre if no pad object resolves.
private _padObj = (nearestObjects [[15186, 17331, 0], ["Helipad_base_F", "Land_HelipadSquare_F", "Land_HelipadCircle_F"], 150]) param [0, objNull];
private _padPos = if (isNull _padObj) then { [15186, 17331, 0] } else { getPosATL _padObj };
private _search = nearestObjects[_padPos, ["Air"], 8];
if (_search isEqualTo[]) exitWith {["There isn't a chopper on the helipad!", "basic"] spawn AP_fnc_handleMessage};
if (AP_cash < 1000) exitWith {["You need $1,000", "basic"] spawn AP_fnc_handleMessage};
AP_action_in_use = true;
disableSerialization;
5 cutRsc["AP_progress", "PLAIN"];
private _ui = uiNamespace getVariable "AP_progress";
private _text = "Servicing Chopper";
private _progress = _ui displayCtrl 38201;
private _pgText = _ui displayCtrl 38202;
_pgText ctrlSetText format["%2 (1%1)...", "%", _text];
_progress progressSetPosition 0.01;
private _cP = 0.01;
for "_i"
from 0 to 1 step 0 do {uiSleep 0.2;
    _cP = _cP + 0.01;
    _progress progressSetPosition _cP;
    _pgText ctrlSetText format["%3 (%1%2)...", round(_cP * 100), "%", _text];
    if (_cp >= 1) exitWith {};}; private _nearestChopper = _search select 0;
if (!alive _nearestChopper || {_nearestChopper distance air_sp > 15}) exitWith {AP_action_in_use = false;
    ["The vehicle is no longer alive or on the helipad!", "basic"] spawn AP_fnc_handleMessage;};
if (!local _nearestChopper) then {[[_nearestChopper, 1], "AP_fnc_setFuel", _nearestChopper] spawn AP_fnc_MP;} else {
    _nearestChopper setFuel 1;};
private _plb_dmg = _nearestChopper;
_plb_dmg setDamage 0;
AP_cash = AP_cash - 1000;
AP_cashCacheB = ((AP_cash / 4) + 9);
5 cutText["", "PLAIN"];
titleText["Your chopper is now repaired and refuelled.", "PLAIN"];
AP_action_in_use = false;