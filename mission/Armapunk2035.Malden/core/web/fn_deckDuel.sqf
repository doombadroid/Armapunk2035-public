/*
    AP_fnc_deckDuel -- the DUEL ARENA card (approved mock deck-duel).

    Invite is the native promptInviteDueler block ported minus its listbox and
    guiMessage (the page arms the wager): the same 70s invite cooldown, the
    arena-busy gate, the $50k-$999,999 wager band, the half-stake escrow on
    acceptance with its -BANKTRANSFER- log, and the same SRV_duelArenaData
    publicVariable protocol. ACCEPT delegates to the untouched native mode.

    ["data"] / ["invite", uid, wager] / ["accept"]
*/
params [["_verb", "", [""]], ["_a", "", [""]], ["_b", 0, [0]]];

private _no  = { params ["_m"]; createHashMapFromArray [["ok", false], ["msg", _m]] };
private _yes = { params ["_m"]; createHashMapFromArray [["ok", true],  ["msg", _m]] };

switch (toLower _verb) do {

case "data": {
    private _cool = (SRV_duelArenaData select 1) != -1800 && {(time - (SRV_duelArenaData select 1)) < 70};
    createHashMapFromArray [
        ["busy", SRV_duelArenaData select 0],
        ["cooldown", _cool],
        ["invitedMe", (SRV_duelArenaData select 3) isEqualTo (getPlayerUID player) && _cool && !(SRV_duelArenaData select 0)],
        ["wager", SRV_duelArenaData select 4],
        ["players", ((allPlayers select {
            !(isNull _x) && side _x == civilian && alive _x
            && !(_x getVariable ["AP_arrested", false]) && !(_x getVariable ["AP_restrained", false])
        }) - [player]) apply { createHashMapFromArray [
            ["uid", getPlayerUID _x], ["name", [name _x] call AP_fnc_cleanName] ] }],
        ["bank", AP_atmcash]
    ]
};

case "invite": {
    private _val = _b;
    if ((SRV_duelArenaData select 1) != -1800 && {(time - (SRV_duelArenaData select 1)) < 70}) exitWith {
        ["Someone already sent an invite in the last 70 seconds."] call _no };
    if (SRV_duelArenaData select 0) exitWith { ["The arena is in use -- wait your turn."] call _no };
    if (_val <= 49999) exitWith { ["The wager must be over $49,999."] call _no };
    if (_val >= 1000000) exitWith { ["The wager must be under $1,000,000."] call _no };
    if (AP_atmcash < (_val / 2)) exitWith { ["You cannot cover your half of that wager."] call _no };
    private _civ = allPlayers select { side _x == civilian };
    private _unit = _civ param [_civ findIf { (getPlayerUID _x) isEqualTo _a }, objNull];
    if (isNull _unit || {_unit isEqualTo player}) exitWith { ["Pick an opponent."] call _no };

    [_unit, _val] spawn {
        params ["_unit", "_val"];
        SRV_duelArenaData set [1, time];
        SRV_duelArenaData set [2, getPlayerUID player];
        SRV_duelArenaData set [3, getPlayerUID _unit];
        SRV_duelArenaData set [4, _val];
        SRV_duelArenaData set [5, [0, 0]];
        SRV_duelArenaData set [6, false];
        publicVariable "SRV_duelArenaData";
        [format ["You have been invited for a duel by %1 for a total of %2.<br/><br/>You can accept this duel by going to the courthouse and interacting with the NPC (you have one minute). All your gear will be given back once the duel has been accepted (Y inventory will not be restored)",
            format ["%1", [name player] call AP_fnc_cleanName], _val], "basic"] remoteExec ["AP_fnc_handleMessage", _unit];
        ["Invite sent -- awaiting acceptance. All gear returns when the duel starts (Y inventory is not restored).", "basic"] spawn AP_fnc_handleMessage;
        private _inviteSent = SRV_duelArenaData select 1;
        waitUntil { uiSleep 1; time - _inviteSent > 65 || SRV_duelArenaData select 0 };
        if (SRV_duelArenaData select 0 && SRV_duelArenaData select 2 == getPlayerUID player) then {
            AP_atmcash = AP_atmcash - ((SRV_duelArenaData select 4) / 2);
            AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
            [1] call AP_fnc_ClupdatePartial;
            [["-BANKTRANSFER-", player, profileName, format ["the duel arena has taken %1 due to the start of their duel",
                ((SRV_duelArenaData select 4) / 2)]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
            AP_inEvent = true;
            [format ["Invite accepted -- transferring to the arena. $%1 is held until the fight ends.", (_val / 2)], "basic"] spawn AP_fnc_handleMessage;
            [[], "APS_fnc_duelArenaSystemSRV", 2] call AP_fnc_MP;
        } else {
            ["Your invite has expired.", "basic"] spawn AP_fnc_handleMessage;
        };
    };
    ["Invite sent."] call _yes
};

case "accept": {
    [] spawn { closeDialog 0; uiSleep 0.15; ["acceptInvite"] spawn AP_fnc_duelArenaSystem; };
    ["Accepting -- gear check runs natively."] call _yes
};

default { ["unknown duel verb"] call _no };
};
