params[["_playerBank", -1, [-1]], ["_playerCash", -1, [-1]], ["_playerUID", "", [""]], ["_playerName", "", [""]], ["_playerSteamName", "", [""]], ["_playerOwner", -1, [-1]], ["_player", objNull, [objNull]]];
if (_playerOwner isEqualTo - 1 || isNull _player) exitWith {};
disableSerialization;

// STAFF DECK (2026-08-14): the same answer feeds the HTML menu, which has no
// controls to paint. Cash and bank are not network-synced -- this round trip is
// the only way either menu learns them -- so cache them by uid for the deck's
// 1 Hz roster, then fall through to the native painting below IF that dialog is
// the one that is open.
private _cache = missionNamespace getVariable ["AP_staffDossier", createHashMap];
_cache set [_playerUID, createHashMapFromArray [
    ["cash",  _playerCash],
    ["bank",  _playerBank],
    ["steam", _playerSteamName],
    ["name",  _playerName],
    ["t",     diag_tickTime]
]];
missionNamespace setVariable ["AP_staffDossier", _cache];

private _display = findDisplay 12900;
if (isNull _display) exitWith {};   // deck-only query: nothing to paint
private _leftText = _display displayCtrl 12944;
private _rightText = _display displayCtrl 12945;
private _myLoonyBin = _display displayCtrl 12923;
private _primaryWeapon =
if (primaryWeapon _player isNotEqualTo "") then {([primaryWeapon _player] call AP_fnc_fetchCfgDetails select 1)} else {"None"};
private _handgunWeapon =
if (handgunWeapon _player isNotEqualTo "") then {([handgunWeapon _player] call AP_fnc_fetchCfgDetails select 1)} else {"None"};
private _secondaryWeapon =
if (secondaryWeapon _player isNotEqualTo "") then {([secondaryWeapon _player] call AP_fnc_fetchCfgDetails select 1)} else {"None"};
private _vest =
if (vest _player isNotEqualTo "") then {([vest _player] call AP_fnc_fetchCfgDetails select 1)} else {"None"};
private _uniform =
if (uniform _player isNotEqualTo "") then {([uniform _player] call AP_fnc_fetchCfgDetails select 1)} else {"None"};
private _backpack =
if (backpack _player isNotEqualTo "") then {([backpack _player] call AP_fnc_fetchCfgDetails select 1)} else {"None"};
private _attachments = [];
private "_tmp";
if !(primaryWeapon _player isEqualTo "") then {{if !(_x isEqualTo "") then {_tmp = ([_x] call AP_fnc_fetchCfgDetails select 1);
            _attachments pushBack _tmp;};}
    forEach(primaryWeaponItems _player);};
if (_attachments isEqualTo[]) then {_attachments = "None"};
_leftText ctrlSetStructuredText parseText format["<t size='0.800' color='#ffffff'>Name: %1</t><br/><t size='0.800' color='#ffffff'>Steam: %2</t><br/><t size='0.800' color='#ffffff'>UID: %3</t><br/><t size='0.800' color='#ffffff'>Cash: $%4</t><br/><t size='0.800' color='#ffffff'>Bank: $%5</t><br/><t size='0.800' color='#ffffff'>POS: %6</t>", _playerName, _playerSteamName, _playerUID, [_playerCash] call AP_fnc_numberText, [_playerBank] call AP_fnc_numberText, getPosATL _player];
_rightText ctrlSetStructuredText parseText format["<t size='0.700' color='#ffffff'>Uniform: %1</t><br/><t size='0.700' color='#ffffff'>Backpack: %2</t><br/><t size='0.700' color='#ffffff'>Vest: %3</t><br/><t size='0.700' color='#ffffff'>Primary Gun: %4</t><br/><t size='0.700' color='#ffffff'>Primary Attach: %5</t><br/><t size='0.700' color='#ffffff'>Handgun: %6</t><br/><t size='0.700' color='#ffffff'>Secondary: %7</t>", _uniform, _backpack, _vest, _primaryWeapon, _attachments, _handgunWeapon, _secondaryWeapon];
_myLoonyBin ctrlSetStructuredText parseText format["<a align='center' valign='middle' href='https://discord.gg/TdNVfcFcx6'>My LoonyBin<' /></a>", _playerUID];