/*
    fn_pysqfDiag.sqf  —  registered as  APS_fnc_pysqfDiag

    THE PROBLEM THIS SOLVES
      Both diagnostics live in the server addon, so they exist only on the server.
      A dedicated server has no debug console, and CfgRE is a whitelist, so until
      now the only way to run either one was to edit initServer.sqf, deploy, read
      the log and revert -- a ninety-second loop for a test whose whole point is
      being cheap to repeat.

      This is the one entry point, whitelisted for clients, admin-gated on BOTH
      sides:

          ["smoke"]   remoteExec ["APS_fnc_pysqfDiag", 2];
          ["conform"] remoteExec ["APS_fnc_pysqfDiag", 2];

    THE GATE
      The caller is resolved from remoteExecutedOwner, never from the payload, and
      their adminlevel is re-read from players_global -- the same shape
      APS_fnc_changeWeather uses. A client that lies about being staff gets a -SEC-
      line and nothing else. Level 3.

      That matters more here than for a cosmetic verb: these run real work against
      the Python daemon and the database, and conform issues ~113 calls. An
      ungated diagnostic is a free denial-of-service against the layer the whole
      migration is about to sit on.

    OUTPUT
      Goes to the server RPT, prefixed [pysqf-smoke] / [pysqf-conform], because
      that is where the harness reads it. The caller gets a one-line acknowledgement
      so they know it started rather than watching nothing happen.
*/
params [["_which", "smoke", [""]]];

private _src = remoteExecutedOwner;   // 0 = server-internal = trusted
private _caller = if (_src isEqualTo 0) then { objNull } else {
    (allPlayers select { owner _x isEqualTo _src }) param [0, objNull] };

// _blocked carries the refusal out: an exitWith inside the then-block only leaves that block.
private _blocked = false;
if (_src isNotEqualTo 0) then {
    private _uid = getPlayerUID _caller;
    private _rows = [format ["SELECT adminlevel FROM players_global WHERE playerid='%1'",
        (_uid splitString "\'""") joinString ""], 2, true] call DB_fnc_asyncQuery;
    private _lvl = parseNumber format ["%1", (_rows param [0, [0]]) param [0, 0]];
    if (_lvl < 3) exitWith {
        _blocked = true;
        ["-SEC-", _caller, format ["BLOCKED pysqfDiag '%1' by %2 (level %3)", _which, _uid, _lvl]] call APS_fnc_logIt;
    };
};
if (_blocked) exitWith {};

private _label = toLower _which;
if !(_label in ["smoke", "conform"]) exitWith {
    diag_log format ["[pysqf-diag] unknown diagnostic '%1' -- use smoke or conform", _which];
    if (!isNull _caller) then {
        [[1, format ["pysqf: no diagnostic called '%1'. Use smoke or conform.", _which]],
            "AP_fnc_broadcast", _caller, false] spawn AP_fnc_MP;
    };
};

diag_log format ["[pysqf-diag] running %1 for %2", _label,
    if (isNull _caller) then { "server" } else { format ["%1 (%2)", name _caller, getPlayerUID _caller] }];

if (!isNull _caller) then {
    [[1, format ["pysqf: %1 started -- results are in the server RPT.", _label]],
        "AP_fnc_broadcast", _caller, false] spawn AP_fnc_MP;
};

// Both suites need a scheduled context; both are slow enough to want their own.
switch (_label) do {
    case "smoke":   { [] spawn APS_fnc_pysqfSmoke };
    case "conform": { [] spawn APS_fnc_pysqfConform };
};
