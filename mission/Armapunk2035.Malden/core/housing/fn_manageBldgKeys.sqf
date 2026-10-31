params[["_mode", -1, [0]]];
if (_mode isEqualTo - 1) exitWith {};
disableSerialization;
private _bldg = AP_pInact_curTarget;
if (isNull _bldg) exitWith {};
if !(_bldg isKindOf "House_F") exitWith {};
if (isNil {_bldg getVariable "AP_homeOwner"} && !(_bldg in AP_vehicles)) exitWith {
    ["You must be the owner of this property to configure key settings.", "basic"] spawn AP_fnc_handleMessage;
    closeDialog 0;};
if !((_bldg getVariable["AP_homeOwner", ""]) isEqualTo(getPlayerUID player)) exitWith {
    ["You must be the owner of this property to configure key settings.", "basic"] spawn AP_fnc_handleMessage;
    closeDialog 0;};
switch (_mode) do {case 0: {waitUntil {!isNull(findDisplay 37500)};
            private _display = findDisplay 37500;
            private _nearPlayers = _display displayCtrl 37501;
            private _bldgKeyholders = _display displayCtrl 37502;
            private _rankBox = _display displayCtrl 37503;
            private _menuDescription = _display displayCtrl 37504;
            private _menuKeyCapText = _display displayCtrl 37505;
            private _menuKeyCapButton = _display displayCtrl 37506;
            private _keyPlayers = [_bldg, "", "getKeyHolders"] call AP_fnc_keyHolderStatus;
            private _keyholders = _bldg getVariable["AP_house_keys", []];
            private _keyCapCount = _bldg getVariable["AP_keycap", 0];
            private _availableKeys = _keyCapCount - count _keyholders; {lbClear _x}
            forEach[_nearPlayers, _bldgKeyholders];
            _menuDescription ctrlSetStructuredText parseText "<t size='0.90' align='center'>Players with a key cannot spawn at or sell the building. You can revoke access by removing individual keys or changing the locks on the building.</t>";
            _menuKeyCapText ctrlSetStructuredText parseText format["Available Spare Keys: %1", _availableKeys];
            private _keyCapEnable =
            if (_keyCapCount >= AP_maxHouseKeys) then {false} else {true};
            private _keyCapText =
            if (_keyCapEnable) then {"Add Key"} else {"Max Keys"};
            _menuKeyCapButton ctrlSetText _keyCapText;
            _menuKeyCapButton ctrlEnable _keyCapEnable;
            if (_keyCapEnable) then {_menuKeyCapButton buttonSetAction "[4] spawn AP_fnc_manageBldgKeys";}; {_x params["_perm", "_rank"];
                _rankBox lbAdd format["%1", _perm];
                _rankBox lbSetData[(lbSize _rankBox) - 1, str _rank];}
            forEach[["Both", 1], ["Inv", 2], ["Keys", 3]];
            _rankBox lbSetCurSel 2; {
                if (!isNull _x && alive _x && (side _x isEqualTo civilian) && player distance _x < 20 && _x != player) then {
                    _nearPlayers lbAdd format["%1", _x getVariable["AP_name", [name _x] call AP_fnc_cleanName]];
                    _nearPlayers lbSetData[(lbSize _nearPlayers) - 1, str _x];};}
            forEach((getPos player) nearEntities["CAManBase", 15]) select {isPlayer _x && alive _x}; {
                _x params["_playerUID", "_playerRank", "_playerName"];
                _displayRank =
                switch (_playerRank) do {case (1): {"Both"};
                    case (2): {"Inv"};
                    case (3): {"Keys"};}; _bldgKeyholders lbAdd format["%1 - %2 - %3", _playerName, _playerUID, _displayRank];
                _bldgKeyholders lbSetData[(lbSize _bldgKeyholders) - 1, str _x];}
            forEach _keyholders;};
    case 1: {private _keyholders = _bldg getVariable["AP_house_keys", []];
            private _keyPlayers = [_bldg, "", "getKeyHolders"] call AP_fnc_keyHolderStatus;
            private _keyCapCount = _bldg getVariable["AP_keycap", 0];
            if (count _keyPlayers >= _keyCapCount) exitWith {
                [format["You have reached the limit of %1 key holders for this property.", _keyCapCount], "basic"] spawn AP_fnc_handleMessage;
            };
            private _dialog = findDisplay 37500;
            private _nearPlayers = _dialog displayCtrl 37501;
            private _rankBox = _dialog displayCtrl 37503;
            private _selectedPlayer = _nearPlayers lbData(lbCurSel _nearPlayers);
            private _chosenRank = parseNumber(_rankBox lbData(lbCurSel _rankBox));
            private _selectedPlayer = missionNamespace getVariable _selectedPlayer;
            if (isNil "_selectedPlayer") exitWith {["Please select a player from the list.", "basic"] spawn AP_fnc_handleMessage;};
            if (isNull _selectedPlayer) exitWith {["Please select a player from the list.", "basic"] spawn AP_fnc_handleMessage;};
            private _selectedPlayerName = _selectedPlayer getVariable["AP_name", [name _selectedPlayer] call AP_fnc_cleanName];
            private _uid = getPlayerUID _selectedPlayer;
            if (_uid in _keyPlayers) exitWith {
                [format["%1 already has a key to this property.", _selectedPlayerName], "basic"] spawn AP_fnc_handleMessage;};
            _keyholders pushBack[_uid, _chosenRank, _selectedPlayerName];
            _displayRank =
            switch (_chosenRank) do {case (1): {"Both"};
                case (2): {"Inv"};
                case (3): {"Keys"};};
            [ format ["You have given %1 a special key to your building.", _selectedPlayerName]] spawn AP_fnc_handleMessage; [
                [_bldg, _keyholders, player], "APS_fnc_bldgUpdateKeys", 2] spawn AP_fnc_MP;
            _bldg setVariable["AP_activeTrunk", nil, true];};
    case 2: {private _keyPlayers = _bldg getVariable["AP_house_keys", []];
            if (_keyPlayers isEqualTo[]) exitWith {["No one currently has keys to this property.", "basic"] spawn AP_fnc_handleMessage;};
            [[_bldg, [], player], "APS_fnc_bldgUpdateKeys", 2] spawn AP_fnc_MP;
            ["You have changed the locks to the building. All previous building keys will no longer work on the locks.", "basic"] spawn AP_fnc_handleMessage;
        };
    case 3: {private _keyholders = _bldg getVariable["AP_house_keys", []];
            private _keyPlayers = [_bldg, "", "getKeyHolders"] call AP_fnc_keyHolderStatus;
            private _display = findDisplay 37500;
            private _bldgKeyholders = _display displayCtrl 37502;
            if (lbCurSel _bldgKeyholders isEqualTo - 1) exitWith {};
            (parseSimpleArray(_bldgKeyholders lbData(lbCurSel _bldgKeyholders))) params[["_removePlayerUID", "", [""]], ["_removeRank", -1, [0]], ["_removePlayerName", "", [""]]];
            if (_removePlayerUID isEqualTo "") exitWith {};
            private _findIDX = _keyholders findIf {_removePlayerUID isEqualTo(_x param[0, ""])};
            if !(_removePlayerUID in _keyPlayers) exitWith {
                ["The selected player no longer has keys to this building.", "basic"] spawn AP_fnc_handleMessage;};
            _keyholders deleteAt _findIDX;
            [format["You have removed access to this building from %1.", _removePlayerName]] spawn AP_fnc_handleMessage; [
                [_bldg, _keyholders, player], "APS_fnc_bldgUpdateKeys", 2] spawn AP_fnc_MP;};
    case 4: {closeDialog 0;
            if (AP_action_in_use || AP_houseTxn) exitWith {
                ["You already attempting an upgrade on your house.", "basic"] spawn AP_fnc_handleMessage;};
            private _keyCapCount = _bldg getVariable["AP_keycap", 0];
            if (_keyCapCount >= AP_maxHouseKeys) exitWith {
                ["You already have the max amount of spare keys created.", "basic"] spawn AP_fnc_handleMessage;};
            private _keyholders = _bldg getVariable["AP_house_keys", []];
            private _availableKeys = _keyCapCount - (count _keyholders);
            private _upgradeCost = AP_keyUpgradeCosts select _keyCapCount;
            if (213 in AP_side_talents) then { _upgradeCost = round (_upgradeCost * 0.5); };   // HOMESTEADER Locksmith -50%
            private _action = [format["Would you like to create an additonal house key for $%1", [_upgradeCost] call AP_fnc_numberText], "Create Additional house Key", "Create Key", "Cancel"] call BIS_fnc_guiMessage;
            if !(_action) exitWith {["You have decided not to create an additional house key.", "basic"] spawn AP_fnc_handleMessage;};
            if (_action) then {private _houseID = _bldg getVariable["AP_houseID", -1];
                if (_houseID isEqualTo - 1) exitWith {["An error has occured. Please try again.", "basic"] spawn AP_fnc_handleMessage;};
                if (_upgradeCost > AP_cash && _upgradeCost > AP_atmcash) exitWith {
                    [format["You do not have $%1 on-hand or in your bank to upgrade your property.", [_upgradeCost] call AP_fnc_numberText], "basic"] spawn AP_fnc_handleMessage;
                };
                AP_houseTxn = true;
                AP_action_in_use = true;
                if (AP_cash >= _upgradeCost) then {AP_cash = AP_cash - _upgradeCost;
                    AP_cashCacheB = ((AP_cash / 4) + 9);} else {AP_atmcash = AP_atmcash - _upgradeCost;
                    AP_atmcashCacheB = ((AP_atmcash / 4) + 11);};
                [6] call AP_fnc_ClupdatePartial; [
                    [_bldg, player, "spareKey", _keyCapCount, _houseID], "APS_fnc_updateProperty", 2] spawn AP_fnc_MP;
                ["Creating an additional key for your house...", "basic"] spawn AP_fnc_handleMessage;};};};