/*
    fn_weaponAllMags.sqf  (AP_fnc_weaponAllMags)

    EVERY magazine a weapon accepts: root magazines[] + root magazineWell + the
    same for EVERY muzzle subclass (secondary barrels like the Type 115 .50 BW,
    GLs). Reads every array in each CfgMagazineWells entry (BI_Magazines, Enoch,
    mod wells alike) -- the stock helpers miss muzzle-level magazineWells.

    Lifted out of fn_adminWeaponMenu 2026-08-14 so the STAFF DECK's weaponAcc
    verb answers with exactly the same set the native staff menu lists, rather
    than a second copy that drifts.

    Usage:  private _mags = ["arifle_MX_F"] call AP_fnc_weaponAllMags;
*/
params [["_wCls", "", [""]]];
if (_wCls isEqualTo "") exitWith { [] };

private _out = [];
private _cfgW = configFile >> "CfgWeapons" >> _wCls;
if !(isClass _cfgW) exitWith { [] };

private _fnWell = {
    params ["_wells", "_acc"];
    {
        private _w = configFile >> "CfgMagazineWells" >> _x;
        if (isClass _w) then {
            { if (isArray _x) then { _acc append (getArray _x); }; } forEach configProperties [_w, "true", true];
        };
    } forEach _wells;
};

_out append (getArray (_cfgW >> "magazines"));
[getArray (_cfgW >> "magazineWell"), _out] call _fnWell;
{
    private _mz = _cfgW >> _x;
    if (!(_x isEqualTo "this") && {isClass _mz}) then {
        _out append (getArray (_mz >> "magazines"));
        [getArray (_mz >> "magazineWell"), _out] call _fnWell;
    };
} forEach (getArray (_cfgW >> "muzzles"));

_out arrayIntersect _out
