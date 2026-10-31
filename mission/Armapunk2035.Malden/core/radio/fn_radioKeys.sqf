/*
    fn_radioKeys.sqf  (AP_fnc_radioKeys) -- one-shot at spawn: register ONE KeyDown handler for the car
    radio. Gated to in-vehicle + alive + no dialog. Returns false (never blocks the key). Q/R act on the
    VEHICLE you are DRIVING (state is shared, driver-controlled) -- passengers can't change it.
    Q = toggle on/off, R = next station, TAB = radial station selector. (No skip -- stations are a continuous server broadcast, APS_fnc_radioSRV.)
    Playback for everyone = fn_radioListen.
*/
if (!isNil "AP_radioKeysBound") exitWith {};
AP_radioKeysBound = true;

waitUntil { !isNull (findDisplay 46) };
(findDisplay 46) displayAddEventHandler ["KeyDown", {params ["_disp", "_code", "_shift"];
    if (dialog || {vehicle player isEqualTo player} || {!alive player}) exitWith { false };
    // owner 2026-07-09: Air is no longer blanket-blocked -- TAB does nothing in aircraft, so the radial
    // brings the radio to helis/planes. Q (collective!) and R (reload) stay flight controls in Air.
    private _isAir = (vehicle player) isKindOf "Air";
    private _v = vehicle player;
    switch (_code) do {case 16: { if (!_isAir) then { [] call AP_fnc_autoRadio; }; };   // Q -- toggle (collective in Air: pass through)
        // TAB -- station selector. owner 2026-08-18: this is the HTML car radio (dialog 515600) now.
        // SHIFT+TAB keeps the old radial (515500) reachable as a fallback -- it had never been driven
        // in a running game when it was promoted, and a keypress is cheaper than a redeploy if it
        // turns out broken in front of players. Drop the fallback once it has been driven properly.
        // Both write the same two vehicle variables (AP_radioOn / AP_radioStation) and neither
        // touches playback, which stays entirely in fn_radioListen.
        case 15: { if (_shift) then { [] spawn AP_fnc_radioRadial; } else { [] spawn AP_fnc_carRadioOpen; }; };
        case 19: {                                  // R -- next station (driver only; reload in Air: pass through)
            if (!_isAir && {driver _v isEqualTo player} && {_v getVariable ["AP_radioOn", false]}) then {
                private _n = count getArray (missionConfigFile >> "AP_Radio_Cfg" >> "AutoRadio" >> "AUTORADIO_Radio");
                _v setVariable ["AP_radioStation", (((_v getVariable ["AP_radioStation", 0]) + 1) mod _n), true];};};};
    false}];
