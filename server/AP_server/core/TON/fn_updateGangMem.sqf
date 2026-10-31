/*
    APS_fnc_updateGangMem  (LooneyBin: REPAIRED adapter -- replaces the broken passthrough stub that fed
    APS_fnc_gangMember the wrong args, so gang membership was NEVER persisted -> members vanished on relog
    and the roster query found nobody).

    2020 client args: [_caller, _mode, _gangID, _gangName, _memberRef, _rank]
      _memberRef = member UID (string)  OR  an online member (unit object)
      _rank      = new gang rank (1 = leader .. 5 = member);  _rank < 0  ==> KICK / LEAVE
    Callers: gangInvite (join, mode 0), gangKick, manageRank (promote/demote), gangNewLeader.
    Persists players.gang0 / players.gangrank0 for that member (mirrors APS_fnc_gangMember).
*/
params [["_caller", objNull], ["_mode", -1, [0]], ["_gangID", 0, [0, ""]], ["_gangName", "", [""]], ["_memberRef", "", ["", objNull]],
    ["_rank", -1, [0]]];
if ("AP_server_training" call DB_fnc_flag) exitWith {};

// owner 2026-06-23 SECURITY (security.md §2.2/§2.3): was attacker-controlled -> kick/demote a leader or
// self-promote in ANY gang, with _memberRef-UID + _gangID raw in the UPDATE. Fixes: NON-SPOOFABLE caller;
// on JOIN (mode 0) the joiner is FORCED to the real caller (self-write only); for any OTHER op the caller
// must be a MEMBER of _gangID (closes the cross-gang disband/kick/demote-rival CRIT) and may not RAISE their
// own rank (self-promote closed); escape both client strings for SQL. The finer "can't act on a same-gang
// member at/above your own rank" is enforced client-side (fn_manageRank/fn_gangKick) and is left to it here
// to avoid colliding with the async two-call leadership-transfer flow (fn_gangNewLeader) -> NEEDS OWNER REVIEW.
private _san = { (format ["%1", _this]) splitString "\'""" joinString "" };
private _src = remoteExecutedOwner;   // 0 == server-internal = trusted
private _caller2 = if (_src isEqualTo 0) then { objNull } else { (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
private _callerUID = getPlayerUID _caller2;
private _gangSafe = (format ["%1", _gangID]) call _san;

private _uid = "";
// LooneyBin fix: on JOIN (mode 0) the player who accepted the invite is the one joining the gang.
// gangInvite mistakenly passes the *inviter* in the member slot, so persisting _memberRef just re-wrote the
// inviter's row and the new member's gang0 was never set. Every other caller (kick/leave/rank/leader, modes
// 1/2) correctly puts the target member at _memberRef, so only mode 0 needs the override. SECURITY: for a
// client mode-0 call the joiner = the NON-SPOOFABLE caller (can only enrol THEMSELVES).
private _ref = if (_mode isEqualTo 0) then { if (_src isEqualTo 0) then { _caller } else { _caller2 } } else { _memberRef };
// SECURITY: a client mode-0 (JOIN) must enrol at the lowest rank only -- the legit invite path always sends
// rank 5; without this clamp a scripter self-joins any gang as gangrank0=1 (leader). Server-internal unchanged.
if (_mode isEqualTo 0 && {_src != 0}) then { _rank = 5; };
if (_ref isEqualType objNull) then {if (!isNull _ref) then { _uid = getPlayerUID _ref; };} else {_uid = _ref;};
_uid = _uid call _san;   // SQLi-safe target UID (reaches the UPDATE WHERE playerid)
if (_uid isEqualTo "") exitWith {};

// AUTHZ for a CLIENT call (server-internal src==0 always passes). Mode 0 = self-enrol, already identity-bound
// above (no further check). All other ops: the caller must belong to _gangID, and a self-targeted op may only
// LOWER the caller's rank or leave (rank<0) -- never self-promote.
if (_src != 0 && {_mode != 0}) then {private _ok = true;
    private _crow = [format ["SELECT gangrank0 FROM %2 WHERE playerid='%1' AND gang0='%3'", _callerUID, "players", _gangSafe], 2] call DB_fnc_asyncQuery;
    private _isMember = (_crow isEqualType []) && {count _crow >= 1} && {!isNil { _crow select 0 }};
    private _crank = if (_isMember) then { parseNumber (format ["%1", _crow select 0]) } else { 99 };
    if (!_isMember) then { _ok = false; };   // not in this gang -> can't manage it (kills the rival-gang attack)
    if (_ok && {_uid isEqualTo _callerUID} && {_rank >= 0} && {_rank < _crank}) then { _ok = false; };   // self-promote (lower number = higher) -> deny
    // owner 2026-07-24 SECURITY (audit): membership alone was the whole gate for acting on OTHERS, so ANY
    // member could manage anyone -- a rank-5 recruit could kick the rank-1 leader, or promote an accomplice.
    // Ranks are INVERTED here (1 = leader .. 5 = recruit), so "lower number = more authority".
    // Require leader/officer (rank <= 2) to act on someone ELSE. Self-targeted ops are untouched (leaving,
    // and self-demotion, must stay open to everyone).
    // DELIBERATELY NOT ADDED, and why: the two obvious extra rules -- "cannot grant a rank above your own"
    // and "cannot act on a target at/above your own rank" -- would BREAK leadership transfer. The file's own
    // note flagged this collision for owner review, and fn_gangNewLeader confirms it: it demotes the current
    // leader to rank 2 FIRST (:27), THEN promotes the new leader to rank 1 (:33) -- so the second call is a
    // rank-2 caller granting rank 1, which either rule would reject. This gate is verified safe for that
    // flow: call 1 is self-targeted (exempt) and call 2 comes from a rank-2 caller, which passes <= 2.
    // RESIDUAL for owner review: an officer can still kick another officer or hand out leadership.
    if (_ok && {_uid isNotEqualTo _callerUID} && {_crank > 2}) then { _ok = false; };
    if (!_ok) then {
        ["-SEC-", _caller2, format ["BLOCKED updateGangMem mode=%1 gang=%2 target=%3 newRank=%4 by %5 (rank %6)", _mode, _gangSafe, _uid, _rank, _callerUID, _crank]] call APS_fnc_logIt;
        _uid = "";   // flag failure -> top-level guard exits the FUNCTION
    };};
if (_uid isEqualTo "") exitWith {};

private _query = if (_rank < 0) then {
    // kick / leave -> clear membership (mirrors fn_deleteGang's ex-member reset: gang0='0', gangrank0='3')
    format ["UPDATE %2 SET gang0='0', gangrank0='3' WHERE playerid='%1'", _uid, "players"]} else {
    format ["UPDATE %3 SET gang0='%2', gangrank0='%4' WHERE playerid='%1'", _uid, _gangSafe, "players", _rank]};
[_query] call DB_fnc_asyncQuery;
diag_log format ["[LooneyBin][updateGangMem] persisted uid=%1 gang0=%2 rank=%3 (mode=%4)", _uid, _gangID, _rank, _mode];

// Keep the server's own uid -> gang map in step with the row just written. Seeded
// at login in fn_queryRequest; maintained here because this is the single funnel
// every join, kick, leave and rank change goes through. It is what the ArmaQuest
// `align:` prerequisite reads, and reading it instead of the public `gang_data`
// object variable is the whole point -- that one is written by the observed
// player's own client and cannot gate anything.
//
// _rank < 0 is the removal sentinel this function already uses for kick and leave
// (it is what turns the query into gang0='0'), so the two branches here mirror the
// two branches of the query above rather than re-deriving anything.
private _gangOf = localNamespace getVariable "APS_gangOfUid";   // localNamespace (vars.sqf): no client publicVariable reaches it
if (_rank < 0) then {
    _gangOf deleteAt _uid;
} else {
    _gangOf set [_uid, parseNumber (format ["%1", _gangSafe])];

    // FIVE MEMBERS AND NO PATRON. The gang is not locked, nothing is taken away --
    // the pressure is that the fixers' best work is gated on alignment and this
    // gang cannot see it. Telling them once, at the moment the threshold is
    // crossed, is the difference between a design and a secret.
    //
    // Counted with the same subquery fn_queryGangs uses, because there is no
    // members column -- membership lives on players.gang0, and counting it any
    // other way would be a second definition of what a gang member is.
    private _cnt = [format ["SELECT COUNT(*) AS n FROM %2 WHERE gang0='%1'", _gangSafe, "players"], 2] call DB_fnc_asyncQuery;
    private _n = if (_cnt isEqualType [] && {count _cnt > 0}) then { parseNumber (format ["%1", _cnt select 0]) } else { 0 };
    if (_n >= AP_FACTION_ALIGN_AT) then {
        private _fr = [format ["SELECT COALESCE(faction,'') AS faction FROM gangs WHERE id='%1'", _gangSafe], 2] call DB_fnc_asyncQuery;
        private _cur = if (_fr isEqualType [] && {count _fr > 0}) then { format ["%1", _fr select 0] } else { "" };
        if (_cur isEqualTo "") then {
            private _names = ((["all"] call AP_fnc_factionCfg) select { (_x param [5, []]) isNotEqualTo [] } apply { _x select 1 }) joinString ", ";
            {
                [[format ["Your gang is %1 strong and answers to nobody. The fixers -- %2 -- keep their best work for crews that have picked a side.", _n, _names], "info"],
                 "AP_fnc_handleMessage", _x, false] spawn AP_fnc_MP;
            } forEach (allPlayers select { !(isNull _x) && {(_x getVariable ["gang_data", [-1]]) param [0, -1] isEqualTo (parseNumber (format ["%1", _gangSafe]))} });
        };
    };
};

// owner 2026-06-16 (#266 "gang rank 2 cannot access the gang bank"): push the new rank to the member's
// LIVE client so rank-gated actions (the gang bank gate reads AP_gang_data select 2, also fn_setGangHouse
// etc.) take effect WITHOUT a relog. This was DB-ONLY -> a member promoted to rank 2 stayed at their old
// AP_gang_data[2] until they relogged, so the gang bank kept rejecting them. Only for an ONLINE member
// rank change (mode 2, rank>=0); AP_fnc_gangRanks is CfgRE-whitelisted and sets AP_gang_data[2] + gang_data.
if (_mode isEqualTo 2 && {_rank >= 0} && {_memberRef isEqualType objNull} && {!isNull _memberRef}) then {
    [[_rank], "AP_fnc_gangRanks", _memberRef, false, false] spawn AP_fnc_MP;};
