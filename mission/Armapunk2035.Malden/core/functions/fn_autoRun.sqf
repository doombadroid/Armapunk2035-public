if !(isNull objectParent player) exitWith {};
if (player getVariable["AP_downed", false] || player getVariable["AP_restrained", false]) exitWith {};
if (AP_autoRun) exitWith {AP_autoRun = false;
    ["Auto Run disabled.", "basic"] spawn AP_fnc_handleMessage;
    player playMoveNow "AmovPercMstpSnonWnonDnon";
    if !(isNil "autoRunStop") then {(findDisplay 46) displayRemoveEventHandler["KeyDown", autoRunStop];};
    autoRunStop = nil;};
autoRunStop = (findDisplay 46) displayAddEventHandler["KeyDown", {params["_ctrl", "_code", "_shift", "_ctrlKey", "_alt"];
    if (_code in [17, 30, 31, 32]) then {AP_autoRun = false;
        ["Auto Run disabled.", "basic"] spawn AP_fnc_handleMessage;
        player playMoveNow "AmovPercMstpSnonWnonDnon";
        if !(isNil "autoRunStop") then {(findDisplay 46) displayRemoveEventHandler["KeyDown", autoRunStop];};
        autoRunStop = nil;};}];
private _getAnimDuration = {private _animSpeed = getNumber(configfile >> "CfgMovesMaleSdr" >> "States" >> _this >> "speed");
    private _duration =
    if !(_animSpeed isEqualTo 0) then {abs(1 / _animSpeed)} else {0};
    _duration * 0.9;};
AP_autoRun = true;
["Auto Run enabled.", "basic"] spawn AP_fnc_handleMessage;
while {AP_autoRun}
do {if !(isNull objectParent player) exitWith {AP_autoRun = false;};
    if (player getVariable["AP_downed", false] || player getVariable["AP_restrained", false]) exitWith {AP_autoRun = false;};
    if (AP_isDead) exitWith {AP_autoRun = false;};
    private _terrainSlope = [getPos player, getDir player] call BIS_fnc_terrainGradAngle;
    private _staminaTime = getStamina player;
    private _damage = damage player;
    private _damageLegs = player getHit "legs";
    private _uniform = uniform player;
    private _animation = "";
    private _diveSuits = ["U_O_Wetsuit", "U_I_Wetsuit", "U_B_Wetsuit", "U_B_survival_uniform"];
    private _curWep = currentWeapon player;
    private _primary = primaryWeapon player;
    private _secondary = secondaryWeapon player;
    private _handgun = handgunWeapon player;
    switch (true) do {
        case (_staminaTime > 1.5 && surfaceIsWater position player && (((getPosASL player) select 2) < -1.15) && _damage < 0.5 && _damageLegs < 0.5):
            {_animation =
                switch (true) do {case (_curWep isEqualTo "" && _uniform in _diveSuits): {"AbdvPercMsprSnonWnonDf"};
                    case (_curWep isEqualTo _primary && _uniform in _diveSuits): {"AbdvPercMsprSnonWrflDf"};
                    case (_curWep isEqualTo ""): {"AbswPercMsprSnonWnonDf"};
                    default {"AbswPercMsprSnonWnonDf"};}; player setStamina(_staminaTime - 0.0001);};
        case (surfaceIsWater position player && (((getPosASL player) select 2) < -1.15) && _damage < 0.5 && _damageLegs < 0.5): {
                _animation =
                switch (true) do {case (_curWep isEqualTo "" && _uniform in _diveSuits): {"AbdvPercMrunSnonWnonDf"};
                    case (_curWep isEqualTo _primary && _uniform in _diveSuits): {"AbdvPercMrunSnonWrflDf"};
                    case (_curWep isEqualTo ""): {"AbswPercMrunSnonWnonDf"};
                    default {"AbswPercMrunSnonWnonDf"};};};
        case (surfaceIsWater position player && (((getPosASL player) select 2) < -1.6)): {_animation =
                switch (true) do {case (_curWep isEqualTo "" && _uniform in _diveSuits): {"AdvePercMwlkSnonWnonDf"};
                    case (_curWep isEqualTo _primary && _uniform in _diveSuits): {"AbdvPercMwlkSnonWrflDf"};
                    case (_curWep isEqualTo ""): {"AbswPercMwlkSnonWnonDf"};
                    default {"AbswPercMwlkSnonWnonDf"};};};
        case (_staminaTime > 1.5 && _terrainSlope < 20 && _damage < 0.5 && _damageLegs < 0.5 && !(surfaceIsWater position player)): {
                _animation =
                switch (true) do {case (_curWep isEqualTo ""): {"AmovPercMevaSnonWnonDf"};
                    case (_curWep isEqualTo _primary): {"AmovPercMevaSlowWrflDf"};
                    case (_curWep isEqualTo _secondary): {"AmovPercMevaSlowWlnrDf"};
                    case (_curWep isEqualTo _handgun): {"AmovPercMevaSlowWpstDf"};
                    default {"AmovPercMevaSnonWnonDf"};}; player setStamina(_staminaTime - 0.0001);};
        case (_damage >= 0.5 || _damageLegs >= 0.5): {_animation =
                switch (true) do {case (_curWep isEqualTo ""): {"AmovPercMlmpSnonWnonDf"};
                    case (_curWep isEqualTo _primary): {"AmovPercMlmpSlowWrflDf"};
                    case (_curWep isEqualTo _secondary): {"AmovPercMlmpSlowWlnrDf"};
                    case (_curWep isEqualTo _handgun): {"AmovPercMlmpSrasWpstDf"};
                    default {"AmovPercMlmpSnonWnonDf"};};};
        case (_terrainSlope >= 30): {_animation =
                switch (true) do {case (_curWep isEqualTo ""): {"AmovPercMwlkSnonWnonDf"};
                    case (_curWep isEqualTo _primary): {"AmovPercMwlkSlowWrflDf_ver2"};
                    case (_curWep isEqualTo _secondary): {"AmovPercMwlkSrasWlnrDf"};
                    case (_curWep isEqualTo _handgun): {"AmovPercMwlkSlowWpstDf"};
                    default {"AmovPercMrunSnonWnonDf"};};};
        default {_animation =
            switch (true) do {case (_curWep isEqualTo ""): {"AmovPercMrunSnonWnonDf"};
                case (_curWep isEqualTo _primary): {"AmovPercMrunSlowWrflDf"};
                case (_curWep isEqualTo _secondary): {"AmovPercMrunSrasWlnrDf"};
                case (_curWep isEqualTo _handgun): {"AmovPercMrunSlowWpstDf"};
                default {"AmovPercMrunSnonWnonDf"};};};}; player playMove _animation;
    uiSleep(_animation call _getAnimDuration);};