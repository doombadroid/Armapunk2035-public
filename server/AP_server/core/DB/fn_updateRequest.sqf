/*
    DB_fnc_updateRequest  (LooneyBin: 2020 full save)
    client fn_ClupdateRequest -> [player, name, side, cash, atmcash, side_talents, side_exp, (civ)pos]
    Core periodic/disconnect save. Per-field state goes via DB_fnc_updatePartial.
*/
params [["_player",objNull,[objNull]],["_name","",[""]],["_side",civilian,[civilian]],["_cash",0,[0]],["_bank",0,[0]],["_talents",[],[[]]],["_exp",0,[0]]];
if (isNull _player) exitWith {};
private _uid = getPlayerUID _player;
if (_uid == "") exitWith {};
// THE ACTING ACCOUNT IS THE CALLER, NOT THE PACKET -- the same rule and the same reasoning as
// DB_fnc_updatePartial's copy of this block, which carries the long form (including why a server-local call
// is exempt and why an unresolvable sender is dropped without a row). `_player` is the client's own object
// reference, so `_uid` above is the uid of whoever the PACKET named; this full save rewrites name, cash,
// bankacc and a whole talent/exp pair on it. Refuse rather than re-route: the two candidates are two
// accounts, not two columns.
// It sits ABOVE the money guard on purpose -- that guard logs -MONEYGUARD- against `_uid`, and a forged uid
// would put an innocent account's Steam64 in the row.
private _src = remoteExecutedOwner;
private _sender = if (_src isEqualTo 0) then { objNull } else { (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
private _senderUid = if (_src isEqualTo 0) then { _uid } else { if (isNull _sender) then { "" } else { getPlayerUID _sender } };
if (_senderUid isNotEqualTo _uid) exitWith {
    if (_senderUid isNotEqualTo "") then {
        ["-SEC-", _sender, format ["BLOCKED cross-account full-save: packet named uid %1, sender is %2", _uid, _senderUid]] call APS_fnc_logIt;
    } else {
        // unattributable by construction (no live unit for this owner) -- RPT breadcrumb only, no DB row.
        diag_log format ["[AP-DUTY] full-save dropped, unresolvable sender: payload uid=%1 owner=%2", _uid, _src];
    };
};
// owner 2026-06-21 (Vista money-wipe, root cause): the client packet's cash/bank arrive as nil/`any` when
// fn_ClupdateRequest fires BEFORE the session loads AP_cash/AP_atmcash -- AP_session_completed goes
// stale-TRUE across sessions, so at reconnect it ran at connect-time. `params` above then SILENTLY defaults a
// nil cash/bank to 0, and this UPDATE wrote bankacc=0 over the real balance a split-second before the login
// query read it back (Vista 423,432 -> 0). When the money is non-numeric, EVERY field of this packet is a
// default/stale placeholder (talents=[], exp=0, ...), not just money -- so persisting ANY of it is corruption.
// Abort the whole save. The real periodic save fires again once the session is actually loaded.
if ((count _this < 5) || {isNil {_this select 3}} || {isNil {_this select 4}}
        || {!((_this select 3) isEqualType 0)} || {!((_this select 4) isEqualType 0)}) exitWith {
    ["-MONEYGUARD-", _uid, "blocked a nil/uninitialised full-save at connect (would have zeroed bank + wiped talents/exp)"] call APS_fnc_logIt;
};
// SIDE BY ROSTER, NOT BY PACKET -- the same rule and the same reasoning as DB_fnc_updatePartial's copy of this
// block, which carries the long form. Here it decides which pair of <side>_talents/<side>_exp columns the
// periodic full save rewrites, and (below) whether `position` is written at all. `_uid` is getPlayerUID of the
// unit the packet carried, so it is engine-derived rather than a client string, and it is the key the roster is
// stored under. Unrostered -- i.e. everyone, on a flag-false server -- keeps the client-claimed value verbatim.
private _sideFlag = switch (_side) do { case west:{"cop"}; case independent:{"med"}; default {"civ"} };
if (localNamespace getVariable ["AP_dutyEnabled", false]) then {   // server copy (Lsec-0-1); the published global is client-writable
    private _dutyRow = _uid call APS_fnc_dutyLookup;
    // AND ONLY ONCE THE SHIFT IS ACKED. The roster entry is written BEFORE the grant is pushed to the
    // client, and the client's very first act on receiving it is to flush the CIVILIAN character -- gear
    // (mode 3) and talents (mode 4) -- while AP_effSide still says civilian, because those columns are the
    // only copy of it. Routing on a bare "is rostered" would catch exactly that flush and write the
    // civilian's kit and trees into cop_gear/cop_talents, destroying the character the flush exists to
    // preserve, on every single sign-on. Slot 3 is APS_fnc_dutySRV's ack flag: false until the client has
    // confirmed the engine side actually moved, i.e. false for precisely the window in which the client is
    // telling the truth about being a civilian. Before the ack, believe the packet; after it, believe the
    // roster.
    private _rosterFlag = if !(_dutyRow param [3, false]) then { "" } else {
        switch (_dutyRow param [0, ""]) do {
            case "maxsec": {"cop"};
            case "trauma": {"med"};
            default {""};
        };
    };
    if (_rosterFlag isNotEqualTo "") then {
        if (_rosterFlag isNotEqualTo _sideFlag) then {
            // Standing rule: log subject from remoteExecutedOwner, never the payload -- `_player` above is
            // whatever object reference the CLIENT put in its own remoteExec'd array, so a forged call could
            // name anyone as the mismatch subject. `_sender` is that resolution, done once by the origin gate
            // at the top of the file (it used to be re-derived here, shadowing it). The uid stays in the
            // message text (already sanitized).
            ["-DUTY-", _sender, format ["ROUTE MISMATCH full-save uid=%1 claimed=%2 rostered=%3 -- saved as %3", _uid, _sideFlag, _rosterFlag]] call APS_fnc_logIt;
        };
        _sideFlag = _rosterFlag;
    };
};
// owner 2026-06-23 SECURITY (security.md §2.3): KRON_Replace is mission-only -> UNDEFINED on the dedicated
// server, so these calls threw / nil-corrupted the name and it reached the UPDATE unescaped. Replace with the
// in-repo _san strip. (_uid is getPlayerUID _player above = server-derived, digits-only -- not client-spoofable.)
private _san = { (format ["%1", _this]) splitString "\'""" joinString "" };
_name = _name call _san;

private _set = format ["name='%1', cash='%2', bankacc='%3', %4_talents='%5', %4_exp='%6'",
    _name, _cash call DB_fnc_numberSafe, _bank call DB_fnc_numberSafe,
    _sideFlag, [_talents] call DB_fnc_mresArray, _exp call DB_fnc_numberSafe];

// `position` is the CIVILIAN character's spawn point and nothing else (a duty officer respawns at HQ, and
// bleeding an on-duty logoff spot into this shared column is bug #439). Gate it on the ROUTED flag rather than
// the claimed side, so a rostered player who claims civilian cannot write it. Pre-flip _sideFlag is exactly the
// claimed side, so this is the same test it always was.
// Shape gate (PR10): a position is either the death sentinel [] (-> spawn menu on the next login) or a
// full [x,y,z]. Anything else is a malformed packet -- refuse it rather than store junk the login path
// would then have to defend against.
if (_sideFlag isEqualTo "civ" && count _this > 7) then {private _p7 = _this select 7;
    if ((_p7 isEqualType []) && {(count _p7 isEqualTo 0) || {count _p7 >= 3}}) then {
        _set = _set + format [", position='%1'", [_p7] call DB_fnc_mresArray];};};

[format ["UPDATE players SET %1 WHERE playerid='%2'", _set, _uid]] call DB_fnc_asyncQuery;
