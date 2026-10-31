params[["_type", [""], [""]]];
if (_type isEqualTo "") exitWith {[]};
private _buyableItems =
switch (_type) do {case ("rebel"): {
            ((["rebel"] call AP_fnc_virt_shops) param[1, []]) + ((["hospital"] call AP_fnc_virt_shops) param[1, []])
        }; case ("skiptracer"): {
                ((["skiptracer"] call AP_fnc_virt_shops) param[1, []]) + ((["hospital"] call AP_fnc_virt_shops) param[1, []])};
        // owner 2026-06-18 (player038): cop + medic loadouts saved ZERO Y items -- this switch only listed
        // rebel/skiptracer as "buyable", so a cop/medic loadout _type fell to the empty default below and the
        // capture loop's `_x in _buyableItems` gate matched nothing. fn_getLoadoutPrice already handles cop + medic;
        // mirror it on the save: cop Y items = the "cop" virtual shop (spikestrips/cones/barriers/tracker/vammo/
        // food), medic = the "meditemshop" shop (defib/bloodbag/FAK/adrenaline/food/deployables).
        case ("cop"): {(["cop"] call AP_fnc_virt_shops) param[1, []]}; case ("medic"): {
                (["meditemshop"] call AP_fnc_virt_shops) param[1, []]};
        default {[]};}; private _buyableItems = _buyableItems arrayIntersect _buyableItems;
private _inventoryArray = []; {private _val = missionNameSpace getVariable format["AP_inv_%1", _x];
    if (_val > 0 && (_x in _buyableItems)) then {_inventoryArray pushBack[_x, _val];};}
forEach([2] call AP_fnc_virtItemCfg);
_inventoryArray
