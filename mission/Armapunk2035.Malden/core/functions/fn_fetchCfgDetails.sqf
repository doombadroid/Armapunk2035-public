params[["_entity", "", [""]]];
private _type = -1;
private _acc_p = [];
private _acc_o = [];
private _acc_m = [];
private _slotclasses = [];
private _scope = 0;
private _itemInfo = -1;
private _muzzles = [];
private _magazines = [];
if (_entity isEqualTo "") exitWith {[]};
private _cfg =
if (isNil {_this select 1}) then {switch (true) do {case (isClass(configFile >> "CfgMagazines" >> _entity)): {"CfgMagazines";};
        case (isClass(configFile >> "CfgWeapons" >> _entity)): {"CfgWeapons";};
        case (isClass(configFile >> "CfgVehicles" >> _entity)): {"CfgVehicles";};
        case (isClass(configFile >> "CfgGlasses" >> _entity)): {"CfgGlasses";};};} else {_this select 1};
private _ret = [];
if !(_cfg isEqualType "") exitWith {[]};
if !(isClass(configFile >> _cfg >> _entity)) exitWith {[]};
if (_cfg isEqualTo "") exitWith {[]};
private _config = configFile >> _cfg >> _entity;
private _displayName = getText(_config >> "displayName");
private _picture = getText(_config >> "picture");
private _desc = getText(_config >> "descriptionshort");
private _base = inheritsFrom _config;
switch (_cfg) do {case "CfgVehicles": {_type = getText(_config >> "vehicleClass");
            _scope = getNumber(_config >> "scope");}; case "CfgWeapons": {_scope = getNumber(_config >> "scope");
                _type = getNumber(_config >> "type");
                _desc = getText(_config >> "descriptionshort");
                if (isClass(_config >> "WeaponSlotsInfo")) then {
                    _acc_p = getArray(_config >> "WeaponSlotsInfo" >> "PointerSlot" >> "compatibleItems");
                    _acc_o = getArray(_config >> "WeaponSlotsInfo" >> "CowsSlot" >> "compatibleItems");
                    _acc_m = getArray(_config >> "WeaponSlotsInfo" >> "MuzzleSlot" >> "compatibleItems"); {private "_thiscfgitem";
                        for "_i"
                        from 0 to(count(_x) - 1) do {_thiscfgitem = _x select _i;
                            if (isClass _thiscfgitem) then {if !((configName _thiscfgitem) in _slotclasses) then {
                                    _slotclasses pushBack configName _thiscfgitem;};};};}
                    forEach([_config >> "WeaponSlotsInfo"] call bis_fnc_returnParents);};
                if (isClass(_config >> "ItemInfo")) then {_itemInfo = getNumber(_config >> "ItemInfo" >> "Type");};
                _muzzles = getArray(_config >> "muzzles");
                _magazines = getArray(_config >> "magazines");
                if (!isNil {_muzzles}) then {private["_tmp"]; {if (_x != "this") then {_tmp = getArray(_base >> _x >> "magazines"); {
                                _magazines pushBack _x;}
                            forEach(_tmp);};}
                    forEach _muzzles;};};
        case "CfgMagazines": {_scope = getNumber(_config >> "scope");};}; if (!isNil "_slotclasses") then {
    _slotclasses = _slotclasses - ["MuzzleSlot"];
    _slotclasses = _slotclasses - ["CowsSlot"];
    _slotclasses = _slotclasses - ["PointerSlot"];};
_ret = [_entity, _displayName, _picture, _scope, _type, _itemInfo, _cfg, _magazines, _muzzles, _desc, _acc_p, _acc_o, _acc_m, _base, _slotclasses];
_ret;