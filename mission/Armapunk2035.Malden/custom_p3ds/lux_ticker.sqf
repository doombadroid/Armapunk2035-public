/*
    custom_p3ds\lux_ticker.sqf — crown ticker for the lux tower, the
    no-addon route from ARMA3_HANDOFF_LUX.md: a client-side drawIcon3D
    marching text over the 49 crown path points (lux_ticker_data.sqf,
    generated from holo-manifest.json). All other hologram animation
    (koi orbits, ad rotors, blinks, clock hands) needs model.cfg = the
    addon route, so those meshes are baked static in the p3d.

    Called from the malden_buildings.sqf model sweep once PER INSTANCE
    (serialized): each call appends its tower; one Draw3D handler renders
    every registered tower. Clients only — the server has no draw context.
*/
params ["_bld"];
if (!hasInterface) exitWith {};

if (isNil "AP_LUXTICK_PTS") then {
    AP_LUXTICK_PTS = call compile preprocessFileLineNumbers
        "custom_p3ds\lux_ticker_data.sqf";
};
if (isNil "AP_LUXTICK_TOWERS") then { AP_LUXTICK_TOWERS = []; };
AP_LUXTICK_TOWERS pushBack _bld;

if (!isNil "AP_LUXTICK_EH") exitWith {};
AP_LUXTICK_EH = addMissionEventHandler ["Draw3D", {
    private _n = count AP_LUXTICK_PTS;
    private _t = format ["%1:%2  ", floor daytime,
        [floor ((daytime mod 1) * 60), 2] call BIS_fnc_padNumber];
    private _wx = if (rain > 0.1) then { "RAIN 雨" } else {
        if (overcast > 0.6) then { "CLOUDY 曇" } else { "CLEAR 晴" } };
    private _s = _t + _wx + "  プロムナードスイーツ  RENT THE PROMENADE SUITES  アルマパンク2035  ";
    private _len = count _s;
    private _off = floor (time * 6);
    {
        private _twr = _x;
        if (player distance _twr < 900) then {
            for "_k" from 0 to (_n - 1) do {
                private _ch = _s select [(_off + _k) mod _len, 1];
                drawIcon3D ["", [0.05, 0.72, 1, 1],
                    _twr modelToWorldVisual (AP_LUXTICK_PTS select (_n - 1 - _k)),
                    0, 0, 0, _ch, 2, 0.055, "PuristaBold"];
            };
        };
    } forEach AP_LUXTICK_TOWERS;
}];
