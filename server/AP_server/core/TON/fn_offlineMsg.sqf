/*
    APS_fnc_offlineMsg  (Armapunk 2035, owner 2026-08-11) -- queue a text for a player who is
    not on the server. Runs on the SERVER. CfgRE allowedTargets = 2 (client -> server).

        [_targetUid, _msg] remoteExec -> here

    Why this is not just another mode in APS_fnc_handlePhoneMsg: that router addresses its
    recipient as an OBJECT (_target), and an offline player has no object. So the recipient is
    identified by uid here, which means the uid arrives from the client and every check below
    has to assume it is hostile.

    SECURITY, matching the hardening already on APS_fnc_handlePhoneMsg:
      * the SENDER's identity is taken from remoteExecutedOwner, never from the payload -- the
        same impersonation hole that fn_handlePhoneMsg was fixed for in the 2026-07-24 audit.
      * the target uid is shape-checked (digits, sane length) before it reaches SQL, and the
        message is stripped of quote characters, so neither can break out of the INSERT.
      * a player who IS online is not queued -- that path already exists and works, and
        allowing it here would let someone bypass the live delivery checks.
      * rate limited per sender and capped per recipient, so the table cannot be flooded.
*/
if (!isServer) exitWith {};
params [["_targetUid", "", [""]], ["_msg", "", [""]]];

// ---- sender identity: the verified actor, never the payload --------------------------------
private _src = remoteExecutedOwner;
private _unit = if (_src isEqualTo 0) then { objNull } else {
    (allPlayers select { owner _x isEqualTo _src }) param [0, objNull]
};
if (isNull _unit) exitWith {};
private _fromUid = getPlayerUID _unit;
if (_fromUid isEqualTo "") exitWith {};

if (_msg isEqualTo "" || {_targetUid isEqualTo ""}) exitWith {};

// ---- the target uid is client-supplied, so validate its SHAPE before trusting it with SQL ---
// A Steam64 is 17 digits. Anything else is either a bug or an injection attempt.
if (count _targetUid > 32) exitWith {
    ["-SEC-", _unit, format ["offline msg: oversized target uid (%1 chars)", count _targetUid]] call APS_fnc_logIt;
};
if ((_targetUid splitString "") findIf { !(_x in ["0","1","2","3","4","5","6","7","8","9"]) } > -1) exitWith {
    ["-SEC-", _unit, format ["offline msg: non-numeric target uid '%1'", _targetUid]] call APS_fnc_logIt;
};
if (_targetUid isEqualTo _fromUid) exitWith {};   // texting yourself achieves nothing

// ---- online players go down the live path, not this one ------------------------------------
if ((allPlayers findIf { (getPlayerUID _x) isEqualTo _targetUid }) > -1) exitWith {
    [["That player is online -- send it normally.", "basic"], "AP_fnc_handleMessage", _unit, false, false] spawn AP_fnc_MP;
};

// ---- rate limit, same shape as APS_fnc_bonesDM ----------------------------------------------
if (isNil "AP_offlineMsgLast") then { AP_offlineMsgLast = createHashMap; };
if ((serverTime - (AP_offlineMsgLast getOrDefault [_fromUid, -999])) < 10) exitWith {
    [["Slow down -- one message at a time.", "basic"], "AP_fnc_handleMessage", _unit, false, false] spawn AP_fnc_MP;
};
AP_offlineMsgLast set [_fromUid, serverTime];

// ---- cap the recipient's queue so an inbox cannot be flooded --------------------------------
private _pending = [format ["SELECT COUNT(*) AS c0 FROM offline_msgs WHERE to_uid='%1' AND delivered = false", _targetUid], 2, true] call DB_fnc_asyncQuery;
private _n = parseNumber format ["%1", (_pending param [0, [0]]) param [0, 0]];
if (_n >= 20) exitWith {
    [["Their inbox is full -- try again when they are online.", "basic"], "AP_fnc_handleMessage", _unit, false, false] spawn AP_fnc_MP;
};

// ---- sanitise exactly as bonesDM does -------------------------------------------------------
private _clean = _msg select [0, 500];
_clean = ((_clean splitString "'""`\") joinString "");
private _nm = ((name _unit) splitString "'""`\") joinString "";
if ((count _nm) > 28) then { _nm = _nm select [0, 28]; };

[format ["INSERT INTO offline_msgs (to_uid, from_uid, from_name, message) VALUES ('%1','%2','%3','%4')",
    _targetUid, _fromUid, _nm, _clean]] call DB_fnc_asyncQuery;

[["Sent. They will get it next time they log in.", "basic"], "AP_fnc_handleMessage", _unit, false, false] spawn AP_fnc_MP;
["-OFFLINEMSG-", _unit, _nm, format ["queued for %1: %2", _targetUid, _clean]] call APS_fnc_logIt;
