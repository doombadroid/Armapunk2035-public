/*
    Re-plumbed 2026-08-12 for the web deck. Item, recipient and amount used to come
    only from dialog 361000's controls.

        _this spawn AP_fnc_giveItem;                          // native, unchanged
        [controlNull, "apple", 3, "76561198..."] spawn AP_fnc_giveItem;   // deck
*/
params [["_btn", controlNull], ["_itemIn", "", [""]], ["_qtyIn", -1, [0]], ["_uidIn", "", [""]]];
private _direct = _itemIn isNotEqualTo "";
if (!_direct && {(lbCurSel 361001) isEqualTo -1}) exitWith {["You didn't select an item you wanted to give", "basic"] spawn AP_fnc_handleMessage;
    false};
if (!_direct && {(lbCurSel 361003) isEqualTo -1}) exitWith {["You didn't selected anyone to give this to", "basic"] spawn AP_fnc_handleMessage;
    false};
private _item = if (_direct) then { _itemIn } else { lbData[361001, lbCurSel 361001] };
if (_item isEqualTo "") exitWith {false};
private _tuid = if (_direct) then { _uidIn } else { lbData[361003, lbCurSel 361003] };
private _unit = allUnits param[allUnits findIf {(getPlayerUID _x) isEqualTo _tuid}, objNull];
if ((isNull _unit) || (_unit isEqualTo player)) exitWith {false};
private _itemMax = missionNamespace getVariable(format["AP_inv_%1", _item]);
private _itemQuantity =
if (_direct) then { _qtyIn min _itemMax } else {
    if ((parseNumber(ctrlText 361002)) > _itemMax) then[{_itemMax}, {parseNumber(ctrlText 361002)}]
};
if ((AP_is_processing) && (AP_action_in_use)) exitWith {
    ["You cannot give items while processing", "basic"] spawn AP_fnc_handleMessage;
    false};
if (player getVariable["AP_restrained", false]) exitWith {
    ["Your hands are bound, how can you possibly give that person anything?", "basic"] spawn AP_fnc_handleMessage;
    false};
if (lineIntersects[eyePos player, aimPos _unit, vehicle player, _unit]) exitWith {
    ["It would be hard to pass things through the wall, don't you think?", "basic"] spawn AP_fnc_handleMessage;
    false};
if (_itemQuantity <= 0) exitWith {["You need to enter an actual amount you want to give", "basic"] spawn AP_fnc_handleMessage;
    false};
if !([false, _item, _itemQuantity] call AP_fnc_handleInv) exitWith {
    ["Couldn't give that much of that item, maybe you don't have that amount?", "basic"] spawn AP_fnc_handleMessage;
    false};
if !([str _itemQuantity] call AP_fnc_isNumber) exitWith {["You didn't enter a positive integer.", "basic"] spawn AP_fnc_handleMessage;
}; [[_unit, _itemQuantity, _item, player], "AP_fnc_receiveItem", _unit, false, false] spawn AP_fnc_MP;
[format["You gave %1 %2 %3.", name _unit, _itemQuantity, ["getName", _item] call AP_fnc_virtItemCfg], "basic"] spawn AP_fnc_handleMessage;

[true] call AP_fnc_saveGear;
true