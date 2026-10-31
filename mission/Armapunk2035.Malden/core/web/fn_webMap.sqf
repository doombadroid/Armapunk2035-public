/*
    fn_webMap.sqf — open MALDEN GRID from anywhere (phone tile, keybind, script).
    Same close-then-open dance as every web dialog: a dialog is usually already
    up when this fires, and two dialogs cannot coexist.
*/
[] spawn {
    if (dialog) then { closeDialog 0; uiSleep 0.12; };
    createDialog "AP_web_map";
};
