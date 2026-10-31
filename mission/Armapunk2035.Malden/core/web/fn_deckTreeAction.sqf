/*
    fn_deckTreeAction.sqf -- toggle one node in any of the six point-spend trees,
    from the web deck.

    ONE VERB, because the native functions are toggles: calling fn_learnTalent or
    fn_learnPrestige on a node you already own unlearns it, with that tree's own
    cost and its own child-dependency check. The page decides what to LABEL the
    button; it does not decide what the call does.

    PERSISTENCE IS THE POINT OF THIS FUNCTION. Neither native function saves --
    the tree dialogs sync on close, by waiting for display 123000 to disappear
    and then calling ClupdatePartial. The deck never opens that dialog, so
    without the sync below a talent bought here is gone at the next relog. The
    numbers are not interchangeable: 4 standard / 14 bh / 16 cop / 22 rebel /
    23 medic, and gang talents do not use ClupdatePartial at all -- they are
    broadcast to online members and written by APS_fnc_updateGangTalents.

    Usage:  ["bh", 11] call AP_fnc_deckTreeAction;   -> { ok, msg }
*/

params [["_cat", "", [""]], ["_id", -1, [0]]];

private _reply = {
    params ["_ok", "_msg"];
    createHashMapFromArray [["ok", _ok], ["msg", _msg]]
};

if !(_cat in ["standard", "gang", "bh", "cop", "rebel", "medic"]) exitWith {
    [false, format ["unknown tree: %1", _cat]] call _reply
};
if (_id < 0) exitWith { [false, "no node selected"] call _reply };

// The gang tree is rank-gated before anything else happens, exactly as
// fn_talentMenu gates opening it. fn_learnTalent checks this too; catching it
// here means the page gets a reason instead of a bare refusal.
if (_cat isEqualTo "gang" && { AP_gang_data isEqualTo [] }) exitWith {
    [false, "you are not in a gang"] call _reply
};
if (_cat isEqualTo "gang" && { (AP_gang_data param [2, 9]) > 2 }) exitWith {
    [false, "your gang rank cannot edit perks"] call _reply
};

// Straight through the native function -- same checks, no second copy of the
// prerequisite, cap, currency and licence rules. `true` is the pre-answered
// confirm: the page asks in its own UI, so the native message box must not fire
// on top of the browser control.
private _ok = if (_cat in ["standard", "gang"]) then {
    [_cat, _id, true] call AP_fnc_learnTalent
} else {
    [_cat, _id, true] call AP_fnc_learnPrestige
};

if !(_ok isEqualType false) then { _ok = false };

if (_ok) then {
    switch (_cat) do {
        case "standard": { [4]  call AP_fnc_ClupdatePartial; };
        case "bh":       { [14] call AP_fnc_ClupdatePartial; };
        case "cop":      { [16] call AP_fnc_ClupdatePartial; };
        case "rebel":    { [22] call AP_fnc_ClupdatePartial; };
        case "medic":    { [23] call AP_fnc_ClupdatePartial; };
        case "gang": {
            // mirrors fn_talentMenu's close path: tell the online members first,
            // then let the server write the gang row
            private _gangID = AP_gang_data select 0;
            private _online = (allPlayers - [player]) select {
                !((_x getVariable ["gang_data", []]) isEqualTo []) &&
                { ((_x getVariable "gang_data") select 0) isEqualTo _gangID }
            };
            if !(_online isEqualTo []) then {
                [["AP_gang_talents", AP_gang_talents], "AP_fnc_netSetVar", _online] call AP_fnc_MP;
            };
            [[[AP_gang_exp, AP_gang_talents], _gangID], "APS_fnc_updateGangTalents", 2] call AP_fnc_MP;
        };
    };
};

// The native function has already shown the player why it refused, via
// handleMessage. Repeating the reason here would double every failure.
[_ok, if (_ok) then { "" } else { "refused" }] call _reply
