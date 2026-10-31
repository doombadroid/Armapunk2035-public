/*
    AP_fnc_hcShield  (Armapunk 2035, 2026-09-02) -- collision shield for a headless-owned autopilot vehicle.
    A setVelocity-driven vehicle with no human at the wheel clips town buildings/terrain and self-destructs
    in seconds. Ignore IMPACT/collision/fire damage, but STILL let weapons through so players can intercept
    it. Shared by AP_fnc_hcDrive (ground) and AP_fnc_hcFly (air); added where the vehicle is local, removed
    by the caller when its autopilot run ends.

    In:  [_veh]   Out: nil. Sets hc_ap_dmgEH on the vehicle (the caller removes the EH with it when done).
*/
params [["_veh", objNull, [objNull]]];
private _dmgEH = _veh addEventHandler ["HandleDamage", {params ["_v", "_sel", "_dmg", "_src", "_proj", "_hi", "_inst", "_hp"];
    // probe witness (the summon self-test sets hc_ap_probe): inside THIS handler on purpose -- with several
    // HandleDamage handlers on one object the engine takes the LAST one's return, so a separate logging
    // handler would silently replace the shield's verdict with the default damage (it did, b0841).
    if (_dmg > 0.01 && {_v getVariable ["hc_ap_probe", false]}) then {
        diag_log format ["[HCSHIELD-PROBE] sel=%1 dmg=%2 src=%3 proj=%4 inst=%5 hp=%6 pos=%7", _sel, round (_dmg * 100) / 100, typeOf _src, _proj, typeOf _inst, _hp, (getPosATL _v) apply { round _x }];
    };
    if (_proj isNotEqualTo "" || {!isNull _inst && {_inst isKindOf "CAManBase"} && {_inst isNotEqualTo _v}}) exitWith { _dmg };
    if (_hp isEqualTo "") then { damage _v } else { _v getHitPointDamage _hp }}];
_veh setVariable ["hc_ap_dmgEH", _dmgEH];
