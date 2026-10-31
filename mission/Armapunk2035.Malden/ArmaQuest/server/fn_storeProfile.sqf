// SPDX-License-Identifier: MIT
/*
    server/fn_storeProfile.sqf   —   aq_fnc_storeProfile

    Purpose: store driver backed by profileNamespace. The default, and the one
    that makes the system work with no database and no host setup at all.

    WHY THIS EXISTS
    A quest system whose only persistence option is a database cannot be tried.
    The first-run experience has to be "drop it in and play", or the design never
    gets exercised and the bugs are found by the first host who wires SQL. This
    driver is the zero-setup path.

    ***  READ THIS BEFORE USING IT ON A PERSISTENT SERVER  ***
    profileNamespace is a *profile* namespace: on a dedicated server it belongs
    to the server's own profile, and on a hosted/coop session it belongs to the
    host's. That has three consequences a host must accept knowingly:
      - state lives in a file on the machine that ran the mission, so moving or
        reinstalling the server loses every quest ever completed;
      - a second server instance has its own separate copy, so a player's
        progress depends on which box they joined;
      - it is written by the engine on its own schedule plus saveProfileNamespace,
        so an unclean process kill can lose the last window of writes.
    For a persistent server use the extDB driver. This one is for coop, for
    single-box play, and for development.

    WHAT IT DOES
      Implements the four driver verbs against profileNamespace, one variable per
      record, namespaced so it cannot collide with a host's own profile data.
      Records are opaque JSON strings — the driver never inspects them.

    Usage:  ["save", ["player:76561198000000000", _json]] call aq_fnc_storeProfile;
*/

params [["_verb", "", [""]], ["_args", [], [[]]]];

#define AQ_PROFILE_PREFIX "aq_store_"

if (!isServer) exitWith {
    diag_log text "[AQ] storeProfile called off the server; refused.";
    false
};

switch (toLower _verb) do {

    case "init": {
        // Nothing to open. The one thing worth reporting is which profile is
        // about to receive the writes, because "my progress vanished" is almost
        // always "a different profile than expected".
        diag_log text format ["[AQ] storeProfile: using profileNamespace on this machine (profile '%1'). Not suitable for a persistent multi-box server.",
            profileName];
        true
    };

    case "load": {
        _args params [["_key", "", [""]]];
        if (_key isEqualTo "") exitWith {
            diag_log text "[AQ] storeProfile load: empty key.";
            ""
        };
        private _v = profileNamespace getVariable [AQ_PROFILE_PREFIX + _key, ""];
        if !(_v isEqualType "") exitWith {
            diag_log text format ["[AQ] storeProfile load: '%1' held a %2, expected a string. Treating as absent.", _key, typeName _v];
            ""
        };
        _v
    };

    case "save": {
        _args params [["_key", "", [""]], ["_json", "", [""]]];
        if (_key isEqualTo "") exitWith {
            diag_log text "[AQ] storeProfile save: empty key; nothing written.";
            false
        };
        profileNamespace setVariable [AQ_PROFILE_PREFIX + _key, _json];
        true
    };

    case "flush": {
        // The engine also writes the profile at its own moments; this makes the
        // write-behind interval mean what it says rather than "eventually".
        saveProfileNamespace;
        true
    };

    default {
        diag_log text format ["[AQ] storeProfile: unknown verb '%1'.", _verb];
        false
    };
};
