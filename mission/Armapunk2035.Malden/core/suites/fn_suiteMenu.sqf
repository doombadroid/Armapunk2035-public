/*
    File: fn_suiteMenu.sqf  (AP_fnc_suiteMenu)
    Luxe Suites 2026-08-06 -- the tenant's three-action menu. See suites.md §7.

        [_oid, _floor] spawn AP_fnc_suiteMenu

    Exactly three actions -- Buy Furniture, Storage, End Lease -- plus a read-only
    header and, when rent is late, a red banner with a Pay Now button. This is a
    dedicated dialog rather than houseMenu with 21 of its 24 controls hidden.

    Storage and furniture land in phases 3 and 4; until then their buttons say so
    rather than silently doing nothing (a dead button that looks alive is worse
    than an honest one).
*/
#include "..\..\macro.h"

#define IDD_MENU    941601
#define IDC_M_TITLE 941620
#define IDC_M_INFO  941621
#define IDC_M_FURN  941622
#define IDC_M_STORE 941623
#define IDC_M_END   941624
#define IDC_M_PAY   941625

// ---------------------------------------------------------------- actions ---
if !(isFinal "AP_fnc_suiteMenuFurniture") then {AP_fnc_suiteMenuFurniture = compileFinal {
    closeDialog 0;
    [player, player, -1, "homegoods"] spawn AP_fnc_virtualShopMenu;
}};

if !(isFinal "AP_fnc_suiteMenuStorage") then {AP_fnc_suiteMenuStorage = compileFinal {
    closeDialog 0;
    [AP_suiteMenuOid, AP_suiteMenuFloor] spawn AP_fnc_suiteStorage;
}};

if !(isFinal "AP_fnc_suiteMenuPay") then {AP_fnc_suiteMenuPay = compileFinal {
    if (missionNamespace getVariable ["AP_suiteBusy", false]) exitWith {};
    AP_suiteBusy = true;
    [["payNow", AP_suiteMenuOid], "APS_fnc_suiteSRV", 2] spawn AP_fnc_MP;
    closeDialog 0;
    ["Settling your arrears...", "basic"] spawn AP_fnc_handleMessage;
}};

if !(isFinal "AP_fnc_suiteMenuEnd") then {AP_fnc_suiteMenuEnd = compileFinal {
    // Deliberately a two-step confirm with the consequence spelled out: ending a
    // lease destroys stored items, and the owner chose that over an escrow.
    private _ok = [
        format ["End the lease on suite %1?\n\nAnything stored inside is DESTROYED, and the floor is re-let immediately. There is no refund for the current month.", AP_suiteMenuFloor],
        "END LEASE", "End Lease", "Keep It"
    ] call BIS_fnc_guiMessage;
    if (!_ok) exitWith {};
    if (missionNamespace getVariable ["AP_suiteBusy", false]) exitWith {};
    AP_suiteBusy = true;
    [["end", AP_suiteMenuOid], "APS_fnc_suiteSRV", 2] spawn AP_fnc_MP;
    closeDialog 0;
    ["Lease ended.", "basic"] spawn AP_fnc_handleMessage;
}};

// SECURITY 2026-09-26: core\init.sqf calls this with "boot" at client init, so the helpers above are
// defined (final) before another client can publicVariable a final copy of one first.
if (_this isEqualTo "boot") exitWith {};

params [["_oid", "", [""]], ["_floor", 0, [0]]];
if (_oid isEqualTo "") exitWith {};

AP_suiteMenuOid   = _oid;
AP_suiteMenuFloor = _floor;

if (!createDialog "suiteMenu") exitWith {};
disableSerialization;
private _d = findDisplay IDD_MENU;

private _row  = (missionNamespace getVariable ["AP_suiteRows", createHashMap]) getOrDefault [_oid, []];
private _due  = _row param [3, 0];
private _over = _row param [4, 0];

(_d displayCtrl IDC_M_TITLE) ctrlSetStructuredText parseText
    format ["<t size='1.05' color='#0db8ff'>SUITE %1</t><t size='0.75' color='#888888'>   //  LUXE SUITES</t>",
        if (_floor < 10) then { format ["0%1", _floor] } else { str _floor }];

// Days remaining are computed from the server's unix deadline against the
// server's own clock, pushed with the row -- never from the client's clock.
private _now  = missionNamespace getVariable ["AP_suiteNow", 0];
private _days = if (_due > 0 && {_now > 0}) then { floor ((_due - _now) / 86400) } else { -1 };

private _txt = format ["<t color='#cfcfcf'>Rent </t><t color='#0db8ff'>%1 ND</t><t color='#cfcfcf'> every 30 days.</t><br/>", AP_suiteRentND];
if (_over > 0) then {
    private _left = 10 - (floor ((_now - _over) / 86400));
    _txt = _txt + format ["<t color='#ff4444' size='0.95'>OVERDUE.</t><t color='#ff8f6b'> %1 day(s) to settle before this suite is re-let and everything stored inside is lost.</t>", _left max 0];
} else {
    if (_days >= 0) then {
        _txt = _txt + format ["<t color='#cfcfcf'>Next payment in </t><t color='#9fdf9f'>%1 day(s)</t><t color='#cfcfcf'>, taken automatically.</t>", _days];
    };
};
(_d displayCtrl IDC_M_INFO) ctrlSetStructuredText parseText _txt;

// Pay Now only exists while there are arrears
private _pay = _d displayCtrl IDC_M_PAY;
_pay ctrlShow (_over > 0);
_pay ctrlEnable (_over > 0);
