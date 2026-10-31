params[["_itemType", 0, [0]], ["_item", "", [""]]];
if (_itemType isEqualTo 0 || _item isEqualTo "") exitWith {};
private _vars =
switch (_itemType) do {case 1: {[{vest player;}, {removeVest player;}, "this vest"]};
    case 2: {[{backpack player;}, {removeBackpack player;}, "this backpack"]};
    case 3: {[{uniform player;}, {removeUniform player;}, "this uniform"]};
    case 4: {[{headgear player;}, {removeHeadgear player;}, "this headgear"]};
    case 5: {[{goggles player;}, {removeGoggles player;}, "these goggles"]};
    case 6: {[{primaryWeapon player;}, {player removeWeapon _item;}, "this weapon"]};
    case 7: {[{secondaryWeapon player;}, {player removeWeapon _item;}, "this weapon"]};
    case 8: {[{handgunWeapon player;}, {player removeWeapon _item;}, "this weapon"]};
    default {[]};}; if (_vars isEqualTo[]) exitWith {};
_vars params["_type", "_remove", "_text"];
if (((call _type) find _item) >= 0) then {private _gwh = createVehicle["GroundWeaponHolder", getPosATL player, [], 0, "CAN_COLLIDE"];
    _gwh addItemCargoGlobal[call _type, 1]; [[_gwh, 300], "APS_fnc_setCleanTime", 2] spawn AP_fnc_MP;
    call _remove;
    [format["You cannot use %1!", _text], "basic"] spawn AP_fnc_handleMessage;};