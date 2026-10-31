if (isNull(findDisplay 1800)) exitWith {};
disableSerialization;
ctrlEnable[1830, false];
private _display = findDisplay 1800;
private _recipeItems = _display displayCtrl 1860;
private _title = _display displayCtrl 1865;
private _description = _display displayCtrl 1855;
private _class = lbData[1850, lbCurSel 1850];
private _skinsList = _display displayCtrl 1804;
lbClear _skinsList;
_skinsList ctrlEnable false;
private _name = "Item";
private _index = -1;
private _items = [_class] call AP_fnc_recipeDetail;
private _desc = "No description available."; (switch (true) do {case (isClass(configFile >> "CfgWeapons" >> _class)): {
            ["CfgWeapons", getText(configFile >> "CfgWeapons" >> _class >> "displayName")]};
    case (isClass(configFile >> "CfgVehicles" >> _class)): {
            ["CfgVehicles", getText(configFile >> "CfgVehicles" >> _class >> "displayName")]};
    case (isClass(configFile >> "CfgMagazines" >> _class)): {
            ["CfgMagazines", getText(configFile >> "CfgMagazines" >> _class >> "displayName")]};}) params["_cfgClass", "_displayName"];
switch (_cfgClass) do {case "CfgWeapons": {_name = _displayName;
            private _prices = AP_factory_prices;
            _index = [_class, _prices] call AP_fnc_index;
            _desc = format["<t size='1'>Sell Price: <t color='#8cff9b'>$%1</t><br/>Type: %2", [0.65 * ((_prices select _index) select 1)] call AP_fnc_numberText, getText(configFile >> "cfgWeapons" >> _class >> "descriptionShort")];
        }; case "CfgVehicles": {
                private _vehicleInfo = ([_class] call AP_fnc_fetchVehInfo) params["_class", "_scope", "_pic", "_displayName", "_vehicleClass", "_side", "_faction", "_superClass", "_speed", "_armor", "_transportSoldier", "_enginePower", "_fuelCap"];
                _name = _displayName;
                private _cfgRow = ["getVehicleRowParsed", "", _class] call AP_fnc_vehicleConfig;
                private _buyPrice = _cfgRow select 7;
                private _sellPrice = _buyPrice * 0.65;
                private _trunkSpace = _cfgRow select 10;
                _desc = format["<t size='1'>Base Price: <t color='#8cff9b'>$%1</t>  Sell Price: <t color='#8cff9b'>$%2</t><br/>Max Speed: %3 km/h<br/>Horse Power: %4<br/>Passenger Seats: %5<br/>Trunk Capacity: %6<br/>Fuel Capacity: %7<br/>Armor Rating: %8", [_buyPrice] call AP_fnc_numberText, [_sellPrice] call AP_fnc_numberText, _speed, _enginePower, _transportSoldier, _trunkSpace, _fuelCap, _armor];
                private _textureArray = ["allClass", _class] call AP_fnc_vehicleTextures;
                private _copLevel = call AP_copLevel;
                private _medicLevel = call AP_medicLevel;
                private _donorLevel = 10;
                private _adminLevel = call AP_adminLevel;
                for "_i"
                from 0 to(count(_textureArray) - 1) do {private _temp = _textureArray select _i;
                    if ((((_temp select 2) select 0) in ["civ", "reb"]) && ((_temp select 3) isEqualTo "")) then {
                        if ((_copLevel >= _temp select 4) && (_medicLevel >= _temp select 5) && (_adminLevel >= _temp select 6) && ((_donorLevel >= _temp select 7) || ((getPlayerUID player) in (_temp select 9)))) then {
                            if ((_temp select 8) isEqualTo - 1) then {_skinsList lbAdd format["%1", _temp select 10];
                                _skinsList lbSetValue[(lbSize _skinsList) - 1, _temp select 0];} else {
                                
                                    _skinsList lbAdd format["%1", _temp select 10];
                                    _skinsList lbSetValue[(lbSize _skinsList) - 1, _temp select 0];
};};};}; _skinsList ctrlEnable((lbSize _skinsList) >= 1);
                _skinsList lbSetCurSel 0;};
        case "CfgMagazines": {_name = _displayName;
                _desc = "Ammunition for a weapon";};}; _title ctrlSetStructuredText parseText format["<t size='1.75'>%1</t>", _name];
_description ctrlSetStructuredText parseText _desc;
lbClear _recipeItems;
if ((AP_gang_data param[0, -3]) isEqualTo(panagia_flag getVariable["AP_turf_data", []] param[0, -2])) then {{
        _x params["_item", "_amount"];
        _x set[1, ceil(_amount * 0.75)];}
    forEach _items;};
private _isQuest491 = ((491 in AP_completedLifetimeQuests) && (_class in ["B_MRAP_01_F", "O_MRAP_02_F"]));
private _isQuest492 = ((492 in AP_completedLifetimeQuests) && ((([_class] call BIS_fnc_itemType) param[1, "Gun"]) in ["AssaultRifle", "Handgun", "Launcher", "MachineGun", "Shotgun", "SubmachineGun", "SniperRifle", "Rifle"]));
if (_isQuest491 || _isQuest492) then {{_x params["_item", "_amount"];
        private _toReduce =
        switch (true) do {case ((491 in AP_completedLifetimeQuests) && (_isQuest491)): {0.90};
            case ((492 in AP_completedLifetimeQuests) && (_isQuest492)): {0.90};
            default {1};}; _x set[1, ceil(_amount * _toReduce)];}
    forEach _items;};
private _isQuest490 = ((490 in AP_completedLifetimeQuests) && (_class isKindOf "Air"));
if (_isQuest490) then {{_x params["_item", "_amount"];
        if (_item == "AP_cash") then {private _toReduce =
            switch (true) do {case ((490 in AP_completedLifetimeQuests) && (_isQuest490)): {0.90};
                default {1};}; _x set[1, ceil(_amount * _toReduce)];};}
    forEach _items;};
private _canCraft = _items findIf {missionNamespace getVariable(_x select 0) < (_x select 1)}
isEqualTo - 1; {_x params["_item", "_amount"];
    private _color =
    if ((missionNamespace getVariable _item) >= _amount) then {[0, 1, 0, 1]} else {[1, 0, 0, 1]};
    private _text =
    if (_item isEqualTo "AP_cash") then {format["$%1", [_amount] call AP_fnc_numberText];} else {
        format["%1x %2", _amount, ["getName", _item] call AP_fnc_virtItemCfg];};
    _index = _recipeItems lbAdd _text;
    _recipeItems lbSetColor[_index, _color];}
forEach _items;
if (_items isEqualTo[]) then {_canCraft = false;
    _recipeItems lbAdd "You do not know how to produce this item.";};
ctrlEnable[1830, _canCraft];
if (isClass(configFile >> "cfgMagazines" >> _class)) exitWith {ctrlEnable[1832, false];};
ctrlEnable[1832, _canCraft];
if (_class isKindOf "Air" || _class isKindOf "Car") then {ctrlEnable[1832, false];};