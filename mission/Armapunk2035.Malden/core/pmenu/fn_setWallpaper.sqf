/*
    Re-plumbed 2026-08-12 so the web deck can set a wallpaper. The id used to come
    only from dialog 315000's listbox, so only that dialog could ever change it.

        [_ctrl] spawn AP_fnc_setWallpaper;      // native picker -- unchanged
        [controlNull, 2] call AP_fnc_setWallpaper;   // deck
*/
params[["_button", controlNull], ["_idIn", -1, [0]]];
private _display = findDisplay 315000;
// NOTE the braces around the inner conditional. SQF's `else` is a binary
// operator taking Code else Code -- there is no `else if` chain. Written without
// them the parser hands `else` an If, not Code, and the whole function dies with
// "Error else: Type if, expected code" before it sets anything.
private _wallpaperID =
if (_idIn >= 0) then { _idIn } else {
    if (!isNull _display) then {private _list = _display displayCtrl 315001;
        private _details = _display displayCtrl 315002;
        private _button = _display displayCtrl 315003;
        if (!isNull _button) then {_button ctrlEnable false};
        _list lbValue(lbCurSel _list)} else {(profileNamespace getVariable "PLBClientSettings") select 0}
};
AP_wallpaper = _wallpaperID;
(profileNamespace getVariable "PLBClientSettings") set[0, AP_wallpaper];
private _index = (localNamespace getVariable "AP_wallpapers") findIf {(_x select 0) isEqualTo AP_wallpaper};
// A saved id can name a wallpaper that no longer exists -- Matrix Rain (id 2) was
// removed 2026-08-14 and every profile that had it selected still asks for it.
// `select -1` is a script error, not a miss, so fall back to the first entry.
if (_index < 0) then {
    _index = 0;
    AP_wallpaper = ((localNamespace getVariable "AP_wallpapers") select 0) select 0;
    (profileNamespace getVariable "PLBClientSettings") set[0, AP_wallpaper];
    saveProfileNamespace;   // or the profile still asks for the dead id next session
};
private _wallpaperImage = ((localNamespace getVariable "AP_wallpapers") select _index) select 1; {
    // Guarded: the deck can set a wallpaper with neither native display open, and
    // writing to a control on a null display is not something to rely on.
    if (!isNull _x) then { (_x displayCtrl 90300) ctrlSetText format["images\wallpapers\%1", _wallpaperImage] };}
forEach[findDisplay 90000, findDisplay 315000];