/*
    fn_deckGangRequest.sqf — ask the server to refill AP_gangMembersList.

    The roster is not client state: APS_fnc_getGangInfo answers on
    AP_fnc_gangMembersReceive, which sets AP_gangMembersList and flips
    AP_gangMembersList_ready. fn_gangMenu does the same dance before it
    populates its listbox; the web deck needs it too, without the dialog.

    Rate-limited, because the deck's push loop calls it and the reply is a
    server round-trip.

    Usage:  [] call AP_fnc_deckGangRequest;
*/

if (AP_gang_data isEqualTo []) exitWith { false };

private _last = missionNamespace getVariable ["AP_deckGangAsk", -999];
if (diag_tickTime - _last < 10) exitWith { false };
AP_deckGangAsk = diag_tickTime;

AP_gangMembersList_ready = false;
[[AP_gang_data select 0, player], "APS_fnc_getGangInfo", 2] call AP_fnc_MP;
true
