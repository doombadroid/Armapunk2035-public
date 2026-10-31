#include "..\..\macro.h"
/*
    AP_fnc_adminWeaponMenu (LooneyBin, ui branch) -- the staff menu's WEAPONS & GEAR tab (idd 12900,
    panel 13103). Spawns ANY weapon that exists in the game (every scope-2 CfgWeapons rifle / pistol /
    launcher, shops or not) plus the selected weapon's REAL compatible magazines and attachments
    (fetchWeaponMagazines + WeaponSlotsInfo>>compatibleItems -- the full config set, not the shop pool).
    Admin level > 2 (same gate as vehicle spawn); every give is logged via -ADMINSPAWN-.
    Modes: ["init"] (tab open) | ["filter"] (search box) | ["select"] | ["giveweapon"] | ["givekit"]
           | ["giveaddon", N]
*/
params [["_mode", "init", [""]], ["_arg", 1, [0]]];
if ((call AP_adminLevel) <= 2) exitWith {};
disableSerialization;
private _display = findDisplay 12900;
if (isNull _display) exitWith {};
private _wepList = _display displayCtrl 13111;
private _accList = _display displayCtrl 13112;
private _info    = _display displayCtrl 13117;

// selected player in the staff list (12901) or yourself -- same resolution as fn_adminAddMoney
private _fnTarget = {private _sel = lbCurSel 12901;
    if (_sel < 0) exitWith { player };
    private _u = missionNamespace getVariable [lbData [12901, _sel], objNull];
    if (isNull _u || {!alive _u}) then { player } else { _u }};
private _fnLog = {params ["_what", "_t"];
    [["-ADMINSPAWN-", player, profileName, format ["admin-spawned %1 for %2 at POS: %3", _what, name _t, getPosATL _t]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
};
// EVERY magazine a weapon accepts -- moved to AP_fnc_weaponAllMags 2026-08-14 so the STAFF DECK's
// weaponAcc verb answers from the same walk instead of a second copy of it.
private _fnAllMags = { params ["_wCls"]; [_wCls] call AP_fnc_weaponAllMags };

switch (_mode) do {

    case "init";
    case "filter": {
        // one-time catalogue: EVERY real weapon in the game (type 1 rifle / 2 handgun / 4 launcher)
        if (isNil "AP_adminWepCache") then {AP_adminWepCache = []; {private _dn = getText (_x >> "displayName");
                if (_dn != "") then {AP_adminWepCache pushBack [_dn, configName _x, getText (_x >> "picture")];};
            } forEach ("getNumber (_x >> 'scope') == 2 && {(getNumber (_x >> 'type')) in [1, 2, 4]}" configClasses (configFile >> "CfgWeapons"));
            // owner 2026-07-23: UAV terminals are CfgWeapons TYPE 4096 (UAV/binocular slot), so the rifle/
            // handgun/launcher scan above skips them. Add each faction's terminal explicitly. isClass-guarded
            // -> a class the game doesn't have is silently skipped, never an error. The existing "weapon"
            // giveGear path (player addWeapon) is exactly how a UAV terminal is issued.
            {_x params ["_uCls", "_uLbl"];
                if (isClass (configFile >> "CfgWeapons" >> _uCls)) then {
                    AP_adminWepCache pushBack [_uLbl, _uCls, getText (configFile >> "CfgWeapons" >> _uCls >> "picture")];};} forEach [
                ["B_UavTerminal",   "UAV Terminal (NATO / BLUFOR)"], ["O_UavTerminal",   "UAV Terminal (CSAT / OPFOR)"],
                ["I_UavTerminal",   "UAV Terminal (AAF / Independent)"], ["I_G_UavTerminal", "UAV Terminal (FIA / Guerrilla)"]];
            AP_adminWepCache sort true;};
        private _filter = toLower (ctrlText (_display displayCtrl 13110));
        lbClear _wepList; {_x params ["_dn", "_cls", "_pic"];
            if (_filter isEqualTo "" || {(toLower _dn) find _filter >= 0} || {(toLower _cls) find _filter >= 0}) then {
                private _i = _wepList lbAdd _dn;
                _wepList lbSetData [_i, _cls];
                _wepList lbSetPicture [_i, _pic];};} forEach AP_adminWepCache;
        if (_mode isEqualTo "init") then {
            _info ctrlSetStructuredText parseText format ["<t color='#8993a0'>%1 weapons indexed.<br/>Pick one to see its compatible mags + attachments.</t>", count AP_adminWepCache];
        };};

    case "select": {private _sel = lbCurSel _wepList;
        if (_sel < 0) exitWith {};
        private _cls = _wepList lbData _sel;
        uiNamespace setVariable ["AP_adminWepSel", _cls];
        lbClear _accList;
        // compatible magazines (full config set via magazineWells)
        private _mags = [_cls] call _fnAllMags;
        private _nMags = 0; {private _dn = getText (configFile >> "CfgMagazines" >> _x >> "displayName");
            if (_dn != "") then {private _i = _accList lbAdd format ["[MAG] %1", _dn];
                _accList lbSetData [_i, _x];
                _accList lbSetValue [_i, 1];
                _accList lbSetPicture [_i, getText (configFile >> "CfgMagazines" >> _x >> "picture")];
                _nMags = _nMags + 1;};} forEach _mags;
        // compatible attachments (every WeaponSlotsInfo compatibleItems class, not the shop pool)
        private _compat = []; {private _ci = _x >> "compatibleItems";
            if (isArray _ci) then { { _compat pushBack _x; } forEach getArray _ci; };
            if (isClass _ci) then { { if (getNumber _x >= 1) then { _compat pushBack configName _x; }; } forEach configProperties [_ci, "isNumber _x", true]; };
        } forEach configProperties [configFile >> "CfgWeapons" >> _cls >> "WeaponSlotsInfo", "isClass _x", true];
        _compat = _compat arrayIntersect _compat;
        private _nAcc = 0; {private _dn = getText (configFile >> "CfgWeapons" >> _x >> "displayName");
            if (_dn != "") then {private _i = _accList lbAdd format ["[ATT] %1", _dn];
                _accList lbSetData [_i, _x];
                _accList lbSetValue [_i, 0];
                _accList lbSetPicture [_i, getText (configFile >> "CfgWeapons" >> _x >> "picture")];
                _nAcc = _nAcc + 1;};} forEach _compat;
        _info ctrlSetStructuredText parseText format [
            "<t color='#ebeff4' size='1.1'>%1</t><br/><t color='#8993a0'>%2</t><br/><br/><t color='#53e39c'>%3 mags</t> <t color='#8993a0'>/</t> <t color='#37e8f0'>%4 attachments</t>",
            getText (configFile >> "CfgWeapons" >> _cls >> "displayName"), _cls, _nMags, _nAcc];};

    case "giveweapon": {private _cls = uiNamespace getVariable ["AP_adminWepSel", ""];
        if (_cls isEqualTo "") exitWith {};
        private _t = call _fnTarget;
        [["weapon", _cls, 1], "AP_fnc_adminGearReceive", _t, false] call AP_fnc_MP;
        [format ["1x %1 (weapon)", _cls], _t] call _fnLog;
        [format ["Spawned %1 for %2.", getText (configFile >> "CfgWeapons" >> _cls >> "displayName"), name _t], "basic"] spawn AP_fnc_handleMessage;
    };

    case "givekit": {private _cls = uiNamespace getVariable ["AP_adminWepSel", ""];
        if (_cls isEqualTo "") exitWith {};
        private _t = call _fnTarget;
        private _mags = getArray (configFile >> "CfgWeapons" >> _cls >> "magazines");   // primary barrel first
        if (_mags isEqualTo []) then { _mags = [_cls] call _fnAllMags; };
        private _mag = _mags param [0, ""];
        if (_mag != "") then {[["mag", _mag, 3], "AP_fnc_adminGearReceive", _t, false] call AP_fnc_MP;};
        [["weapon", _cls, 1], "AP_fnc_adminGearReceive", _t, false] call AP_fnc_MP;   // after the mags so it spawns loaded
        [format ["1x %1 + 3x %2 (kit)", _cls, _mag], _t] call _fnLog;
        [format ["Spawned %1 with 3 mags for %2.", getText (configFile >> "CfgWeapons" >> _cls >> "displayName"), name _t], "basic"] spawn AP_fnc_handleMessage;
    };

    case "giveaddon": {private _sel = lbCurSel _accList;
        if (_sel < 0) exitWith {["Select a mag or attachment in the middle list first.", "basic"] spawn AP_fnc_handleMessage;};
        private _cls = _accList lbData _sel;
        private _isMag = (_accList lbValue _sel) isEqualTo 1;
        private _t = call _fnTarget;
        [[["item", "mag"] select _isMag, _cls, _arg max 1], "AP_fnc_adminGearReceive", _t, false] call AP_fnc_MP;
        [format ["%1x %2 (%3)", _arg max 1, _cls, ["attachment", "magazine"] select _isMag], _t] call _fnLog;
        [format ["Spawned %1x %2 for %3.", _arg max 1, getText (configFile >> (["CfgWeapons", "CfgMagazines"] select _isMag) >> _cls >> "displayName"), name _t], "basic"] spawn AP_fnc_handleMessage;
    };};
