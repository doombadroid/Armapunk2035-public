// SPDX-License-Identifier: MIT
/*
    fn_postInit.sqf -- bring the client half up once the world exists: attach
    every giver's interaction driver, and ask the server for this player's
    quests.

    WHY THIS EXISTS
      Two things cannot happen at preInit, and both of them look like the whole
      system being broken when they are missed.

      A giver with no interaction is content that exists and cannot be played.
      Giver objects are spawned by the server, so at preInit there is nothing to
      attach to on a client, and there may still be nothing a second later --
      the object has to replicate. The driver therefore has to be attached from
      the client, after the world is up, with a bounded retry rather than one
      hopeful attempt. Attaching on the server instead would put a scroll action
      on a machine with no player on it.

      And the client holds no quest state of its own by design: it is always
      told, never remembers. A player who joins mid-session, or who reconnects,
      has an empty journal until something pushes to them. So the first thing
      this client does is ask.

    WHAT IT DOES
      Client only. Waits for the player and for preInit's verdict, requests a
      resync, then walks AQ_Givers and calls each giver's registered trigger
      driver as [_giverId, _giverObject, _giverConfig]. A giver whose object has
      not replicated yet is retried; one that never appears is named once, at
      the end, rather than once per attempt.

      A driver that needs no object (a phone app, a radio menu) is called on the
      first pass with objNull and is not retried, because there is nothing to
      wait for.

    Usage:  call aq_fnc_postInit;      // from CfgFunctions postInit = 1
*/

if (!hasInterface) exitWith { false };

[] spawn {
    // preInit sets aq_ready; a client that arms givers against a catalogue
    // nobody validated is the disarmed case this library refuses to run.
    waitUntil { !isNil "aq_ready" && {!isNull player} };
    if (!aq_ready) exitWith {
        diag_log "[AQ] postInit: aq_ready is false, so no giver is armed and no state is requested. The validation report above says why.";
    };

    // The client is stateless about quests: it asks, and the server answers by
    // pushing everything this player holds.
    [player, "", []] remoteExec ["aq_fnc_srvFact", 2];

    if (isNil "aq_idxGiver") exitWith {
        diag_log "[AQ] postInit: no giver index; aq_fnc_preInit did not run.";
    };

    private _pending = keys aq_idxGiver;
    private _armed   = [];

    for "_pass" from 1 to 30 do {
        private _still = [];
        {
            private _gid = _x;
            private _cfg = aq_idxGiver getOrDefault [_gid, configNull];

            private _driverName = if (isNull _cfg) then { "" } else {
                if (isText (_cfg >> "trigger")) then { getText (_cfg >> "trigger") } else { "addAction" }
            };
            if (_driverName isEqualTo "") then { _driverName = "addAction"; };
            private _driver = (localNamespace getVariable "aq_triggers") getOrDefault [_driverName, {}];

            if (_driver isEqualTo {}) then {
                // Reported once, by name. Validation already refuses a catalogue
                // that reaches here, so this is the belt to that braces.
                if (_pass isEqualTo 1) then {
                    diag_log format ["[AQ] postInit: giver '%1' names trigger driver '%2', which is not registered; nobody can reach this giver.", _gid, _driverName];
                };
            } else {
                private _obj = missionNamespace getVariable [format ["aq_giverObj_%1", _gid], objNull];
                private _wantsObject = !isNull _cfg && {isText (_cfg >> "object")} && {(getText (_cfg >> "object")) != ""};

                if (!isNull _obj || {!_wantsObject}) then {
                    if ([_gid, _obj, _cfg] call _driver) then { _armed pushBackUnique _gid; };
                } else {
                    _still pushBack _gid;
                };
            };
        } forEach _pending;

        _pending = _still;
        if (_pending isEqualTo []) exitWith {};
        sleep 1;
    };

    if !(_pending isEqualTo []) then {
        diag_log format ["[AQ] postInit: giver object(s) for %1 never appeared, so those givers have no interaction on this client. The server spawns them from AQ_Givers >> object at AQ_Givers >> marker; check both exist.", _pending];
    };
    diag_log format ["[AQ] postInit: %1 giver(s) armed on this client.", count _armed];
};

true
