#include "\A3\ui_f\hpp\defineCommonGrids.inc"
params[["_display", displayNull, [displayNull]]];
if (isNull _display) exitWith {};
disableSerialization;
private _plb_display = _display;
private _abort = _plb_display displayCtrl 104;
private _save = _plb_display displayCtrl 103;
private _respawn = _plb_display displayCtrl 1010;
private _fieldManual = _plb_display displayCtrl 122;
private _optionsButton = _plb_display displayCtrl 101;
// LooneyBin: only lock Abort/Suicide while IN COMBAT (anti-combat-log), not always. The deobf source
// disabled them unconditionally, so the Escape menu's Abort/Respawn never worked and the only way to
// leave was alt-F4.
if (AP_inCombat) then {{ _x ctrlEnable false } forEach [_abort, _save, _respawn, _fieldManual];
    _respawn ctrlSetText "Cannot Suicide (In Combat)";
    _abort ctrlSetText "Cannot Abort (In Combat)";};
private _versionNr = ctrlText((findDisplay 0) displayCtrl 118);
private _versionFooter = _plb_display displayCtrl 1005;
_versionFooter ctrlSetText format["LoonyBin Life | %1", _versionNr];
// LooneyBin (owner, 2026-06-11): escape menu trimmed to DISCORD only -- forums/teamspeak/wiki/
// MyLoonyBin removed (dead pre-rebrand links). Discord URL lives in customEscMenu.hpp.
private _loonybinDiscord = _plb_display ctrlCreate["LoonyBinDiscordLinkButton", -1];
_loonybinDiscord ctrlSetText "LoonyBin Discord";
_loonybinDiscord ctrlSetTooltip "Join the LoonyBin Discord Server";
// LooneyBin (owner, 2026-06-11): with 4 link rows removed the header+discord floated high above the
// menu. Dropped both to the bottom of the old cluster so they sit right against the menu buttons
// (header grid 11.9, discord 13 -- discord was the lowest/closest-to-menu row originally).
_loonybinDiscord ctrlSetPosition[1 * GUI_GRID_W + GUI_GRID_X, 13 * GUI_GRID_H + GUI_GRID_Y, 15 * (((safezoneW / safezoneH) min 1.2) / 40), 1 * ((((safezoneW / safezoneH) min 1.2) / 1.2) / 25)];
private _loonybinHeader = _plb_display ctrlCreate["AP_EscapeMenuHeader", -1];
_loonybinHeader ctrlSetStructuredText parseText "<t font='PuristaMedium'>PROJECT LOONYBIN</t>";
_loonybinHeader ctrlSetPosition[1 * GUI_GRID_W + GUI_GRID_X, 11.9 * GUI_GRID_H + GUI_GRID_Y, 15 * (((safezoneW / safezoneH) min 1.2) / 40), 1 * ((((safezoneW / safezoneH) min 1.2) / 1.2) / 25)]; {
    _x ctrlCommit 0;}
forEach[_loonybinHeader, _loonybinDiscord];
uiNamespace setVariable["BIS_DisplayInterrupt_ServerButtons", [_loonybinHeader, _loonybinDiscord]];
_optionsButton ctrlAddEventHandler["ButtonClick", {_this spawn {
        private _buttons = uiNamespace getVariable["BIS_DisplayInterrupt_ServerButtons", []];
        private _isExpanded = uiNamespace getvariable["BIS_DisplayInterrupt_isOptionsExpanded", false]; {
            private _buttonPosition = ctrlPosition _x;
            private _padding = ((_buttonPosition select 1) - GUI_GRID_Y) / GUI_GRID_H;
            if (_isExpanded) then {
                _x ctrlSetPosition[(_buttonPosition select 0), ((_padding + 4.4) * GUI_GRID_H + GUI_GRID_Y), (_buttonPosition select 2), (_buttonPosition select 3)];
            } else {
                _x ctrlSetPosition[(_buttonPosition select 0), ((_padding - 4.4) * GUI_GRID_H + GUI_GRID_Y), (_buttonPosition select 2), (_buttonPosition select 3)];
            };
            _x ctrlCommit 0.2;}
        forEach _buttons;};}];
_respawn buttonSetAction "AP_suicide = true;";
private _enableButtons = (!(isNil "AP_session_completed") && {
    !(player getVariable["AP_restrained", false]) && AP_session_completed && !(AP_isDowned) && !(player getVariable["AP_escorting", false]) && !(player getVariable["AP_transporting", false]) && ((AP_is_arrested param [0,0]) isEqualTo 0) && !AP_killedByElectricChair
});
if (_enableButtons) then {[_abort, _respawn, _display] spawn {params["_abort", "_respawn", "_display"];
        // owner 2026-06-18 (#350): RE-CHECK the suicide block-gate EVERY tick while the ESC menu is OPEN -- not just
        // once at open (_enableButtons). A player opened ESC a beat BEFORE the taze (gate passed), rode this countdown
        // out, and suicided to DODGE ARREST. Now becoming restrained / downed / arrested / in-combat / escorted at
        // ANY point -- before OR after the countdown ends -- disables Suicide immediately and keeps it disabled.
        // (Also closes a latent hole: in-combat disabled the buttons at open but the old end-of-countdown re-enable
        // ignored combat, so an in-combat player could still suicide at 15s.) The countdown (15s, 1s admin) still
        // gates the FIRST enable. LoonyBin (owner 2026-06-12): buttons stay disabled for the whole countdown so it
        // can't be clicked mid-count.
        private _timeStamp = if (call AP_adminLevel >= 3) then { time + 1 } else { time + 15 };
        private _welcomeDone = false;
        while { !isNull _display } do {private _ok = !(player getVariable["AP_restrained", false]) && !AP_isDowned
                && ((AP_is_arrested param [0,0]) isEqualTo 0) && !AP_inCombat
                && !(player getVariable["AP_escorting", false]) && !(player getVariable["AP_transporting", false])
                && !AP_killedByElectricChair;
            private _left = round (_timeStamp - time);
            switch (true) do {case (!_ok): {_respawn ctrlEnable false; _abort ctrlEnable false;
                    _respawn ctrlSetText (if (AP_inCombat) then {"Cannot Suicide (In Combat)"} else {"Cannot Suicide (Being Captured)"});
                    _abort ctrlSetText (if (AP_inCombat) then {"Cannot Abort (In Combat)"} else {"Cannot Abort"});};
                case (_left > 0): {_respawn ctrlEnable false; _abort ctrlEnable false;
                    _respawn ctrlSetText format ["Suicide [%1]", _left];
                    _abort ctrlSetText format ["Quit LoonyBin [%1]", _left];};
                default {_respawn ctrlEnable true; _abort ctrlEnable true;
                    _respawn ctrlSetText "Suicide";
                    _abort ctrlSetText "Quit LoonyBin Life";
                    if (!_welcomeDone && AP_session_completed && AP_quitWelcomeUI) then { _welcomeDone = true; [] call AP_fnc_ClupdateRequest; };
                };};
            uiSleep 0.1;};
        if (alive player) then { AP_suicide = nil };};} else {if ((AP_is_arrested param [0,0]) isEqualTo 1) then {
        _abort ctrlSetText "Quit LoonyBin Life";
        _abort ctrlEnable true;} else {
        // owner 2026-06-19 (#381): ESC opened while ALREADY restrained/being-moved (so the _enableButtons
        // countdown path above never ran) -> Abort stayed in its default ENABLED state, letting a cuffed player
        // Quit to combat-log out of the restraint. Keep Abort DISABLED in those cop-capture states. (Arrested/
        // jailed players CAN still quit -- handled above; loaders with session not completed are NOT blocked.)
        if ((player getVariable ["AP_restrained", false]) || (player getVariable ["AP_escorting", false]) || (player getVariable ["AP_transporting", false])) then {
            _abort ctrlEnable false;
            _abort ctrlSetText "Cannot Abort (Restrained)";};};};