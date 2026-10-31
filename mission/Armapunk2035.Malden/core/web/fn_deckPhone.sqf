/*
    fn_deckPhone.sqf — open the web phone (GHOSTLINE MK-II / NEON AEGEAN OS).

    The HTML rebuild of the handset. Runs alongside the native phone (dialog
    90000) rather than replacing it, so the two can be compared in game and the
    native one stays the fallback while apps are ported one at a time.

    Bound to CTRL+Y. Y on its own still opens the native phone.

    Usage:  [] call AP_fnc_deckPhone;
*/

// every exit below is silent by design, which made "nothing happened" impossible
// to tell apart from "the keybind never fired". Log the reason instead.
if (!isNull (findDisplay 937500)) exitWith { diag_log "[DECK] already open, closing"; closeDialog 0 };
if (!alive player) exitWith { diag_log "[DECK] blocked: dead"; };
if (dialog) exitWith {
    // opened from inside another dialog (the native phone's app button does
    // this): close that one first, then come back.
    diag_log "[DECK] a dialog was open, closing it first";
    [] spawn { closeDialog 0; uiSleep 0.1; createDialog "AP_deck_phone"; };
};
if ((player getVariable ["AP_restrained", false]) && { (call AP_adminLevel) <= 1 }) exitWith {
    diag_log "[DECK] blocked: restrained";
    ["You cannot access your phone because your hands are restrained", "basic"] spawn AP_fnc_handleMessage;
};

diag_log "[DECK] createDialog AP_deck_phone";
createDialog "AP_deck_phone";
