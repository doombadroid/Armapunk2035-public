/*
    AP_fnc_deckGang -- gang COMMAND verbs for the deck (approved mocks
    deck-gang-a + the deck-gang-c war room).

    The deck's My Gang view already reads the roster and does rename / invite /
    promote / demote / kick. This adds what still lived only in dialog 9620:
    the bank, leave/disband, the tag, leadership transfer, and the war room.
    Bank amounts go through the parametrized fn_gangDeposit / fn_gangWithdraw /
    fn_gangBankTransfer -- one copy of every guard. The rest are ports of the
    single-digit-line natives minus their listbox reads; every destructive verb
    is arm-then-commit on the page.

    ["bank"]                    spawned funds fetch -> gang channel push
    ["dep"|"wd", amt] ["depall"]
    ["xfer", amt, uid, name]
    ["leave"] ["disband"]
    ["tag", tag]
    ["lead", uid, name] ["owner", uid, name]
    ["war", "challenge"|"accept"|"surrender", gangId]
*/
params [["_verb", "", [""]], ["_a", 0, [0, ""]], ["_b", "", [""]], ["_c", "", [""]]];

private _no  = { params ["_m"]; createHashMapFromArray [["ok", false], ["msg", _m]] };
private _yes = { params ["_m"]; createHashMapFromArray [["ok", true],  ["msg", _m]] };
if (AP_gang_data isEqualTo []) exitWith { ["You are not in a gang."] call _no };
AP_gang_data params [["_gid", -1, [0]], ["_gname", "", [""]], ["_rank", 5, [0]]];

private _pushGang = {
    private _cc = uiNamespace getVariable ["WEBUI_ctrl", controlNull];
    if (!isNull _cc) then { [_cc, "gang", (["gang"] call AP_fnc_deckData)] call webui_fnc_push; };
};

switch (toLower _verb) do {

case "bank": {
    if !(_rank in [1, 2, 3]) exitWith { ["Only your gang's top ranks can access the bank."] call _no };
    if (!AP_use_atm) exitWith { ["ATM lockout -- you robbed a store."] call _no };
    [] spawn {
        AP_gangfund_ready = false;
        AP_gang_funds = -1;
        [[0, AP_gang_data select 0, player], "APS_fnc_gangBank", false, false] spawn AP_fnc_MP;
        private _t = time + 6;
        waitUntil { uiSleep 0.1; AP_gangfund_ready || time > _t };
        private _cc = uiNamespace getVariable ["WEBUI_ctrl", controlNull];
        if (!isNull _cc) then { [_cc, "gang", (["gang"] call AP_fnc_deckData)] call webui_fnc_push; };
    };
    ["Opening the ledger..."] call _yes
};

case "dep": {
    if !(_rank in [1, 2, 3]) exitWith { ["Top ranks only."] call _no };
    if (AP_gfunds_active) exitWith { ["A transaction is already in progress."] call _no };
    [false, _a] spawn AP_fnc_gangDeposit;
    ["Deposit sent."] call _yes
};
case "depall": {
    if !(_rank in [1, 2, 3]) exitWith { ["Top ranks only."] call _no };
    if (AP_gfunds_active) exitWith { ["A transaction is already in progress."] call _no };
    [true] spawn AP_fnc_gangDeposit;
    ["Deposit sent."] call _yes
};
case "wd": {
    if !(_rank in [1, 2]) exitWith { ["Rank 2 or above to withdraw."] call _no };
    if (AP_gfunds_active) exitWith { ["A transaction is already in progress."] call _no };
    [_a] spawn AP_fnc_gangWithdraw;
    ["Withdrawal sent."] call _yes
};
case "xfer": {
    if !(_rank in [1, 2]) exitWith { ["Rank 2 or above to transfer."] call _no };
    if (AP_gfunds_active) exitWith { ["A transaction is already in progress."] call _no };
    [_a, _b, _c] spawn AP_fnc_gangBankTransfer;
    ["Transfer sent."] call _yes
};

case "leave": {
    [] spawn AP_fnc_gangLeave;
    ["Leaving..."] call _yes
};
case "disband": {
    if !(_rank isEqualTo 1) exitWith { ["Leader only."] call _no };
    [] spawn AP_fnc_gangDisband;
    ["Disband sent."] call _yes
};

case "tag": {
    // fn_setGangTag mode 2 minus the input dialog -- the page's field replaces it
    if !(_rank in [1, 2]) exitWith { ["Rank 2 or above."] call _no };
    private _tag = _b;
    if (_tag isEqualTo "") exitWith { ["Type a tag."] call _no };
    if (count _tag > 4) exitWith { ["Four characters or less."] call _no };
    if (_tag == "MSEC" || _tag == "TT") exitWith { ["This tag is not allowed."] call _no };
    [[_gid, _tag, group player, true], "APS_fnc_setGangTagSRV", 2] spawn AP_fnc_MP;
    [format ["Tag set to [%1].", _tag]] call _yes
};

case "lead": {
    // fn_gangNewLeader minus the listbox and the guiMessage (page armed twice)
    if !(_rank isEqualTo 1) exitWith { ["You are not the leader."] call _no };
    private _playerID = _b;
    if (_playerID isEqualTo (getPlayerUID player)) exitWith { ["You are already the leader."] call _no };
    if (_playerID isEqualTo "") exitWith { ["Pick a member."] call _no };
    [_playerID, _gid, _gname] spawn {
        params ["_playerID", "_gangID", "_gangName"];
        private _onlineMembers = [_gangID] call AP_fnc_getOnlineMembers;
        private _newLeader = playableUnits param [playableUnits findIf { getPlayerUID _x isEqualTo _playerID }, objNull];
        private _group = group player;
        [[player, 2, _gangID, _gangName, player, 2], "APS_fnc_updateGangMem", 2] spawn AP_fnc_MP;
        if (isNull _newLeader) then {
            [[player, 1, _gangID, _gangName, _playerID, 1], "APS_fnc_updateGangMem", false] spawn AP_fnc_MP;
        } else {
            [[player, 2, _gangID, _gangName, _newLeader, 1], "APS_fnc_updateGangMem", false] spawn AP_fnc_MP;
            if (_group getVariable ["gang_id", -64] isEqualTo _gangID) then {
                _group selectLeader _newLeader;
                [[_newLeader, _group], "AP_fnc_clientGangLeader", _onlineMembers] spawn AP_fnc_MP;
            };
        };
    };
    ["Transferring leadership..."] call _yes
};

case "owner": {
    // fn_gangTransferOwner minus the listbox and the guiMessage
    if !(_rank isEqualTo 1) exitWith { ["Leader only."] call _no };
    private _newOwnerPID = _b;
    private _newOwnerName = _c;
    if (_newOwnerPID isEqualTo "") exitWith { ["Pick a member."] call _no };
    [_newOwnerPID, _newOwnerName, _gid] spawn {
        params ["_newOwnerPID", "_newOwnerName", "_gid"];
        private _onlineMembers = [_gid] call AP_fnc_getOnlineMembers;
        private _newOwner = allPlayers param [allPlayers findIf { _newOwnerPID isEqualTo (getPlayerUID _x) }, objNull];
        [[getPlayerUID player, _newOwnerPID], "APS_fnc_transferGangOwnerSRV", 2] spawn AP_fnc_MP;
        if !(isNull (AP_gangBuilding select 0)) then {
            [[AP_gangBuilding select 0, _gid], "AP_fnc_removeGangHouse", _onlineMembers] spawn AP_fnc_MP;
            [[AP_gangBuilding select 0, _gid], "APS_fnc_removeGangHouseSRV", 2] spawn AP_fnc_MP;
        };
        [[], "AP_fnc_gangSetOwner", _newOwner] spawn AP_fnc_MP;
        AP_gang_data set [2, 2];
        [format ["You have transferred gang ownership to %1.", _newOwnerName], "basic"] spawn AP_fnc_handleMessage;
    };
    ["Transferring ownership..."] call _yes
};

case "war": {
    private _enemy = parseNumber _b;
    switch (toLower (format ["%1", _a])) do {
        case "challenge": {
            if (_rank > 3) exitWith { ["You are not of sufficient rank."] call _no };
            if (time < (missionNamespace getVariable ["AP_gang_war_next", 0])) exitWith {
                ["One challenge every 5 minutes."] call _no };
            private _toSend = allPlayers select { (_x getVariable ["gang_data", [-1]] select 0) isEqualTo _enemy };
            if (_toSend isEqualTo []) exitWith { ["No members of that gang are online."] call _no };
            [[player, _gid, _gname], "AP_fnc_warChallenged", _toSend] spawn AP_fnc_MP;
            AP_gang_war_next = time + 300;
            ["War challenge sent to every online member."] call _yes
        };
        case "accept": {
            if !(_enemy in AP_gang_challenges) exitWith { ["No such challenge."] call _no };
            [[_gid, _enemy, true], "APS_fnc_updateWar", 2] spawn AP_fnc_MP;
            ["War accepted."] call _yes
        };
        case "surrender": {
            if !(_enemy in AP_gang_wars) exitWith { ["You are not at war with them."] call _no };
            [[_gid, _enemy, false], "APS_fnc_updateWar", 2] spawn AP_fnc_MP;
            ["War ended."] call _yes
        };
        default { ["unknown war verb"] call _no };
    }
};

// Swear the gang to a fixer, or break with the one it has. Everything that
// decides whether this is allowed -- the rank, the fee, the cooldown, whether the
// current patron is at war this week -- is re-derived server-side in
// APS_fnc_gangAlignSRV from the database and the published war state. Nothing here
// is a gate; the rank test below only spares the player a round trip to be told
// something the page already knows.
//
// The page sends a faction ID ALONE. That is the whole payload, and it is why the
// server had to stop taking a player object in slot 0: identity comes from
// remoteExecutedOwner there, never from anything sent here.
case "faction": {
    if !(_rank isEqualTo 1) exitWith { ["Leader only."] call _no };
    private _fid = _b;
    if (_fid isEqualTo "") exitWith { ["Pick a fixer."] call _no };
    if ((["byId", _fid] call AP_fnc_factionCfg) isEqualTo []) exitWith { ["No such fixer."] call _no };
    [[_fid], "APS_fnc_gangAlignSRV", 2] spawn AP_fnc_MP;
    // Deliberately not "Aligned." -- the server may still refuse for the bank, the
    // cooldown or an active war, and it says so itself on the same channel. Claiming
    // success here would put a lie on screen a second before the truth arrives.
    ["Sent to the fixer..."] call _yes
};

default { ["unknown gang verb"] call _no };
};
