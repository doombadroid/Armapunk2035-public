/*
    APS_fnc_endConvoyRobbery  (LooneyBin -- implemented from stub 2026-06-09)
    Convoy FINISH. Client (core/actions/fn_finishConvoyRobbery.sqf, fence NPC "Deliever Stolen
    Shipment" via npcs/fn_civConvoy) sends [_vehicle, _caller, _modifier(0..1 per-fence cut), pos].
    Pays level-scaled value x the fence's modifier in CASH, clears the event, removes the truck.
*/
params [["_vehicle", objNull, [objNull]], ["_caller", objNull, [objNull]], ["_modifier", 0, [0]], ["_pos", [0,0,0], [[]]]];
if (isNull _vehicle || {isNull _caller}) exitWith {};
if !(_vehicle getVariable ["AP_convoyTransport", false]) exitWith {};
if !(SRV_convoy_status param [0, false]) exitWith {};
if (_modifier <= 0 || {_modifier > 1}) exitWith {};
// owner 2026-07-24 SECURITY (audit): CfgRE allowedTargets=2 and the payee was the client-supplied _caller,
// with every possession/proximity/fence check living only in the client (fn_finishConvoyRobbery). So any
// client could remoteExec [<the convoy truck>, <itself>, 1, pos] the moment a convoy existed and collect
// up to $315,000 (225k x Hijacker+Master Thief) without ever hijacking it -- and could bill the payout to
// another player object. The truck is a world object, so naming it is trivial.
// Require: a resolvable caller, that caller IS the payee, and the caller standing at the truck. The legit
// path has the player at the fence NPC with the truck within 30 m of it (fn_finishConvoyRobbery:2-5), so
// 60 m is generous. Talents are read server-side from AP_talents, so the multiplier is unaffected.
private _src = remoteExecutedOwner;   // 0 == server-internal = trusted
if (_src isNotEqualTo 0) then {private _who = (allPlayers select { owner _x isEqualTo _src }) param [0, objNull];
    if (isNull _who || {_who isNotEqualTo _caller} || {(_who distance _vehicle) > 60}) exitWith {
        ["-SEC-", _who, format ["BLOCKED convoy fence payout (payee mismatch or range %1) claimed by %2",
            if (isNull _who) then {-1} else {round (_who distance _vehicle)}, getPlayerUID _caller]] call APS_fnc_logIt;
        _modifier = -1;   // signal; the top-level guard below exits the whole function
    };};
if (_modifier <= 0) exitWith {};

private _level = _vehicle getVariable ["AP_convoyLevel", SRV_convoy_status param [2, 0]];
private _value = [80000, 140000, 225000] param [_level, 80000];
private _payout = round (_value * _modifier);
// OUTLAW talents (server-minted -> read via the talent bridge, not client-asserted): Hijacker(234) +25%
// convoy payout, Master Thief(235) +15% more. Boost before the credit + message so both reflect it.
private _outTal = _caller getVariable ["AP_talents", []];
private _convoyMult = 1;
if (234 in _outTal) then { _convoyMult = _convoyMult + 0.25; };
if (235 in _outTal) then { _convoyMult = _convoyMult + 0.15; };
if (_convoyMult > 1) then { _payout = round (_payout * _convoyMult); };

SRV_convoy_status set [0, false];
publicVariable "SRV_convoy_status";
// owner 2026-07-28: ARM THE LOCKOUT AT THE END TOO (owner decision). fn_convoyRobbery:65 arms it for 900s at
// the START while the convoy's own watchdog cap is 2700s, so a convoy that runs any distance outlives its own
// lockout and buys no cooling-off; fencing the shipment is the convoy's completion, and arming here delivers
// the intended 15 quiet minutes. Keeping the start arm preserves the anti-overlap behaviour.
// DoS: unreachable by a refusal. Every guard above this line is FLAT and top-level in the function --
// :8 null vehicle/caller, :9 not the convoy truck, :10 no convoy active, :11 modifier out of range, and :27
// which is the flat catch for the ONE nested guard in the file: the caller/payee/range check at :22 sits
// inside the then {} opened at :21, so it refuses by setting the _modifier = -1 sentinel that :27 turns into
// a real exit. A forged or refused fence payout therefore stops above here and arms nothing.
// Once per convoy: slot 0 was cleared on the line above, so a second call exits at :10.
// Interval-free by construction -- this writes the timestamp; the 900s window lives in the six readers.
SRV_lastRobbery = serverTime;
publicVariable "SRV_lastRobbery";
private _d = _vehicle getVariable ["AP_convoyDriver", objNull];
if (!isNull _d) then { deleteVehicle _d; };
_vehicle setVariable ["AP_convoyTransport", false, true];
deleteVehicle _vehicle;

[["cash", "add", _payout], "AP_fnc_uC", _caller, false, false] spawn AP_fnc_MP;
[[format ["The fence paid you $%1 for the stolen shipment.", [_payout] call AP_fnc_numberText], "basic"], "AP_fnc_handleMessage", _caller, false, false] spawn AP_fnc_MP;
[["convoysdone", 1], "AP_fnc_statArrUpdate", _caller, false, false] spawn AP_fnc_MP;
[["convoymoneyearned", _payout], "AP_fnc_statArrUpdate", _caller, false, false] spawn AP_fnc_MP;
[[0, "A stolen Altis Shipping cargo has been fenced -- the robbers got away with it!"], "AP_fnc_broadcast", -2, false, false] spawn AP_fnc_MP;
[[998, _caller, format ["CONVOY payout $%1 (lvl %2, mod %3) to %4 (%5)", _payout, _level, _modifier, name _caller, getPlayerUID _caller]], "APS_fnc_logIt", false, false] spawn AP_fnc_MP;
diag_log format ["[LooneyBin][convoy] fenced: lvl %1 x %2 = $%3 -> %4", _level, _modifier, _payout, getPlayerUID _caller];
