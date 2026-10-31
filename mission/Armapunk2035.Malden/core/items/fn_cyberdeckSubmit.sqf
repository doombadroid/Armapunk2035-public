// Altis Life game mechanic — fictional in-game "quickhack" ability, game logic only
/*
    File: fn_cyberdeckSubmit.sqf
    LooneyBin 2026-07-18: Terminal Breach ENTER handler. Reads the typed command, checks it against
    the current target command, advances or penalizes, updates the feed. Called from the edit KeyDown EH.
*/
if (isNil "AP_ctResult") exitWith {};
if !(AP_ctResult isEqualTo -1) exitWith {};
disableSerialization;
private _dlg = findDisplay 941000;
if (isNull _dlg) exitWith {};
private _edit = _dlg displayCtrl 941030;
private _typed = ctrlText _edit;
private _want = AP_ctCmds select AP_ctIdx;

if (_typed isEqualTo _want) then {AP_ctIdx = AP_ctIdx + 1;
    AP_ctFeed pushBack format ["<t color='#33ffbb'>root@node:~# %1  [OK]</t>", _want];
    _edit ctrlSetText "";
    playSound "FD_Finish_F";
    if (false) then {   // owner 2026-07-20: Autocomplete talent (252) removed with the Hacker tree
        _edit ctrlSetText ((AP_ctCmds select AP_ctIdx) splitString " " select 0);};} else {AP_ctDeadline = AP_ctDeadline - 3;
    AP_ctFeed pushBack format ["<t color='#ff5a3c'>root@node:~# %1  [DENIED]</t>", (if (_typed isEqualTo "") then { "(empty)" } else { _typed })];
    playSound "FD_CP_Not_Clear_F";};
call AP_ctRender;
ctrlSetFocus _edit;
