/*
    AP_fnc_miningAssemble  (client) -- build a mining rig from the 8 crypto components.
    Consumes one of each component locally (all-or-nothing), then asks the server to grant the assembled rig.
*/
private _parts = ["cryptoCPU","cryptoGPU","cryptoPSU","cryptoStorage","cryptoMotherboard","cryptoRam","cryptoCooler","cryptoCase"];
private _missing = _parts select { (missionNamespace getVariable [format ["AP_inv_%1", _x], 0]) < 1 };
if (_missing isNotEqualTo []) exitWith {
    [format ["Mining rig needs all 8 parts. Missing: %1", count _missing], "basic"] spawn AP_fnc_handleMessage;};
// consume one of each; if any consume fails, refund what we took and bail
private _taken = [];
private _ok = true; {if ([false, _x, 1] call AP_fnc_handleInv) then { _taken pushBack _x; } else { _ok = false; };} forEach _parts;
if (!_ok) exitWith {{ [true, _x, 1] call AP_fnc_handleInv; } forEach _taken;
    ["Couldn't gather all the parts -- try again.", "basic"] spawn AP_fnc_handleMessage;};
[["assemble", player], "APS_fnc_miningSRV", 2] spawn AP_fnc_MP;
