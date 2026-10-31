/*
    APS_fnc_gangRenameSRV  (Armapunk 2035 2026-08-14)
    Client args: [_gangID, _newName]   (AP_fnc_gangRename, from the web deck's gang screen)

    Renames a gang. There was no rename path at all before this -- a gang's name was
    fixed at creation -- so the deck's gang-name field answered ok=false. Owner call
    2026-08-14: build it, and CHARGE for it, so a name is not free to churn.

    The fee comes out of the GANG BANK (AP_gangRenameFee, published in vars.sqf so the
    page can price the button; the server still owns the charge).

    SECURITY, same shape as fn_gangBank / fn_setGangTagSRV:
      - the caller is resolved from remoteExecutedOwner, NEVER from the payload
      - the caller must be the gang's LEADER (players.gangrank0 = 1) of THIS gang
      - the name is stripped of \ ' " before it reaches any format[] SQL
      - the fee is charged with a relative, floored UPDATE (never an absolute set)

    AP_server_gangs row: [id@0, name@1, wars@2, inviteRank@3, kickRank@4, bank@5, members@6, exp@7, talents@8]
*/
if ("AP_server_training" call DB_fnc_flag) exitWith {};
params [["_gangID", -1, [0, -1, ""]], ["_name", "", [""]]];

private _san = { (format ["%1", _this]) splitString "\'""" joinString "" };   // strips \ ' " (matches fn_logIt)
private _idStr = (format ["%1", _gangID]) call _san;
private _src = remoteExecutedOwner;   // 0 == server-internal; nothing internal renames a gang
private _caller = if (_src isEqualTo 0) then { objNull } else { (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };
if (isNull _caller) exitWith {};
private _callerUID = getPlayerUID _caller;
private _fee = missionNamespace getVariable ["AP_gangRenameFee", 50000];

private _refuse = {
    params ["_why"];
    [[1, _why], "AP_fnc_broadcast", _caller, false] spawn AP_fnc_MP;
};

// ---- the name -------------------------------------------------------------
// Same rules fn_createGang enforces client-side, re-enforced here because the deck
// is a client and a client's validation is a courtesy, not a gate.
private _safeName = trim ((_name call _san) select [0, 25]);
if (count _safeName < 3) exitWith { ["A gang name must be at least 3 characters."] call _refuse };

// ---- the caller must be this gang's leader --------------------------------
private _rankRow = [format ["SELECT gangrank0 FROM %3 WHERE playerid='%1' AND gang0='%2'", _callerUID, _idStr, "players"], 2] call DB_fnc_asyncQuery;
private _isMember = (_rankRow isEqualType []) && {count _rankRow >= 1} && {!isNil { _rankRow select 0 }};
private _rank = if (_isMember) then { parseNumber (format ["%1", _rankRow select 0]) } else { 99 };
if (_rank isNotEqualTo 1) exitWith {
    ["-SEC-", _caller, format ["BLOCKED gangRenameSRV gang=%1 name=%2 by %3 (rank %4)", _idStr, _safeName, _callerUID, _rank]] call APS_fnc_logIt;
    ["Only the gang leader can rename the gang."] call _refuse;
};

// ---- the name must be free ------------------------------------------------
private _taken = [format ["SELECT id FROM gangs WHERE name='%1' AND instance='%2'", _safeName, (localNamespace getVariable "APS_serverInstance")], 2] call DB_fnc_asyncQuery;
if (!isNil "_taken" && {_taken isEqualType []} && {!(_taken isEqualTo [])}) exitWith {
    private _otherId = format ["%1", _taken select 0];
    if (_otherId isEqualTo _idStr) then {
        ["That is already your gang's name."] call _refuse;
    } else {
        ["There is already an existing gang using the name which you provided."] call _refuse;
    };
};

// ---- the gang bank must cover the fee -------------------------------------
private _bankRow = [format ["SELECT bank FROM gangs WHERE id='%1'", _idStr], 2] call DB_fnc_asyncQuery;
if (isNil "_bankRow" || {!(_bankRow isEqualType [])} || {_bankRow isEqualTo []}) exitWith {
    ["That gang no longer exists."] call _refuse;
};
private _funds = parseNumber (format ["%1", _bankRow select 0]);
if (_funds < _fee) exitWith {
    [format ["Renaming the gang costs $%1 from the gang bank -- it holds $%2.",
        [_fee] call AP_fnc_numberText, [_funds] call AP_fnc_numberText]] call _refuse;
};
private _newFunds = _funds - _fee;

// One statement: the name and the charge land together, and the charge is relative
// and floored so it cannot go negative if the fund moved during the checks above.
[format ["UPDATE gangs SET name='%1', bank=GREATEST(bank-%2,0) WHERE id='%3'",
    _safeName, _fee, _idStr], 2] call DB_fnc_asyncQuery;

// Keep the boot cache honest -- fn_gangBank reads bank from it, and the old name
// would otherwise survive until the next restart.
private _idx = AP_server_gangs findIf { (format ["%1", _x select 0]) isEqualTo _idStr };
if (_idx > -1) then {
    private _gang = AP_server_gangs select _idx;
    _gang set [1, _safeName];
    _gang set [5, ((_gang select 5) - _fee) max 0];
    AP_server_gangs set [_idx, _gang];
};

[format ["INSERT INTO gang_bank_log (gangid, name, uid, type, amount) VALUES ('%1','%2','%3','2','%4')",
    _idStr, ((name _caller) call _san), _callerUID, _fee]] call DB_fnc_asyncQuery;
[[997, _caller, format ["Gang(%1) RENAME -> '%2' by %3 (%4), fee $%5 -> fund $%6. Srv %7",
    _idStr, _safeName, name _caller, _callerUID, _fee, _newFunds, AP_server_instance]], "APS_fnc_logIt", false, false] spawn AP_fnc_MP;

// ---- tell every member who is online --------------------------------------
// Their AP_gang_data carries the name; a member who never hears about the rename
// keeps showing the old one until they relog, and their next gang op sends it back.
{
    private _gd = _x getVariable ["gang_data", []];
    if ((format ["%1", _gd param [0, -1]]) isEqualTo _idStr) then {
        [[_gangID, _safeName, _newFunds], "AP_fnc_gangRenamed", _x, false] spawn AP_fnc_MP;
    };
} forEach allPlayers;
