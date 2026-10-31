#include "..\..\macro.h"
/*
    AP_fnc_deckIntake -- the MAXSEC INTAKE terminal (approved mock deck-intake,
    TAL palette). Intake is a form with a bill: suspect card, charge picker
    with counts, and the WARRANT -- an itemised bill -- with two commits:

      ISSUE TICKET  the bill as a fine, through the native ticket-prompt
                    protocol (suspect accepts or refuses on their screen)
      BOOK          every staged charge through APS_fnc_wantedAdd, exactly the
                    native fn_applyCharge tail: the same west broadcast, the
                    same -ADDCHARGE- logs, the 5-count cap per charge, and the
                    id-110 containment charge's CLANKR audit row

    ["data"] / ["book", uid, [[chargeId, n], ...]] / ["ticket", uid, amt]
*/
params [["_verb", "", [""]], ["_a", "", ["", 0]], ["_b", 0, [0, []]]];

private _no  = { params ["_m"]; createHashMapFromArray [["ok", false], ["msg", _m]] };
private _yes = { params ["_m"]; createHashMapFromArray [["ok", true],  ["msg", _m]] };
if !(AP_effSide isEqualTo west) exitWith { ["MaxSec only."] call _no };

private _suspectOf = {
    params ["_uid"];
    allPlayers param [allPlayers findIf {
        ((getPlayerUID _x) isEqualTo _uid) && {!((side _x) isEqualTo west)} }, objNull]
};

switch (toLower _verb) do {

case "data": {
    private _t = missionNamespace getVariable ["AP_deckCtx", objNull];
    if (isNull _t || {!isPlayer _t} || {(side _t) isEqualTo west}) then { _t = objNull; };
    createHashMapFromArray [
        ["suspect", if (isNull _t) then { createHashMap } else { createHashMapFromArray [
            ["uid", getPlayerUID _t],
            ["name", [name _t] call AP_fnc_cleanName],
            ["dist", round (player distance _t)],
            ["cuffed", _t getVariable ["AP_restrained", false]]
        ] }],
        ["charges", (["getManualCharges"] call AP_fnc_wantedChargesConfig) apply {
            _x params ["_id", "_title", "_bounty", "_jail", "_stack"];
            createHashMapFromArray [
                ["id", _id], ["title", _title], ["fine", _bounty],
                ["months", _jail], ["stack", _stack]
            ] }]
    ]
};

case "book": {
    private _uid = _a;
    private _staged = _b;
    if !(_staged isEqualType []) exitWith { ["Nothing staged."] call _no };
    if (_staged isEqualTo []) exitWith { ["Nothing staged."] call _no };
    if (count _staged > 12) exitWith { ["Too many lines on one warrant."] call _no };
    private _unit = [_uid] call _suspectOf;
    if (isNull _unit || {!alive _unit}) exitWith { ["Suspect is gone."] call _no };
    if ((player distance _unit) > 15) exitWith { ["Stand near the suspect."] call _no };
    private _cfg = ["getManualCharges"] call AP_fnc_wantedChargesConfig;
    [_staged, _unit, _cfg] spawn {
        params ["_staged", "_unit", "_cfg"];
        {
            _x params [["_id", -1, [0]], ["_n", 1, [0]]];
            private _row = _cfg param [_cfg findIf { (_x select 0) isEqualTo _id }, []];
            if (_row isNotEqualTo [] && {alive _unit}) then {
                _row params ["_chargeID", "_label", "", "", "_stack"];
                private _count = if (_stack) then { (_n max 1) min 5 } else { 1 };
                [[_chargeID, _unit, _count], "APS_fnc_wantedAdd", 2] spawn AP_fnc_MP;
                [[1, format ["%4 has charged %1 with %2 count(s) of %3",
                    [name _unit] call AP_fnc_cleanName, _count, _label,
                    [profileName] call AP_fnc_cleanName]], "AP_fnc_broadcast", west] spawn AP_fnc_MP;
                [["-ADDCHARGE-", player, profileName, format ["deck-charged %1 (%2) with %3 count(s) of %4.",
                    name _unit, getPlayerUID _unit, _count, _label]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
                if (_chargeID isEqualTo 110) then {
                    [["-MODFLAG-RAPE-", player, profileName, format ["FLAGGED %1 (%2) with the Rape containment charge (x%3) -- needs admin review of footage.",
                        name _unit, getPlayerUID _unit, _count]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
                };
                // the native picker enforced a 0.75s spam gap between charges;
                // a batch honours the same pacing rather than machine-gunning
                // the wanted system
                uiSleep 0.8;
            };
        } forEach _staged;
    };
    [format ["Warrant filed -- %1 line(s).", count _staged]] call _yes
};

case "ticket": {
    private _uid = _a;
    private _val = _b;
    if !(_val isEqualType 0) exitWith { ["Bad amount."] call _no };
    private _unit = [_uid] call _suspectOf;
    if (isNull _unit) exitWith { ["Suspect is gone."] call _no };
    if ((player distance _unit) > 8) exitWith { ["Stand near the suspect."] call _no };
    _val = round _val;
    if (_val <= 0) exitWith { ["The ticket must be at least $1."] call _no };
    if (_val > 1500000) exitWith { ["Tickets cap at $1,500,000."] call _no };
    [[0, format ["%1 gave a ticket of $%2 to %3", profileName, [_val] call AP_fnc_numberText, name _unit]], "AP_fnc_broadcast", -2] spawn AP_fnc_MP;
    [["-TICKET-", player, profileName, format ["deck-ticketed $%1 to %2 (%3) at POS: %4",
        [_val] call AP_fnc_numberText, name _unit, getPlayerUID _unit, getPosATL player]], "APS_fnc_logIt", 2, false, false] spawn AP_fnc_MP;
    [[player, _val], "AP_fnc_ticketPrompt", _unit, false, false] spawn AP_fnc_MP;
    ["action", "giveticketvalue", _val] call AP_fnc_handleQuest;
    ["action", "ticket", 1] call AP_fnc_handleQuest;
    ["ticketsgiven", 1] call AP_fnc_statArrUpdate;
    ["ticketsgivenamount", _val] call AP_fnc_statArrUpdate;
    [format ["Ticket for $%1 issued -- awaiting their answer.", [_val] call AP_fnc_numberText]] call _yes
};

default { ["unknown intake verb"] call _no };
};
