/*
    APS_fnc_fabDebugSRV  (Armapunk -- FREE BUILD, a testing override)

        ["free", [true]]  call from an admin client, or  ["free", [false]]  to turn it off
        ["state", []]     report the current setting to the caller

    WHAT IT DOES. While free build is on, every fabricator ignores three things: the ingredients a
    recipe calls for, the fabrication level it needs, and whether you have learned its schematic.
    Everything else still runs exactly as it does normally -- the machine still has to exist, still
    has to be yours, still has to be the right KIND for the recipe (a bench for a weapon), the job
    still takes its full time, and collect is still the same fail-closed path. That is deliberate:
    the point is to test the rest of the system without first grinding a catalogue of materials, so
    the parts being proven have to keep working the way they will in production.

    ADMIN ONLY, AND THE GATE IS THE CALLER, NOT THE PAYLOAD. adminlevel comes out of the database
    keyed on remoteExecutedOwner -- the engine's answer to "which machine sent this" -- never from
    anything in the packet. Same pattern as APS_fnc_adminNdSRV, and for the same reason: a client
    that can name its own identity can name someone else's.

    It is SERVER STATE. AP_fabFreeBuild is publicVariable'd so the UI can grey the right things and
    the client can skip consuming materials, but the client's copy is advisory only -- every gate
    this bypasses is re-read from the server's own copy inside APS_fnc_fabSRV. A client setting its
    local flag gets a nicer-looking menu and exactly the same refusals.

    Every flip is logged, and the flag does NOT survive a restart. A testing override that quietly
    persists is a testing override that ends up on a live server.
*/
params [["_case", "", [""]], ["_data", [], [[]]]];
if (!isServer) exitWith {};

private _src = remoteExecutedOwner;
private _caller = if (_src isEqualTo 0) then { objNull } else {
    (allPlayers select { owner _x isEqualTo _src }) param [0, objNull]
};

// _src == 0 is server-internal and trusted (a boot call or another server fn). Anything else has
// to prove itself against the database. _blocked is the signal out: an exitWith in here only
// leaves this then-block, so the refusal has to be re-raised by the flat exitWith below.
private _blocked = false;
if (_src isNotEqualTo 0) then {
    if (isNull _caller) exitWith { _blocked = true };
    private _uid = getPlayerUID _caller;
    // parameterised: the value rides beside the SQL, not inside it (first
    // production user of DB_fnc_asyncQuery's params argument)
    private _row = ["SELECT adminlevel FROM players_global WHERE playerid = %s", 2, true, [_uid]] call DB_fnc_asyncQuery;
    // ROW then CELL. `_row param [0, 0]` returns the whole first ROW -- parseNumber "[3]" is 0, so
    // a bare single param blocks every admin including a real one. Same unwrap as fn_adminDelVeh.
    private _lvl = parseNumber format ["%1", (_row param [0, [0]]) param [0, 0]];
    if (_lvl < 3) exitWith {
        _blocked = true;
        ["-SEC-", _caller, format ["BLOCKED fabDebugSRV '%1' (adminlevel %2) by %3", _case, _lvl, _uid]] call APS_fnc_logIt;
        [["You are not authorised to do that.", "basic"], "AP_fnc_handleMessage", _caller, false, false] spawn AP_fnc_MP;
    };
};
if (_blocked) exitWith {};

private _say = {
    params ["_msg"];
    if (isNull _caller) exitWith { diag_log format ["[Armapunk][fab] %1", _msg] };
    [[_msg, "basic"], "AP_fnc_handleMessage", _caller, false, false] spawn AP_fnc_MP;
};

switch (toLower _case) do {

    case "free": {
        private _on = _data param [0, true];
        if !(_on isEqualType true) then { _on = true };
        // the SERVER's copy first -- APS_fnc_fabSRV reads only this one (Lsec-0-1); the global below is the display copy
        localNamespace setVariable ["AP_fabFreeBuild", _on];
        AP_fabFreeBuild = _on;
        publicVariable "AP_fabFreeBuild";
        [format ["<t color='%2'>FABRICATOR FREE BUILD %1</t><br/>Ingredients, level and schematics are %3.",
                 ["OFF", "ON"] select _on,
                 ["#e07a5a", "#7ad19a"] select _on,
                 ["enforced again", "ignored"] select _on]] call _say;
        ["-FAB-", _caller, format ["free build -> %1", _on]] call APS_fnc_logIt;
        diag_log format ["[Armapunk][fab] FREE BUILD %1", ["OFF", "ON"] select _on];
    };

    case "state": {
        [format ["Fabricator free build is %1.",
                 ["OFF", "ON"] select (localNamespace getVariable ["AP_fabFreeBuild", false])]] call _say;
    };
};
