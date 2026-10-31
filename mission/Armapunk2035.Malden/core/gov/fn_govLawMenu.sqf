disableSerialization;
if (SRV_governorData param[0, "GovUID"] isNotEqualTo(getPlayerUID player)) exitWith {};
if ((AP_govClientData param[6, -2200]) > serverTime - 2100) exitWith {
    [format["You have recently changed laws for %1. You may re-toggle laws in %2 minutes", worldName, ceil((((AP_govClientData param[6, -2200]) + 2100) - serverTime) / 60)], "basic"] spawn AP_fnc_handleMessage;
};
private _updateSlider = {params[["_value", -1]];
    if (_value isEqualTo - 1) exitWith {};
    AP_governorData set[2, (_value)];
    ctrlSetText[1001, format["%1%2", (_value), "%"]];};
createDialog "govLaw";
waitUntil {!isNull(findDisplay 250000)};
private _display = findDisplay 250000;
// govLaw.hpp still declares the phone chrome (90300-90303), but every one of those controls
// carries onLoad = ctrlShow false and sits at a negative grid offset -- they were the shell
// this menu used to be drawn inside. fn_p_updateMenu was the only thing that un-hid them, and
// it went with the shell. Driving them again would paint a cash/clock bar off-frame.
private _settingsGroup = _display displayCtrl 250001;
private _allGroupControls = [];
AP_governorData = +SRV_governorData; {if ((ctrlParentControlsGroup _x) isEqualTo _settingsGroup) then {
        (ctrlPosition _x) params["_placeX", "_placeY", "_width", "_height"];
        private _controlIDC = ctrlIDC _x;
        private _control = _x;
        _allGroupControls pushBack _x;
        private _previousControl = _allGroupControls param[(_allGroupControls findIf {_x isEqualTo _control}) - 1, controlNull];
        private _previousControlPosition =
        if !(isNull _previousControl) then {ctrlPosition _previousControl} else {ctrlPosition _control};
        private _spacing =
        switch (true) do {case (isNull _previousControl): {0};
            case ("Start" in ctrlClassName _x): {0.055};
            case ("Start" in ctrlClassName _previousControl): {0.03125};
            case ("Header" in ctrlClassName _x): {0.055};
            case ("Start" in ctrlClassName _x): {0.055};
            case ("Label" in ctrlClassName _x): {0.055};
            case ("_Slider" in ctrlClassName _x): {0};
            case ("MarkerClass" in ctrlClassName _x): {0.055};
            case ("End" in ctrlClassName _x): {0.0575};
            default {0};}; switch (ctrlType _x) do {case 0: {
                    _x ctrlSetPosition[_placeX, (_previousControlPosition select 1) + _spacing, (ctrlPosition _settingsGroup) select 2, _height];
                    if ((((ctrlClassName _x) find "Header") >= 0) && (true)) then {_x ctrlSetBackgroundColor[1, 0, 0, 0.25]};};
            case 43: {private _position =
                    switch (true) do {case (_controlIDC <= 1006): {
                                [_placeX, (_previousControlPosition select 1) + _spacing, ((ctrlPosition _settingsGroup) select 2) - (_placeX + (((ctrlPosition _settingsGroup) select 2) * 0.263)), _height]
                            };
                        case (_controlIDC isEqualTo 1008): {
                                [_placeX, (_previousControlPosition select 1) + _spacing, ((ctrlPosition _settingsGroup) select 2) - (_placeX + (((ctrlPosition _settingsGroup) select 2) * 0.202)), _height]
                            };
                        case (_controlIDC >= 2000): {
                                [_placeX, (_previousControlPosition select 1) + _spacing, ((ctrlPosition _settingsGroup) select 2) - _placeX, _height]
                            };
                        default {[_placeX, (_previousControlPosition select 1) + _spacing, _width, _height]};
                    }; _x ctrlSetPosition _position;};
            case 7: {
                    _x ctrlSetPosition[_placeX, (_previousControlPosition select 1) + _spacing, ((ctrlPosition _settingsGroup) select 2) - _placeX, _height];
                };
            default {};}; _x ctrlCommit 0;};}
forEach(allControls _display);
slidersetRange[1002, 0, 15];
sliderSetPosition[1002, (AP_governorData param[2, 0])];
(_display displayCtrl 1002) sliderSetSpeed[0.01, 0.01, 0.01];
ctrlSetText[1001, format["[%1%2]", (AP_governorData param[2, 0]), "%"]];
(_display displayCtrl 1002) ctrlAddEventHandler["SliderPosChanged", format["[_this select 1] call %1", _updateSlider]];
private _weedLegalToggle = _settingsGroup controlsGroupCtrl 1003;
private _deathPenToggle = _settingsGroup controlsGroupCtrl 1004; {(_x select 0) ctrlSetChecked(_x select 1)}
forEach[[_weedLegalToggle, AP_governorData param[3, false]], [_deathPenToggle, AP_governorData param[4, false]]]; {
    (_x select 0) ctrlAddEventHandler["CheckBoxesSelChanged", _x select 1]}
forEach[[_weedLegalToggle, {params["_control", "_selectedIndex", "_currentState"];
    AP_governorData set[3, (_currentState isEqualTo 1)];}], [_deathPenToggle, {params["_control", "_selectedIndex", "_currentState"];
    AP_governorData set[4, (_currentState isEqualTo 1)];}]];
waitUntil {isNull _display};
if (AP_governorData isNotEqualTo SRV_governorData) then {
    private _action = [format["Would you like to submit these law changes to %1? You can only do this every 35 minutes!", worldName], format["%1 Office", worldName], "Yes", "No"] call BIS_fnc_GUIMessage;
    if (_action) then {AP_govClientData set[6, serverTime];
        [21] call AP_fnc_ClupdatePartial;
        // owner 2026-06-13: send the LAW payload [tax, weedLegal, sparLegal] (toggle 1004 repurposed from
        // death-penalty to SPAR-16). Server updateGovConfig reads exactly these three, authoritatively.
        ["updateConfig", [[AP_governorData param[2, 0], AP_governorData param[3, false], AP_governorData param[4, false]]]] spawn AP_fnc_govSystem;
    };};