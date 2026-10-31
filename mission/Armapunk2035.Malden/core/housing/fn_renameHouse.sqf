/*
    AP_fnc_renameHouse  (LooneyBin, owner 2026-07-10) -- the house-menu "Rename" action. Sanitizes the
    typed name CLIENT-SIDE for instant feedback (strips anything but letters/digits/space/-/_, caps 24),
    owner-checks locally, then hands it to the owner-gated APS_fnc_renameHouseSRV which RE-sanitizes +
    persists (the client sanitize is UX only -- the server is the security boundary). Blank/symbol-only
    input clears the custom name back to the house type name.
    _this = [_house, _rawName]
*/
params [["_house", objNull, [objNull]], ["_raw", "", [""]]];
if (isNull _house) exitWith {};
if !((getPlayerUID player) isEqualTo (_house getVariable ["AP_homeOwner", ""])) exitWith {
    ["Only the house owner can rename it.", "basic"] spawn AP_fnc_handleMessage;};

private _clean = toString ((toArray _raw) select {
    (_x >= 48 && {_x <= 57}) || {_x >= 65 && {_x <= 90}} || {_x >= 97 && {_x <= 122}} || {_x == 32} || {_x == 45} || {_x == 95}});
while { (count _clean) > 0 && {(_clean select [0,1]) isEqualTo " "} } do { _clean = _clean select [1]; };
while { (count _clean) > 0 && {(_clean select [(count _clean) - 1]) isEqualTo " "} } do { _clean = _clean select [0, (count _clean) - 1]; };
if ((count _clean) > 24) then { _clean = _clean select [0, 24]; };

[[_house, _clean], "APS_fnc_renameHouseSRV", 2] spawn AP_fnc_MP;
[if (_clean isEqualTo "") then { "Clearing the house name..." } else { format ["Renaming house to ""%1""...", _clean] }, "info"] spawn AP_fnc_handleMessage;
