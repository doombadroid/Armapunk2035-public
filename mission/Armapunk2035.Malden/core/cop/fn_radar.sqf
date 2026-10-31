if !(AP_effSide isEqualTo west) exitWith {};
if (!AP_radar_active && currentWeapon player != "hgun_P07_F" && !(78 in AP_side_talents) && !(79 in AP_side_talents)) exitWith {
    ["You're either not talented enough or lacking a radar gun to measure the speed of vehicles!", "basic"] spawn AP_fnc_handleMessage;
    AP_radar_active = false};
if (!AP_radar_active && currentWeapon player != "hgun_P07_F" && isNull objectParent player && !(79 in AP_side_talents)) exitWith {
    ["You're either not talented enough or lacking a radar gun to measure the speed of vehicles!", "basic"] spawn AP_fnc_handleMessage;
    AP_radar_active = false};
if (!AP_radar_active && !isNull objectParent player && !(78 in AP_side_talents)) exitWith {
    ["You're not talented enough to use the radar from within a vehicle.", "basic"] spawn AP_fnc_handleMessage;
    AP_radar_active = false};
if (AP_radar_active) exitWith {AP_radar_active = false};
AP_radar_active = true;
[] spawn {private _highest = 0;
    private _color = "";
    private _speed = 0;
    private _vehicle = cursorTarget;
    while {AP_radar_active}
    do {if (isNull objectParent player && currentWeapon player != "hgun_P07_F" && !(79 in AP_side_talents)) exitWith {};
        _vehicle = cursorTarget;
        if (isNull _vehicle) then {_speed = 0;} else {_speed = round speed _vehicle;};
        if (_speed > _highest) then {_highest = _speed};
        _color =
        if (_highest < 80) then {"33CC33"} else {"#FF0000"}; [
            [format["<t color='#ffffff'><t size='0.5'><t align='center'>Speed Radar<br/><t align='center'><t size='0.5'>Active Speed: %1 km/h<br/><t color='%3'>Recorded High: %2 km/h", _speed, _highest, _color], 0, 5, 2]
        ] spawn BIS_fnc_EXP_camp_SITREP;
        uiSleep 0.05;}; AP_radar_active = false; [
        ["<t color='#ffffff'><t size='0.5'><t align='center'>Speed Radar<br/><t color='#33CC33'><t align='center'><t size='0.5'>Deactivated", 0, 2, 1]
    ] spawn BIS_fnc_EXP_camp_SITREP;
    uiSleep 3;};