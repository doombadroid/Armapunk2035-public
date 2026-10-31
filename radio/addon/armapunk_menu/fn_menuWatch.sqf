// armapunk_menu\fn_menuWatch.sqf — engine-native main-menu bootstrap.
// CfgFunctions preInit: the main menu runs an intro MISSION behind it, so
// this fires at (and on every return to) the main menu, with no dependency
// on CBA or on display/control event handlers. The watcher loop dies with
// the intro mission and is reborn by the next preInit — exactly the menu
// display's lifecycle.
diag_log "AP35 hook: preInit";
[] spawn {
    if (isNil {uiNamespace getVariable "AP35_boot"}) then {
        uiNamespace setVariable ["AP35_boot", compile preprocessFileLineNumbers "\armapunk_menu\menu.sqf"];
    };
    while {true} do {
        uiSleep 0.2;
        private _d = findDisplay 0;   // idd 0 exists only at the main menu
        // AP35_bootedDisplay is set by menu.sqf ITSELF on entry — a spawn
        // that died before running (the v1-v3 failure) can never mark it,
        // so the watcher keeps retrying until the boot demonstrably ran.
        if (!isNull _d && {!(_d isEqualTo (uiNamespace getVariable ["AP35_bootedDisplay", displayNull]))}) then {
            diag_log "AP35 hook: preInit watcher booting display";
            [_d] spawn (uiNamespace getVariable "AP35_boot");
            uiSleep 1;   // let the boot reach its marker before rechecking
        };
    };
};
true
