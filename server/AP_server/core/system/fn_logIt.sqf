/*
    APS_fnc_logIt / APS_fnc_logIt  (LooneyBin REBUILT 2026-06-09 -- universal audit sink)
    The 2017 original mapped args wrong (the MESSAGE landed in the table-name slot and was discarded)
    and wrote to a `log` table that didn't exist -- so all ~130 call sites (-KILLED-, -ADMINACTION-,
    -GEAREXPLOIT-, money ops 99x, AC tamper 913, ...) have NEVER persisted anything. This version:
      * accepts EVERY legacy caller shape:
          [tagStr, unitObj, nameStr, msgStr]      (-KILLED- style)
          [codeNum, unitObj, msgStr]              (997 gangBank style)
          [codeNum, uidStr, msgStr]               (999 style)
          [tag, objNull/nil, msg]                 (server-origin events)
      * sanitizes, INSERTs into `log` (ts/tag/playerid/name/message/instance, indexed tag+pid),
      * mirrors to the RPT as [LB-LOG] for live tailing.
    Query examples (anticheat): SELECT * FROM log WHERE tag='-GEAREXPLOIT-' ORDER BY ts DESC;
                                SELECT * FROM log WHERE playerid='765611...' ORDER BY ts DESC LIMIT 50;
*/
private _tag  = format ["%1", param [0, "?"]];
private _who  = param [1, objNull];
private _uid  = "SERVER";
private _name = "SERVER";
// owner 2026-07-24 SECURITY (audit: forgeable ban evidence). This fn is CfgRE-whitelisted
// allowedTargets=2 and BOTH identity paths below are client-controlled: arg 1 as a String is taken
// verbatim as the playerid, and arg 1 as an object has getPlayerUID read off whatever unit was passed.
// A modified client can therefore INSERT rows into `log` attributed to ANY Steam64 with any tag -- and
// `log` is the evidence base CLANKR's auto-ban rules query, so a cheater could fabricate ban-triggering
// rows against innocent players.
//
// We deliberately do NOT force the identity to the caller. Legitimate client call sites attribute a row
// to somebody OTHER than the caller by design: fn_onPlayerKilled runs on the VICTIM's machine and logs
// "-KILLED-" against the KILLER (likewise "-NEWBLOOD-"), fn_removeFiringPin logs against the civ, and
// fn_talLog logs against its subject. Overwriting playerid would reattribute every kill to the victim
// and corrupt the kill log.
//
// Instead: stamp VERIFIED provenance. For any client-originated call, append @SRC=<uid of the machine
// that actually called>. The claimed subject stays in playerid (semantics unchanged, nothing breaks),
// but every row now carries ground truth about who submitted it, so a forged row is detectable and
// attributable. FOLLOW-UP OWED (clankr.py): the three standalone auto-ban rules must require
// @SRC absent (server-origin) or @SRC == playerid before banning; until then treat client-submitted
// rows as unverified evidence. Server-internal calls (remoteExecutedOwner == 0) are unaffected.
private _reo = remoteExecutedOwner;
private _srcUid = "";
if (_reo != 0) then {
    { if (owner _x isEqualTo _reo) exitWith { _srcUid = getPlayerUID _x; }; } forEach allPlayers;   // exitWith intentionally exits the forEach
    if (_srcUid isEqualTo "") then { _srcUid = format ["owner:%1", _reo] };   // still record it if the unit is gone
};
switch (true) do {case (_who isEqualType objNull && {!isNull _who}): { _uid = getPlayerUID _who; _name = name _who; };
    case (_who isEqualType ""): { _uid = _who; };};
// message = every remaining arg that stringifies usefully (handles both 3- and 4-arg shapes; the
// legacy 4-arg shape's 3rd element is the name again -- drop it when it just repeats _name)
private _parts = [];
for "_i" from 2 to ((count _this) - 1) do {private _p = format ["%1", _this select _i];
    if (_p isNotEqualTo "" && {_p isNotEqualTo _name}) then { _parts pushBack _p; };};
private _msg = _parts joinString " | ";
// LooneyBin (owner 2026-06-12, max-detail logging): when the caller passed a live unit, append a
// machine-parseable context block to EVERY row -- position, side, vehicle, speed, damage, server
// uptime. Single-point change = all ~130 call sites gain forensic context for CLANKR / !logs.
if (_who isEqualType objNull && {!isNull _who}) then {private _veh = vehicle _who;
    _msg = _msg + format [" @CTX pos=%1 side=%2 veh=%3 spd=%4 dmg=%5 t=%6", (getPosATL _who) apply { round _x }, side _who,
        (if (_veh isEqualTo _who) then { "foot" } else { typeOf _veh }), round speed _veh, (damage _who) toFixed 2, round serverTime];};
// verified provenance for client-submitted rows (see the SECURITY note at the top). Appended AFTER the
// @CTX block and BEFORE sanitising, so the uid is stripped of quotes like every other interpolated value.
if (_srcUid isNotEqualTo "") then { _msg = _msg + format [" @SRC=%1", _srcUid]; };
private _san = { (format ["%1", _this]) splitString "\'""" joinString "" };
_tag  = _tag  call _san;  _uid = _uid call _san;
_name = _name call _san;  _msg = _msg call _san;
diag_log format ["[LB-LOG][%1] %2 (%3): %4", _tag, _name, _uid, _msg];
[format ["INSERT INTO log (tag, playerid, name, message, instance) VALUES ('%1','%2','%3','%4','%5')",
    _tag, _uid, _name, _msg, (localNamespace getVariable "APS_serverInstance")]] call DB_fnc_asyncQuery;
