/*
    fn_carRadioOpen.sqf  (AP_fnc_carRadioOpen) -- opens AP_web_carRadio (dialog\web_carradio.hpp,
    idd 515600), the HTML port of the TAB-in-vehicle car radio. Ported from the design handoff's
    radial.html ("PHOSPHOR RING") against core/radio/fn_radioRadial.sqf (idd 515500), which this
    sits ALONGSIDE, untouched -- TAB still opens that one until a human has compared the two
    in-game. fn_carRadioBridge.sqf (this dialog's onLoad) does the actual wiring; this file is
    only the guard + open/toggle, mirroring fn_radioRadial.sqf's own opening lines almost
    verbatim (same guard, same toggle-if-already-open) since that IS the behaviour being ported.

    Guard: must be IN a vehicle (any kind, Air included -- fn_radioRadial.sqf allows aircraft
    too: "TAB is unbound in helis/planes, so the radial IS the aircraft radio UI"; this asks the
    identical question). Any seat may open it -- only station/AP CHANGES are driver-gated, inside
    fn_carRadioBridge.sqf's "radialSet" verb, the same place the native radial's own ButtonClick
    handler re-checks `driver _v isEqualTo player`.

    NOT YET BOUND TO A KEY. Reach it from the debug console for a side-by-side look:
        [] spawn AP_fnc_carRadioOpen;
    A real binding would touch core/radio/fn_radioKeys.sqf, outside this port's file ownership
    -- see the task report for what that would need to say.
*/
private _veh = vehicle player;
if (_veh isEqualTo player) exitWith {};
if (!isNull (findDisplay 515600)) exitWith { closeDialog 0; };

createDialog "AP_web_carRadio";
