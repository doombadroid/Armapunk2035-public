/*
    fn_staffMenu.sqf  (AP_fnc_staffMenu) -- one door to the staff menu.

    Owner call 2026-08-14: the staff panel is an APP IN THE PHONE, not a screen of
    its own, so this opens the deck and tells the page to land on its STAFF view.
    Every entry point routes through here -- the phone tile, the inventory button
    and the User14 keybind -- so there is one door, not three copies of a choice.

    Two escape hatches, both off by default:
      AP_webAdmin = false -> the native dialog (admin_menu.hpp, 12900)
*/
if ((call AP_adminLevel) < 2) exitWith {
    ["That menu is staff-only.", "basic"] spawn AP_fnc_handleMessage;
};

if !(missionNamespace getVariable ["AP_webAdmin", true]) exitWith {
    [] spawn { closeDialog 0; uiSleep 0.1; createDialog "AP_admin_menu" };
};

// Same door every other app uses now.
["Admin"] call AP_fnc_deckOpenApp;
