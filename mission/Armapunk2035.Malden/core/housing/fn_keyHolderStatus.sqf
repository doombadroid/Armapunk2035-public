params[["_houseObj", objNull, [objNull]], ["_inputUID", "", [""]], ["_type", "", [""]]];
if (isNull _houseObj || _type isEqualTo "") exitWith {};
private _keyholders = _houseObj getVariable["AP_house_keys", []];
private _findIDX = _keyholders findIf {_inputUID isEqualTo(_x param[0, ""])};
private _return = false;
if (_type isEqualTo "getKeyHolders") exitWith {_keyholders apply {_x select 0}};
if (_type isEqualType[]) exitWith {_keyholders pushBack _type;
    _keyholders};
if (_findIDX isEqualTo - 1) exitWith {_return};
(_keyholders param[_findIDX, ["", -1]]) params[["_playerUID", "", [""]], ["_playerRank", -1, [0]], ["_playerName", "", [""]]];
private _canAccessBoth = (_playerRank isEqualTo 1);
private _canAccessInventory = (_playerRank isEqualTo 2);
private _canAccessLocks = (_playerRank isEqualTo 3);
_return =
switch (_type) do {case ("accessInv"): {_canAccessInventory || _canAccessBoth}; case ("accessLock"): {_canAccessLocks || _canAccessBoth};
        case ("accessHouse"): {_canAccessBoth};
        default {false};}; _return