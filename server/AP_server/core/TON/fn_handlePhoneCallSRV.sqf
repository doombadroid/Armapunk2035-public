/*
    APS_fnc_handlePhoneCallSRV  (LooneyBin) -- in-game voice phone-call setup. Runs on the SERVER.
    The 2020 client drives a radio-channel voice call; this server side was lost (replaced by a broken
    best-guess passthrough to APS_fnc_managePhone, wrong args + wrong notify protocol) so calls never
    connected. Re-implemented to the client's protocol:
      ["startPhoneCall", [_caller, _receiver]]  -> open/reuse a private radio channel with both, reply
                                                   ["phoneCallEstablished", [_chan]] to each (voice link),
                                                   or ["phoneLinesMaxed", []] if no channels are free.
      ["endPhoneCall",   [_channelID, _player]] -> drop both from the channel, tell the OTHER party the
                                                   call ended, and free the channel for reuse.
    (Text / !911 / !311 messages are handled separately by APS_fnc_handlePhoneMsg.)
*/
params [["_caseType", "", [""]], ["_data", [], [[]]]];
// owner 2026-06-13: SEED the pool from the channels pre-created at boot (server_init.sqf -> AP_phone_groups),
// instead of starting empty + creating channels ON DEMAND. Arma caps the total number of radio channels, and
// boot already burns ~9 (dispatch + 3 RF + 5 phone); the on-demand radioChannelCreate hit that cap and returned
// 0 -> EVERY caller got "phoneLinesMaxed". Now we reuse the fixed pool (no new channels) -> N concurrent lines.
if (isNil "AP_phoneCalls") then {AP_phoneCalls = [];   // [[chan, p1, p2], ...]  (p1/p2 objNull = line free)
    if (!isNil "AP_phone_groups") then {
        { if ((_x select 0) > 0) then { AP_phoneCalls pushBack [_x select 0, objNull, objNull]; }; } forEach AP_phone_groups;};};

switch (_caseType) do {case "startPhoneCall": {_data params [["_caller", objNull, [objNull]], ["_receiver", objNull, [objNull]]];
        if (isNull _caller || {isNull _receiver}) exitWith {};
        private _freeIdx = AP_phoneCalls findIf { isNull (_x select 1) && {isNull (_x select 2)} };
        if (_freeIdx isEqualTo -1) exitWith {
            // all lines busy -- reply maxed. NO on-demand radioChannelCreate (that hit Arma's channel cap and
            // returned 0, which is what made EVERY call fail). A freed line is reused; this is a real "busy".
            { [["phoneLinesMaxed", []], "AP_fnc_phoneCallClient", _x, false, false] spawn AP_fnc_MP; } forEach [_caller, _receiver];};
        private _chan = (AP_phoneCalls select _freeIdx) select 0;
        AP_phoneCalls set [_freeIdx, [_chan, _caller, _receiver]];
        _chan radioChannelAdd [_caller];
        _chan radioChannelAdd [_receiver];
        { [["phoneCallEstablished", [_chan]], "AP_fnc_phoneCallClient", _x, false, false] spawn AP_fnc_MP; } forEach [_caller, _receiver];
    };
    case "endPhoneCall": {_data params [["_channelID", -1, [0]], ["_player", objNull, [objNull]]];
        if (_channelID <= 0) exitWith {};
        private _idx = AP_phoneCalls findIf { (_x select 0) isEqualTo _channelID };
        if (_idx isEqualTo -1) exitWith { if (!isNull _player) then { _channelID radioChannelRemove [_player]; }; };
        (AP_phoneCalls select _idx) params ["", "_p1", "_p2"];
        private _other = if (_p1 isEqualTo _player) then { _p2 } else { _p1 };
        { if (!isNull _x) then { _channelID radioChannelRemove [_x]; }; } forEach [_p1, _p2];
        if (!isNull _other && {_other isNotEqualTo _player}) then {
            [["phoneCallEnded"], "AP_fnc_phoneCallClient", _other, false, false] spawn AP_fnc_MP;};
        AP_phoneCalls set [_idx, [_channelID, objNull, objNull]];   // free for reuse
    };};
