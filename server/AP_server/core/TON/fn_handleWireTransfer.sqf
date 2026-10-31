/*
    APS_fnc_handleWireTransfer  (LooneyBin: REPAIRED -- was a broken passthrough to APS_fnc_update)
    Client (bankTransfer / adminAddMoney) args: [_val, _sender, _receiver, _x3, _x4]

    The SENDER already debited + persisted its own bank client-side (fn_bankTransfer); this fn just
    CREDITS the receiver via AP_fnc_clientWireTransfer (adds to their bank + write-throughs [1]).
    The old stub fed these args into the buffered player-save (_uid landed an array) -> no-op -> the
    receiver was never credited and the wired money simply vanished (money-loss bug).
*/
params [["_val", 0, [0]], ["_sender", objNull, [objNull]], ["_receiver", objNull, [objNull]]];
if (_val <= 0 || {_val > 9999999} || {isNull _sender} || {isNull _receiver}) exitWith {};
if !(_receiver in allPlayers) exitWith {};
[[_val, _sender], "AP_fnc_clientWireTransfer", _receiver, false, false] spawn AP_fnc_MP;
[[995, _sender, format ["WIRE $%1 from %2 (%3) -> %4 (%5). Srv %6", _val, name _sender, getPlayerUID _sender, name _receiver, getPlayerUID _receiver, AP_server_instance]], "APS_fnc_logIt", false, false] spawn AP_fnc_MP;
