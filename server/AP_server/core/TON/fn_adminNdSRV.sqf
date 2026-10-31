/*
    APS_fnc_adminNdSRV -- staff grant of New Drachma, server-authoritative.

    [target-unit-or-objNull, amount-string] from a staff client (deck staff app
    or the classic admin dialog). objNull target = the caller themselves.

    THE CALLER IS remoteExecutedOwner, NEVER THE PAYLOAD (standing rule), and
    the admin gate is re-checked HERE against players_global -- the client-side
    level check is UI courtesy only. Server owns anything that pays.

    The credit itself goes through APS_fnc_ndCreditSrv (the ND ledger's one
    write path: per-uid lock, DECIMAL(20,4) string discipline, client resync),
    so this function decides WHO may, and that path decides HOW.
*/
params [["_target", objNull, [objNull]], ["_amt", "", [""]]];

private _src = remoteExecutedOwner;
private _caller = (allPlayers select { owner _x isEqualTo _src }) param [0, objNull];
if (isNull _caller) exitWith {};
private _callerUid = getPlayerUID _caller;

private _lvlRow = [format ["SELECT adminlevel FROM players_global WHERE playerid='%1'", _callerUid], 2] call DB_fnc_asyncQuery;
private _lvl = parseNumber format ["%1", _lvlRow param [0, 0]];
if (_lvl < 3) exitWith {
    [["-SEC-", _caller, name _caller, format ["BLOCKED adminNdSRV: level %1 tried to grant %2 ND", _lvl, _amt]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
};

// whole ND only from the menu, 1..1,000,000 -- the ledger path re-validates its own format
if (!(_amt regexMatch "\d{1,7}") || {(parseNumber _amt) < 1} || {(parseNumber _amt) > 1000000}) exitWith {
    [["amount must be 1..1000000 ND", "basic"], "AP_fnc_handleMessage", _caller, false, false] spawn AP_fnc_MP;
};

if (isNull _target) then { _target = _caller; };
if !(getPlayerUID _target regexMatch "\d{17}") exitWith {};

private _ok = [_target, _amt, format ["admin:%1", _callerUid]] call APS_fnc_ndCreditSrv;
if (_ok isEqualTo false) exitWith {
    [["ND grant failed -- see the server log", "basic"], "AP_fnc_handleMessage", _caller, false, false] spawn AP_fnc_MP;
};

[["-ADMINACTION-", _caller, name _caller, format ["granted %1 ND to %2 (%3)", _amt, name _target, getPlayerUID _target]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
[[format ["Granted %1 ND to %2.", _amt, name _target], "basic"], "AP_fnc_handleMessage", _caller, false, false] spawn AP_fnc_MP;
if !(_target isEqualTo _caller) then {
    [[format ["A staff member granted you %1 ND.", _amt], "basic"], "AP_fnc_handleMessage", _target, false, false] spawn AP_fnc_MP;
};
