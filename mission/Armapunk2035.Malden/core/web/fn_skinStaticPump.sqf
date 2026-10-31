/*
    fn_skinStaticPump.sqf  (AP_fnc_skinStaticPump) -- the client half of a BROADCAST reskin.
    remoteExec'd by fn_skinSwitch to every player near the car:

        [_veh, "apstatic_2_5297", 2.0] remoteExec ...   (via AP_fnc_MP; CfgRE allowedTargets = 1)

    The static itself arrives through setObjectTextureGlobal as a uiEx(...) STRING -- every client
    that receives the string instantiates its own AP_uiTexStatic display and its own browser. What
    the string cannot carry is the PUMP: a ui2texture display renders once and freezes unless
    something calls displayUpdate on it each frame. This is that something, for _secs seconds, on
    each viewer. It also does the once-per-session mipmap preload on machines that have never shown
    the display, and closes the display at the end so nothing lingers after the skin lands.
*/
params [["_veh", objNull, [objNull]], ["_name", "", [""]], ["_secs", 2.0, [0]]];
if (!hasInterface || {_name isEqualTo ""}) exitWith {};
if (isNil "AP_uiTexStaticPreloaded") then {
    private _tmp = (findDisplay 46) createDisplay "AP_uiTexStatic";
    _tmp closeDisplay 1;
    AP_uiTexStaticPreloaded = true;
};
[_veh, _name] call AP_fnc_uiTexManager;   // the ONE pump, capped to the nearest AP_uiTexCap surfaces
[_veh, _name, _secs] spawn {
    params ["_veh", "_name", "_secs"];
    uiSleep (_secs + 0.3);   // a beat past the switcher's own timer so the landing lands on a live display
    [_veh, _name, false] call AP_fnc_uiTexManager;
    private _d = findDisplay _name;
    if (!isNull _d) then { _d closeDisplay 1; };
};
