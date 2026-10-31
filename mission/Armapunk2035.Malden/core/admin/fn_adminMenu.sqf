#include "..\..\macro.h"
showChat true;   // LooneyBin 2026-07-23: self-heal -- clear any showChat-false stranded by a prior menu open (that bug silently muted systemChat / made the debug console look dead)
if ((call AP_adminLevel) <= 1) exitWith {closeDialog 0;};
disableSerialization;
waitUntil {!isNull(findDisplay 12900)};
private _display = findDisplay 12900;
private _playerList = _display displayCtrl 12901;
private _vehicleList = _display displayCtrl 12943;
private _adminlevel = call AP_adminLevel;
private _headerText = _display displayCtrl 12946;
private _newText =
switch (_adminlevel) do {case 2: {" LoonyBin Moderator Menu"};
    case 3: {" LoonyBin Admin Menu"};
    case 4: {" LoonyBin Senior Admin Menu"};
    case 5: {" LoonyBin Owner Menu"};}; _headerText ctrlSetText _newText;
private _newColor =
switch (_adminlevel) do {case 2: {[0.317, 1, 0.184, 0.7]};
    case 4: {[0.07, 0.28, 0.82, 0.7]};
    default {[]};}; if !(_newColor isEqualTo[]) then {{(_display displayCtrl _x) ctrlSetBackgroundColor _newColor;}
    forEach[12946];   // NC: level colour marks the top header only; section bands stay graphite
}; {(_display displayCtrl _x) ctrlShow false;}
forEach[];  // LooneyBin: unhide ALL admin buttons. (Virtual Arsenal removed 2026-06-18.) News Broadcast (12916), Admin Message (11617), Spawn Dummy (12920) + the empty placeholders
if (_adminlevel >= 5) then {
    (_display displayCtrl 12916) ctrlShow true; (_display displayCtrl 12916) ctrlEnable true;   // LooneyBin: News Broadcast = owner-only
    // owner 2026-06-18: STIMMY CHECKS indicator (owner-only) -- reflect the live AP_stimmy state on open.
    private _stim = missionNamespace getVariable ["AP_stimmy", false];
    (_display displayCtrl 12972) ctrlSetText (["Status: OFF", "Status: ON (10x cartel)"] select _stim);
    (_display displayCtrl 12972) ctrlSetTextColor ([[1, 0.5, 0.5, 1], [0.2, 1, 0.2, 1]] select _stim);
    // owner 2026-06-19: FED CONTROL indicator (owner-only) -- reflect the live AP_fedOverride state on open.
    private _fed = missionNamespace getVariable ["AP_fedOverride", false];
    (_display displayCtrl 12976) ctrlSetText (["Override: OFF", "Override: ON (no cops/cooldowns)"] select _fed);
    (_display displayCtrl 12976) ctrlSetTextColor ([[1, 0.5, 0.5, 1], [0.2, 1, 0.2, 1]] select _fed);
    // owner 2026-06-24: owner reported NOT seeing the "Event Menu" button (idc 12914) though admins do. Force it
    // visible + relocate it into the OWNER block (right column, under FED CONTROL) + recolor so it's unmistakable.
    // Reuses the button's existing action ([] spawn AP_fnc_adminEventMenu -> the event+location picker -> Host).
    // Admins keep it in its original left-column spot (this only runs for level 5).
    (_display displayCtrl 12914) ctrlSetText "START EVENT";
    (_display displayCtrl 12914) ctrlSetPosition [0.34 * safezoneW, 0.158 * safezoneH, 0.17 * safezoneW, 0.028 * safezoneH]; // LooneyBin: panel-relative (sits in the OWNER TOOLS section of the Event Tools tab / EventToolsPanel 13102)
    (_display displayCtrl 12914) ctrlSetBackgroundColor [0.55, 0.2, 0.75, 1];
    (_display displayCtrl 12914) ctrlCommit 0;
    (_display displayCtrl 12914) ctrlShow true;
    (_display displayCtrl 12914) ctrlEnable true;
    // owner 2026-06-24: CHARGE SELF (test) button -- owner-only self-charge testing tool.
    (_display displayCtrl 12980) ctrlShow true;
    (_display displayCtrl 12980) ctrlEnable true;
    { (_display displayCtrl _x) ctrlShow true; (_display displayCtrl _x) ctrlEnable true; } forEach [12993, 12994, 12995, 12996, 12997, 12998];   // LooneyBin owner fun guns
} else {
    // hide the STIMMY CHECKS + FED CONTROL blocks for non-owners
    { (_display displayCtrl _x) ctrlShow false; } forEach [12916, 12920, 12925, 12990, 12971, 12972, 12973, 12974, 12975, 12976, 12977, 12978, 12979, 12980, 12993, 12994, 12995, 12996, 12997, 12998];
};
(_display displayCtrl 2904) ctrlEnable false;
if (_adminlevel < 3) then {{(_display displayCtrl _x) ctrlEnable false;}
    forEach[12951, 12954, 12919, 12926, 12934, 12935, 12936, 12937, 12938, 12939, 12940, 12941, 12942, 12959, 12961, 12966, 12969, 12970]; {
        (_display displayCtrl _x) ctrlShow false;}
    forEach[];};
if (_adminlevel < 4) then {{(_display displayCtrl _x) ctrlEnable false;}
    forEach[12951, 12963, 12964, 12967, 12968]; {(_display displayCtrl _x) ctrlShow false;}
    forEach[12951, 12963, 12964, 12967, 12968, 12991];};
// LooneyBin: default to the Actions tab on open (colours the active tab, shows ActionsPanel, hides the other panels).
[13001] call AP_fnc_adminMenuTabSwitch;
showChat false;
lbClear _playerList;
lbClear _vehicleList;
private _index = -1; {(switch (side _x) do {case civilian: {[[0.7, 0, 1, 1], (group _x) getVariable["AP_grpTag", ""]]};
        case west: {[[0, 0.5, 1, 1], _x getVariable["AP_unitCopLevel", 0]]};
        case independent: {[[0, 0.5, 0, 1], _x getVariable["AP_medLevel", 0]]};
        default {
            // LooneyBin 2026-07-23: a unit in allPlayers whose side is NONE of civ/west/indep (the dev
            // HEADLESS CLIENT is the usual one) made this switch return nil -> params left _color/_tag
            // UNDEFINED -> the format[] at the list-add below threw "Undefined variable _tag", ABORTING this
            // forEach BEFORE `showChat true` runs -> chat + systemChat stayed globally suppressed for the rest
            // of the session (this is what made the debug console look dead: exec ran, output was invisible).
            // Neutral fallback so the loop always completes and reaches the showChat restore.
            [[0.7, 0.7, 0.7, 1], ""]};}) params["_color", "_tag"];
    if (side _x isEqualTo west) then {_tag =
        switch (_tag) do {case 1: {"[Cadet] "};
            case 2: {"[Patrol Officer] "};
            case 3: {"[Corporal] "};
            case 4: {"[Sergeant] "};
            case 5: {"[Lieutenant] "};
            case 6: {"[Captain] "};
            case 7: {"[Chief of Police] "};
            default {""};};};
    if (side _x isEqualTo independent) then {_tag =
        switch (_tag) do {case 1: {"[EMR]"};
            case 2: {"[EMT]"};
            case 3: {"[AEMT]"};
            case 4: {"[Paramedic]"};
            case 5: {"[Asst. Chief]"};
            case 6: {"[Chief]"};
            default {""};};};
    _index = _playerList lbAdd format["%1 %2", name _x, _tag];
    _playerList lbSetColor[_index, _color];
    _playerList lbSetPictureRight[_index, if (isNull objectParent _x) then {
        ""} else {getText(configfile >> "CfgVehicles" >> typeOf(vehicle _x) >> "picture")}];
    _playerList lbSetData[_index, str _x];}
forEach allPlayers;
lbSort _playerList;
if ((call AP_adminLevel) <= 1) exitWith {
    showChat true;   // LooneyBin 2026-07-23: restore chat on this early-exit too (showChat false at open would otherwise strand)
    closeDialog 0;};
[] call AP_fnc_adminVehicleList;   // curated sections + full-game search (search box idc 12947)
[["-ADMINACTION-", player, (profileName), format["accessed the admin menu."]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
waitUntil {isNull _display};
showChat true;