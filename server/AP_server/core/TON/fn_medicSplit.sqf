/*
    APS_fnc_medicSplit  (LooneyBin: IMPLEMENTED -- was a logging no-op stub)
    Client args: [_partners, _share]   (from fn_revivePlayer / fn_medicRespondDone)

    When a medic revives someone with nearby Trauma Team partners, the reviver already credited their own
    share client-side and divided the reward by (partners+1); _share is that per-person cut. This pays
    each partner their cut. Server-authoritative: UPDATE the partner's bank in the DB (persists) + uC to
    sync their live view + a payout message. Was a no-op, so assisting medics never got paid.
    (copSplitReceive can't be reused -- it's west-only; medics are independent.)
*/
params [["_partners", [], [[]]], ["_share", 0, [0]]];

// owner 2026-06-23 SECURITY (security.md §2.1 HIGH): CfgRE-whitelisted -> a client could remoteExec
// [[accomplice], 9.9e8] to credit an accomplice's bank an arbitrary sum (the reviver's own share is added
// client-side, never run by a scripter). (1) Derive the REVIVER from the non-spoofable remoteExecutedOwner
// (model fn_seizeLock:22). (2) CLAMP _share to the per-person revive cut ceiling: a legit share is
// AP_revive_fee/(partners+1) <= the full fee, so the fee + headroom is a hard upper bound. The _partners
// are genuinely other medics we can't derive -> bounding _share is the authoritative control (partner
// legitimacy = NEEDS OWNER REVIEW). Also require a real caller on a client invocation.
private _src = remoteExecutedOwner;
private _caller = if (_src isEqualTo 0) then { objNull } else { (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
if (_src isNotEqualTo 0 && {isNull _caller}) exitWith { ["-SEC-", objNull, format ["BLOCKED medicSplit (no real caller, src %1)", _src]] call APS_fnc_logIt; };
private _MAX_SHARE = 10000;   // full revive fee is 2500 (client AP_revive_fee const) -> a per-person cut is <= that; 10k leaves ample headroom for any bonus while blocking the 9.9e8 exploit
_share = (round _share) min _MAX_SHARE;
if (_share <= 0 || {_partners isEqualTo []}) exitWith {}; {if (!isNull _x && {isPlayer _x}) then {private _uid = getPlayerUID _x;
        if (_uid != "") then {
            [format ["UPDATE players SET bankacc = bankacc + %1 WHERE playerid='%2'", _share, _uid]] call DB_fnc_asyncQuery;   // persist (authoritative)
            [["atm", "add", _share], "AP_fnc_uC", _x, false] spawn AP_fnc_MP;                                              // sync live bank view
            [[format ["Medical assist payout: +$%1", [_share] call AP_fnc_numberText], "basic"], "AP_fnc_handleMessage", _x, false] spawn AP_fnc_MP;
        };};} forEach _partners;
