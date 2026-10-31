/*
    AP_fnc_adminSnowFX (LooneyBin) -- client-side cosmetic snowfall. Altis has no native snow, so the
    admin "Snow" weather toggle (APS_fnc_changeWeather) broadcasts this to every client (remoteExec 0 with
    a JIP id) to start/stop a single global particle loop. _this = [ _on (bool) ].
*/
params [["_on", false, [false]]];
AP_snowActive = _on;
if (!_on) exitWith {};
if (!isNil "AP_snowHandle" && {!isNull (missionNamespace getVariable ["AP_snowHandle", scriptNull])}) exitWith {}; // already falling

AP_snowHandle = [] spawn {while {AP_snowActive} do {if (!isNull player && {alive player} && {!isGamePaused}) then {
            for "_i" from 1 to 28 do {drop [["\A3\data_f\cl_basic", 1, 0, 1], "", "Billboard", 1, 7,
                    [-22 + random 44, -22 + random 44, 16],   // relative to player (object arg below) -> snow follows you
                    [0, 0, -2.4], 0, 10, 7.9, 0, [0.1], [[1, 1, 1, 0.85]], [0], 0, 0, "", "", player];};};
        uiSleep 0.28;};
    AP_snowHandle = nil;};
