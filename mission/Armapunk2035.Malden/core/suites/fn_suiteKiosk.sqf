/*
    File: fn_suiteKiosk.sqf  (AP_fnc_suiteKiosk)
    Luxe Suites 2026-08-06 -- the lobby kiosk directory. See suites.md §7.

    Scroll-wheel on the diorama unit in the lux lobby. Lists floors 2..30 of the
    tower this kiosk stands in, with status, and leases a vacant one.

    Defines three fns (registered in Functions.h):
        AP_fnc_suiteKiosk         open the directory
        AP_fnc_suiteKioskRefresh  redraw from AP_suiteRows (server pushes call this)
        AP_fnc_suiteKioskLease    the Lease button
*/
#include "..\..\macro.h"

#define IDD_KIOSK   941600
#define IDC_LIST    941610
#define IDC_INFO    941611
#define IDC_ACTION  941612
#define IDC_TITLE   941613

if !(isFinal "AP_fnc_suiteKioskRefresh") then {AP_fnc_suiteKioskRefresh = compileFinal {
    disableSerialization;
    // DECK: a row push repaints the deck app when it is open instead
    if (!isNull (findDisplay 937500)) then {
        private _c = uiNamespace getVariable ["WEBUI_ctrl", controlNull];
        if (!isNull _c) then { [_c, "suites", (["data"] call AP_fnc_deckSuites)] call webui_fnc_push; };
    };
    private _d = findDisplay IDD_KIOSK;
    if (isNull _d) exitWith {};
    private _list = _d displayCtrl IDC_LIST;
    private _sel  = lbCurSel _list;
    lbClear _list;

    private _uid = getPlayerUID player;
    private _tower = missionNamespace getVariable ["AP_suiteKioskTower", objNull];
    for "_f" from 2 to 30 do {
        private _oid = [_tower, _f] call AP_fnc_suiteOid;
        private _row = (missionNamespace getVariable ["AP_suiteRows", createHashMap]) getOrDefault [_oid, []];
        private _owner = _row param [2, ""];
        private _over  = _row param [4, 0];
        private _mine  = _owner isEqualTo _uid;
        private _status = if (_owner isEqualTo "") then { "VACANT" }
            else { if (_mine) then { if (_over > 0) then { "YOUR SUITE - OVERDUE" } else { "YOUR SUITE" } } else { "LEASED" } };
        private _fTxt = if (_f < 10) then { format ["0%1", _f] } else { str _f };
        private _i = _list lbAdd format ["Floor %1   -   %2", _fTxt, _status];
        _list lbSetData [_i, _oid];
        _list lbSetValue [_i, _f];
        // vacant = cyan, yours = green, someone else's = dim grey
        private _col = if (_owner isEqualTo "") then { [0.05, 0.72, 1, 1] }
            else { if (_mine) then { if (_over > 0) then { [1, 0.35, 0.35, 1] } else { [0.62, 0.87, 0.62, 1] } } else { [0.55, 0.55, 0.55, 1] } };
        _list lbSetColor [_i, _col];
    };
    if (_sel >= 0 && {_sel < lbSize _list}) then { _list lbSetCurSel _sel; } else { _list lbSetCurSel 0; };
}};

if !(isFinal "AP_fnc_suiteKioskLease") then {AP_fnc_suiteKioskLease = compileFinal {
    disableSerialization;
    private _d = findDisplay IDD_KIOSK;
    if (isNull _d) exitWith {};
    if (missionNamespace getVariable ["AP_suiteBusy", false]) exitWith {
        ["Still working on your last request.", "basic"] spawn AP_fnc_handleMessage; };
    private _list = _d displayCtrl IDC_LIST;
    private _sel = lbCurSel _list;
    if (_sel < 0) exitWith {};
    private _oid = _list lbData _sel;
    private _floor = _list lbValue _sel;
    private _row = (missionNamespace getVariable ["AP_suiteRows", createHashMap]) getOrDefault [_oid, []];
    private _owner = _row param [2, ""];
    private _uid = getPlayerUID player;

    // already yours -> the three-action menu instead
    if (_owner isEqualTo _uid) exitWith { [_oid, _floor] spawn AP_fnc_suiteMenu; };
    if (_owner isNotEqualTo "") exitWith {
        ["That suite is leased.", "basic"] spawn AP_fnc_handleMessage; };

    // client-side affordability is a COURTESY CHECK ONLY -- the server debits and
    // is free to refuse. Never treat this as the authority.
    if !([AP_suiteRentND] call AP_fnc_ndAfford) exitWith {
        [format ["You need %1 New Drachma for the first month.", AP_suiteRentND], "basic"] spawn AP_fnc_handleMessage; };

    AP_suiteBusy = true;
    [["lease", _oid, _floor], "APS_fnc_suiteSRV", 2] spawn AP_fnc_MP;
    [format ["Leasing floor %1...", _floor], "basic"] spawn AP_fnc_handleMessage;
}};

// SECURITY 2026-09-26: core\init.sqf calls this with "boot" at client init, so the helpers above are
// defined (final) before another client can publicVariable a final copy of one first.
if (_this isEqualTo "boot") exitWith {};

// ------------------------------------------------------------------ open ---
params [["_kiosk", objNull, [objNull]]];
if (isNull _kiosk) then { _kiosk = cursorObject; };
if (isNull _kiosk) exitWith {};
if (!alive player || {player distance _kiosk > 6}) exitWith {};

private _tower = [getPosATL _kiosk, 140] call AP_fnc_suiteTowerNear;
if (isNull _tower) exitWith {
    ["No tower is registered at this kiosk.", "basic"] spawn AP_fnc_handleMessage; };
AP_suiteKioskTower = _tower;

// DECK ROUTE (UI overhaul 2026-08-26): the directory opens as a deck app.
if (missionNamespace getVariable ["AP_deckApps", true]) exitWith {
    ["Suites", _kiosk] call AP_fnc_deckOpenApp;
};
if (!createDialog "suiteKiosk") exitWith {};
disableSerialization;
private _d = findDisplay IDD_KIOSK;
(_d displayCtrl IDC_TITLE) ctrlSetStructuredText parseText
    "<t size='1.1' color='#0db8ff'>LUXE SUITES</t><t size='0.8' color='#888888'>   //  PROMENADE TOWER</t>";
(_d displayCtrl IDC_INFO) ctrlSetStructuredText parseText format [
    "<t color='#cfcfcf'>Floors 2-30 are available to lease.</t><br/>"
     + "<t color='#0db8ff'>%1 ND</t><t color='#cfcfcf'> now, then </t><t color='#0db8ff'>%1 ND</t><t color='#cfcfcf'> every 30 days.</t><br/>"
     + "<t color='#cfcfcf'>Rent renews itself until you end the lease.</t><br/>"
     + "<t color='#ff8f6b'>Miss a payment and you have 10 days to settle before the suite is re-let. Anything stored inside is lost with it.</t>",
    AP_suiteRentND];

AP_suiteBusy = true;
[["list", ([_tower] call AP_fnc_suiteTowerKey)], "APS_fnc_suiteSRV", 2] spawn AP_fnc_MP;
[] call AP_fnc_suiteKioskRefresh;
