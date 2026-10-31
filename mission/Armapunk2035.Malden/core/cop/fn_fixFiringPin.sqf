/*
    AP_fnc_fixFiringPin  (LooneyBin, owner 2026-06-11)
    Suspect-side repair of a removed firing pin. Scroll option shows ONLY when the player's firing pin is
    removed AND they are UNRESTRAINED (see fn_setupActions). 60-second progress bar; on completion the guns
    work again. Interrupted by death, re-restraint, or losing the broken flag.
*/
if !(player getVariable ["AP_gunBroken", false]) exitWith {};
if (player getVariable ["AP_restrained", false]) exitWith {
    ["You can't repair your firing pin while restrained.", "basic"] spawn AP_fnc_handleMessage;};
if (AP_action_in_use) exitWith {["You're already doing something.", "basic"] spawn AP_fnc_handleMessage;};
if !(isNull objectParent player) exitWith {["Get out of the vehicle to repair your firing pin.", "basic"] spawn AP_fnc_handleMessage;};
AP_action_in_use = true;
private _startPos = getPosATL player;
["Acts_carFixingWheel"] spawn AP_fnc_handleAnim;   // LooneyBin: same kneel-and-fix anim as vehicle/building repair
disableSerialization;
5 cutRsc ["AP_progress", "PLAIN"];
private _ui = uiNamespace getVariable "AP_progress";
private _bar = _ui displayCtrl 38201;
private _txt = _ui displayCtrl 38202;
private _start = time;
private _dur = 60;
private _ok = false;
for "_i" from 0 to 1 step 0 do {uiSleep 0.5;
    private _p = ((time - _start) / _dur) min 1;
    _bar progressSetPosition _p;
    _txt ctrlSetText format ["Repairing firing pin... (%1%2)", round (_p * 100), "%"];
    if (_p >= 1) exitWith { _ok = true; };
    if (!alive player) exitWith {};
    // owner 2026-06-18 (#361): hands-up (TAB -> AP_surrendered) cancels the fix so you can comply, and ESC
    // (pause menu = findDisplay 49) cancels it too. The Acts_carFixingWheel kneel-and-fix anim left you stuck
    // mid-repair = shot for non-compliance in RP. The `[] spawn AP_fnc_handleAnim` below stops the anim on exit.
    if (player getVariable ["AP_surrendered", false]) exitWith {["Repair interrupted -- hands up.", "basic"] spawn AP_fnc_handleMessage;
    };
    if !(isNull (findDisplay 49)) exitWith {["Repair interrupted.", "basic"] spawn AP_fnc_handleMessage;};
    if (player getVariable ["AP_restrained", false]) exitWith {
        ["Repair interrupted -- you were restrained.", "basic"] spawn AP_fnc_handleMessage;};
    if !(player getVariable ["AP_gunBroken", false]) exitWith { _ok = true; };
    if !(isNull objectParent player) exitWith {};
    if (player distance _startPos > 1) exitWith {["Repair interrupted -- you have to hold still.", "basic"] spawn AP_fnc_handleMessage;};
};
[] spawn AP_fnc_handleAnim;   // stop the repair anim (covers every exit path above)
5 cutText ["", "PLAIN"];
AP_action_in_use = false;
if (!_ok) exitWith {};
player setVariable ["AP_gunBroken", false, true];
// owner 2026-06-21 (#440): fn_breakGuns stashed the loaded mag in the backpack + kept the gun dry, so clearing
// the flag alone left the gun EMPTY (couldn't fire after a "successful" repair, and the next save baked the empty
// gun). uiSleep lets fn_breakGuns' empty-loop see the cleared flag and stop, then reload pulls the stashed mag
// back into the gun so it actually works again (and the now-clean loadout saves correctly).
uiSleep 0.4;
reload player;
["<t color='#00FF00' size='1.3'>Firing pin repaired.</t><br/>Your weapons work again.", "info"] spawn AP_fnc_handleMessage;
