/*
    APS_fnc_bankLightHouseToggle  (LooneyBin -- implemented from stub 2026-06-09)
    Bank-robbery lighthouse sabotage (core/actions/fn_bankToggleLighthouse.sqf). Client computed
    _doShutDown (true when the lamps are still healthy) + did the progress bar; server flips the
    lamp hitpoints so the change is authoritative + persists for JIP:
      _doShutDown true  -> damage the lamps (lighthouse dark)
      _doShutDown false -> repair them (light restored)
*/
params [["_doShutDown", false, [false]], ["_object", objNull, [objNull]]];
if (isNull _object) exitWith {}; {_object setHitPointDamage [_x, if (_doShutDown) then { 0.95 } else { 0 }];
} forEach ["Cabin_illumination_hitpoint", "Light_1_hitpoint", "Light_2_hitpoint", "Light_3_hitpoint"];
diag_log format ["[LooneyBin][lighthouse] %1 -> %2", if (_doShutDown) then {"OFF"} else {"ON"}, getPosATL _object];
