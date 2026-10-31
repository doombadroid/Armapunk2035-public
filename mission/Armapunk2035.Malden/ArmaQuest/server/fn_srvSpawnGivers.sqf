// SPDX-License-Identifier: MIT
/*
    server/fn_srvSpawnGivers.sqf   —   aq_fnc_srvSpawnGivers

    Purpose: put each giver's object in the world, at its marker, and publish it
    under a name every client can find.

    WHY THIS EXISTS
    A giver is config, not code, and the whole point of that is that a mission
    author writes five lines and gets a person to talk to. Something has to turn
    those five lines into an object, and it has to be the server: an object
    spawned per client is one object per client standing in the same spot, and
    an object spawned on a client is not there for anybody else.

    The publish is the other half. The client attaches the interaction driver
    (see fn_postInit), so the client needs to know WHICH object belongs to which
    giver id. Searching the marker's radius for "something that looks like a
    giver" would attach the action to whatever the mission happened to place
    nearby; a named public variable per giver cannot be ambiguous.

    WHAT IT DOES
      For every class in AQ_Givers that declares both `object` and `marker`:
      spawns the class at the marker's position, makes it stand still and stop
      being a combatant, and publishes it as `aq_giverObj_<giverId>`.

      Idempotent: a giver that already has a live published object is left
      alone, so calling this again after a mission event does not produce a
      second clerk behind the first.

      A giver with no `object` is skipped, not failed: attaching the driver to
      something the mission already placed is a supported install, and in that
      case the host calls the driver against its own object.

    Usage:  [] call aq_fnc_srvSpawnGivers;      // from aq_fnc_srvInit
*/

if (!isServer) exitWith {
    diag_log text "[AQ] srvSpawnGivers called off the server; refused.";
    0
};

if (isNil "aq_idxGiver") exitWith {
    diag_log text "[AQ] srvSpawnGivers: no giver index; aq_fnc_preInit did not run on this machine.";
    0
};

private _spawned = 0;

{
    private _gid = _x;
    private _cfg = aq_idxGiver getOrDefault [_gid, configNull];
    if !(isNull _cfg) then {

        private _class  = if (isText (_cfg >> "object")) then { getText (_cfg >> "object") } else { "" };
        private _marker = if (isText (_cfg >> "marker")) then { getText (_cfg >> "marker") } else { "" };
        private _varName = format ["aq_giverObj_%1", _gid];
        private _existing = missionNamespace getVariable [_varName, objNull];

        switch (true) do {

            case (_class isEqualTo ""): { /* the mission supplies its own object */ };

            case (!isNull _existing): { /* already standing */ };

            case (_marker isEqualTo ""): {
                diag_log text format ["[AQ] srvSpawnGivers: giver '%1' declares object '%2' but no marker, so there is nowhere to put it.", _gid, _class];
            };

            default {
                private _pos = getMarkerPos _marker;
                // A marker that does not exist reads as the map origin, and a
                // giver in the corner of the world is worse than no giver:
                // nothing about it looks wrong from the config side.
                if (_pos isEqualTo [0,0,0]) then {
                    diag_log text format ["[AQ] srvSpawnGivers: giver '%1' names marker '%2', which does not exist on this map; nothing spawned.", _gid, _marker];
                } else {
                    private _obj = objNull;
                    private _grp = grpNull;
                    // UNVERIFIED: `isKindOf ["Man", configFile >> "CfgVehicles"]`
                    // separates a person from a prop, and a prop spawns with
                    // createVehicle while a person needs a group and createUnit.
                    // The shipped demo uses one of each (C_man_polo_1_F and
                    // Land_MapBoard_F). Confirm both givers appear in game; a
                    // null result is reported below rather than assumed away.
                    if (_class isKindOf ["Man", configFile >> "CfgVehicles"]) then {
                        _grp = createGroup [civilian, true];
                        _obj = _grp createUnit [_class, _pos, [], 0, "CAN_COLLIDE"];
                        if !(isNull _obj) then {
                            _obj setDir (markerDir _marker);
                            _obj setPosATL _pos;
                            _obj disableAI "ALL";
                            _obj allowDamage false;
                            _obj setBehaviour "CARELESS";
                            _obj setVariable ["aq_giver", _gid, true];
                        };
                    } else {
                        _obj = createVehicle [_class, _pos, [], 0, "CAN_COLLIDE"];
                        if !(isNull _obj) then {
                            _obj setDir (markerDir _marker);
                            _obj setPosATL _pos;
                            _obj enableSimulationGlobal false;
                            _obj setVariable ["aq_giver", _gid, true];
                        };
                    };

                    if (isNull _obj) then {
                        if !(isNull _grp) then { deleteGroup _grp; };
                        diag_log text format ["[AQ] srvSpawnGivers: giver '%1' could not spawn '%2' at '%3'; is it a CfgVehicles class?", _gid, _class, _marker];
                    } else {
                        // Published, not broadcast as an event: a client that
                        // joins later reads the same variable and arms the same
                        // giver without anyone having to replay anything.
                        missionNamespace setVariable [_varName, _obj, true];
                        _spawned = _spawned + 1;
                    };
                };
            };
        };
    };
} forEach (keys aq_idxGiver);

diag_log text format ["[AQ] srvSpawnGivers: %1 giver object(s) spawned and published.", _spawned];
_spawned
