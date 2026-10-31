/*
    APS_fnc_changeWeather  (LooneyBin)  -- admin weather control. Runs ON THE SERVER (AP_fnc_adminWeather
    remoteExec's it to machine 2). WAS a passthrough to the neutered APS_fnc_weatherSync (if(true)exitWith{})
    so the Rain/Snow admin buttons did literally nothing. Now applies weather directly; the engine syncs
    server weather to every client (incl. JIP). Altis has no native snow -> a client particle FX is
    broadcast to all clients (AP_fnc_adminSnowFX) with a JIP id so late joiners match the current state.
    _this = weather keyword: "rain" | "snow" | "day" | "night".  rain/snow are toggles.
*/
params [["_function", "", [""]]];
if (_function isEqualTo "") exitWith {};

// owner 2026-06-23 SECURITY (security.md §2.3 — no admin check): this had NO server-side authz, so any client
// could remoteExec it to toggle server-wide rain/snow/day/night (grief). Re-query the NON-SPOOFABLE caller's
// adminlevel and require >= 4 (client gate fn_adminWeather: `(call AP_adminLevel) <= 3` exits).
// remoteExecutedOwner 0 = server-internal = trusted.
private _src = remoteExecutedOwner;
private _caller = if (_src isEqualTo 0) then { objNull } else { (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
private _callerUID = getPlayerUID _caller;
private _lvl = if (_src isEqualTo 0) then { 999 } else {
    private _rows = [format ["SELECT adminlevel FROM players_global WHERE playerid='%1'", _callerUID], 2, true] call DB_fnc_asyncQuery;
    parseNumber format ["%1", (_rows param [0, [0]]) param [0, 0]]};
if (_lvl < 4) exitWith { ["-SEC-", _caller, format ["BLOCKED changeWeather by %1", _callerUID]] call APS_fnc_logIt; };

switch (toLower _function) do {case "rain": {private _on = !(missionNamespace getVariable ["AP_wx_rain", false]);
        missionNamespace setVariable ["AP_wx_rain", _on, true];
        if (_on) then {
            // rain needs overcast; also kill snow if it was running
            missionNamespace setVariable ["AP_wx_snow", false, true];
            [false] remoteExec ["AP_fnc_adminSnowFX", 0, "AP_snowFX_jip"];
            0 setOvercast 1;
            forceWeatherChange;
            0 setRain 1;
            0 setFog 0.04;} else {0 setRain 0;
            0 setOvercast 0;
            forceWeatherChange;
            0 setFog 0;};};
    case "snow": {private _on = !(missionNamespace getVariable ["AP_wx_snow", false]);
        missionNamespace setVariable ["AP_wx_snow", _on, true];
        if (_on) then {missionNamespace setVariable ["AP_wx_rain", false, true];
            0 setRain 0;
            0 setOvercast 0.7;     // winter sky
            forceWeatherChange;
            0 setFog 0.06;} else {0 setOvercast 0;
            forceWeatherChange;
            0 setFog 0;};
        [_on] remoteExec ["AP_fnc_adminSnowFX", 0, "AP_snowFX_jip"];   // start/stop the particle snowfall on every client
    };
    case "day": {date params ["_y", "_mo", "_d"];
        setDate [_y, _mo, _d, 12, 0];   // global from server -> all clients to noon
    };
    case "night": {date params ["_y", "_mo", "_d"];
        setDate [_y, _mo, _d, 0, 0];    // midnight
    };};
