params[["_pile", objNull, [objNull]]];
if (isNull _pile) exitWith {};
if !((_pile isKindOf "GroundWeaponHolder") || (_pile isKindOf "WeaponHolderSimulated") || (_pile isKindOf "WeaponHolder")) exitWith {};
private _weapons = WeaponCargo _pile;
private _magazines = MagazineCargo _pile;
private _items = itemCargo _pile;
if (({player distance getMarkerPos format["police_hq_%1", _x] < 50}
count[1, 2, 3, 4, 5, 6, 7] > 0) || (((SRV_mobileHQ param[1, objNull]) != objNull) && ((SRV_mobileHQ param[1, objNull]) getVariable["AP_mobileHeadQuartersTruckLocked", false]) && (((SRV_mobileHQ param[1, objNull]) distance2D player) < 20))) exitWith {
    deleteVehicle _pile;
    titleText[format["The items from this pile have been seized into evidence!."], "PLAIN"];};
private _wepItems = []; {for "_i"
    from 1 to 3 do {if !((_x select _i) isEqualTo "") then {_wepItems = _wepItems + [_x select _i]};
    }; if !((_x select 4 select 0) isEqualTo "") then {_wepItems = _wepItems + [_x select 4 select 0];};}
forEach weaponsItemsCargo _pile;
if ((_weapons + _magazines + _wepItems + _items) isEqualTo[]) exitWith {
    ["What are you even trying to seize here?", "basic"] spawn AP_fnc_handleMessage};
private _near = nearestObjects[_pile, ["Car", "Air", "Ship"], 30];
private _nearVehicle = _near param[_near findIf {_x getVariable["AP_side", ""] isEqualTo "cop"}, objNull];
if (isNull _nearVehicle) exitWith {["There aren't any nearby police vehicles to seize this into!", "basic"] spawn AP_fnc_handleMessage;};
if !(alive _nearVehicle) exitWith {
    ["You cannot seize items into a vehicle which has been destroyed!", "basic"] spawn AP_fnc_handleMessage;}; {
    _nearVehicle addItemCargoGlobal[_x, 1];}
forEach(_weapons + _magazines + _wepItems + _items);
deleteVehicle _pile;
titleText["The illegal items from this pile have been seized into the nearest police vehicle. The items can be placed into evidence from any Police HQ.", "PLAIN"];