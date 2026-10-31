/*
    AP_fnc_deckSummon -- the deck's SUMMON VEHICLE app.

    ["data"]   the cached AP_summonState (state/msg/dist/eta/cooldown/info); also asks the
               server for fresh info, which arrives on the `summon` channel a moment later
    ["go"]     summon -- the server decides and answers on the channel
*/
params [["_verb", "", [""]]];
switch (toLower _verb) do {
    case "data": {
        ["info"] remoteExec ["APS_fnc_summonSRV", 2];
        missionNamespace getVariable ["AP_summonState", createHashMapFromArray [["state", "idle"], ["msg", ""], ["dist", 0], ["eta", 0], ["cooldown", 0], ["info", createHashMapFromArray [["none", true]]]]]
    };
    case "go": {
        if (!isNull objectParent player) exitWith { createHashMapFromArray [["ok", false], ["msg", "get out of your vehicle first"]] };
        ["go"] remoteExec ["APS_fnc_summonSRV", 2];
        createHashMapFromArray [["ok", true], ["msg", "summoning"]]
    };
    default { createHashMapFromArray [["ok", false], ["msg", "unknown verb"]] };
};
