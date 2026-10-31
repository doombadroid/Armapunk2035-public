disableSerialization;
params[["_control", controlNull, [controlNull]], ["_selection", -1, [0]]];
if (isNull _control || _selection isEqualTo - 1) exitWith {};
private _price = _control lbValue _selection;
private _priceTag = ((findDisplay 39400) displayCtrl 39401);
// owner 2026-07-24 BUGFIX (same defect the owner hit on the GARAGE sell): an ND vehicle CHOPS for New
// Drachma -- fn_chopShopSell credits _price/6000 into the wallet -- but this tag always rendered the raw
// cash figure, so the player is quoted "$80,000" and paid ~13 ND. Resolve the vehicle from lbData (the
// menu stores netId, not the classname) and quote the currency actually paid. ND test matches the server:
// "nd_car" (in an ND shop) or the "nd_priced" currency-only sentinel, in shop-key list idx 3.
private _veh = objectFromNetId (_control lbData _selection);
private _isND = false;
if (!isNull _veh) then {private _keys = (["getVehicleRow", "", typeOf _veh] call AP_fnc_vehicleConfig) param [3, []];
    if (_keys isEqualType []) then { _isND = ("nd_car" in _keys) || {"nd_priced" in _keys}; };};
private _priceTxt = if (_isND) then {format ["%1 ND", [(_price / 6000) toFixed 4] call AP_fnc_ndText]} else {
    format ["$%1", [_price] call AP_fnc_numberText]};
_priceTag ctrlSetStructuredText parseText format["<t size='0.8'>Price: <t color='#8cff9b'>%1</t></t>", _priceTxt];