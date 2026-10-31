params[["_unit", player], ["_button", controlNull]];
if ((isNull _unit) || (!alive _unit)) exitWith {};
if (isNil "AP_uniformCooldown") then {AP_uniformCooldown = 0};
if ((!isNull _button) && (AP_uniformCooldown > time)) exitWith {};
if (!isNull _button) then {_button ctrlEnable false};
private _cooldown = 150;
AP_uniformCooldown = time + _cooldown;
private _containerItems = {params[["_unit", objNull], ["_containerItems", []], ["_container", objNull]];
    if ((isNull _unit) || (!alive _unit)) exitWith {};
    private _magazinesAmmo = magazinesAmmoCargo _container;
    private _items = []; {_x params["_item"];
        if (_item in (magazines _unit)) then {private _index = _magazinesAmmo findIf {(_x select 0) isEqualTo _item};
            if !(_index isEqualTo - 1) then {_items pushBack(_magazinesAmmo select _index);
                _magazinesAmmo deleteAt _index;};} else {_items pushBack _item;};}
    forEach _containerItems;
    _items};
private _vest = vest _unit;
private _uniform = uniform _unit;
private _vestItems = [_unit, vestItems _unit, vestContainer _unit] call _containerItems;
private _uniformItems = [_unit, uniformItems _unit, uniformContainer _unit] call _containerItems;
if ((isNull _unit) || (!alive _unit)) exitWith {};
removeUniform _unit;
removeVest _unit;
_unit addVest _vest; {if (_x isEqualType[]) then {(vestContainer _unit) addMagazineAmmoCargo[_x select 0, 1, _x select 1];} else {
        _unit addItemToVest _x;};}
forEach _vestItems;
_unit forceAddUniform _uniform; {if (_x isEqualType[]) then {(uniformContainer _unit) addMagazineAmmoCargo[_x select 0, 1, _x select 1];
    } else {_unit addItemToUniform _x;};}
forEach _uniformItems;
[] spawn {uiSleep 0.5;
    [uniform player, "setUniform", ""] call AP_fnc_clothingTextures;
    [backpack player, "setBackpack", ""] call AP_fnc_clothingTextures;};