/*
    fn_learnTalent.sqf -- learn or unlearn one talent. A TOGGLE, not a one-way buy.

    Re-plumbed 2026-08-11 so the web deck can drive it. The talent id used to come
    only from the tree dialog's listbox (lbData 123001), which meant exactly one
    caller could ever use it. It now takes an optional id and an optional
    pre-answered confirmation:

        ["standard"] spawn AP_fnc_learnTalent;             // dialog -- unchanged
        ["standard", 42, true] call AP_fnc_learnTalent;    // deck -> returns bool

    With an explicit id nothing in the path suspends -- the only suspension was the
    unlearn confirm, and a direct caller has already answered it -- so that form
    runs inline and returns whether it actually mutated anything. The dialog form
    still spawns and still returns nothing useful.

    PERSISTENCE IS THE CALLER'S JOB, and always was. This function does not save.
    The tree dialog syncs on close: fn_talentMenu waits for display 123000 to go
    away, compares against a cached copy, then calls ClupdatePartial 4. A caller
    with no dialog has to do that itself or the talent is gone on relog.
*/
params [["_type", "", [""]], ["_idIn", -1, [0]], ["_confirmed", false, [false]]];
if (_type isEqualTo "") exitWith { false };

private _body = {
    params ["_type", "_idIn", "_confirmed"];
    disableSerialization;
    private _talentID = if (_idIn >= 0) then { _idIn } else { parseNumber (lbData [123001, lbCurSel 123001]) };
    private _exit = false;
    if (AP_effSide isEqualTo civilian) then {
        if (_type isEqualTo "gang" && !(AP_gang_data isEqualTo[]) && {(AP_gang_data select 2) > 2
        }) exitWith {["You're not high enough rank to edit gang talents!", "basic"] spawn AP_fnc_handleMessage;
            _exit = true;};};
    if (_exit) exitWith {false}; (switch (_type) do {case "standard": {[AP_side_talents, ["getRowByID", _talentID] call AP_fnc_talentCfg]
            }; case "gang": {[AP_gang_talents, ["getRowByID", "gang", _talentID] call AP_fnc_prestigeCfg]}
    }) params["_talents", "_talentRow"];
    if (isNil "_talentRow" || {_talentRow isEqualTo []}) exitWith {false};
    _talentRow params["_talentID", "_side", "_req", "_depth", "_title", "_description"];
    private _result = if (_talentID in _talents) then {if (_type isEqualTo "standard") then {
            private _child = ["getChild", _talentID] call AP_fnc_talentCfg;
            if !(_child isEqualTo[]) exitWith {
                [format["You can't unlearn this talent as it has a child talent, %1, which will need to be unlearned first.", _child select 4], "basic"] spawn AP_fnc_handleMessage;
                false
            };
            private _action = true;
            if (!_confirmed) then {
                _action = [format["If you proceed you will unlearn the talent %1 for a cost of $%2!", _title, [(call AP_respec_fee)] call AP_fnc_numberText], "Unlearn Talent", "Yes", "No"] call BIS_fnc_guiMessage;
            };
            if !(_action) exitWith {false};
            if (AP_atmcash < (call AP_respec_fee)) exitWith {
                ["You don't have enough money in your bank to unlearn this talent.", "basic"] spawn AP_fnc_handleMessage; false};
            AP_side_talents deleteAt(AP_side_talents findIf {_x isEqualTo _talentID});
            AP_atmcash = AP_atmcash - (call AP_respec_fee);
            AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
            [format["You have unlearned the talent %1.", _title], "basic"] spawn AP_fnc_handleMessage;
            true} else {
            private _child = ["getChild", "gang", _talentID] call AP_fnc_prestigeCfg;
            if !(_child isEqualTo[]) exitWith {
                [format["You can't unlearn this talent as it has a child talent, %1, which will need to be unlearned first.", _child select 4], "basic"] spawn AP_fnc_handleMessage;
                false
            };
            AP_gang_talents deleteAt(AP_gang_talents findIf {_x isEqualTo _talentID});
            [format["You have unlearned the gang talent %1.", _title], "basic"] spawn AP_fnc_handleMessage;
            true};} else {
        if (_type isEqualTo "standard") then {if (_talentID isEqualTo 8 && license_civ_rebel && _type isEqualTo "standard") exitWith {
                ["You must first get rid of your Rebel Training to become a Master Bounty Hunter.", "basic"] spawn AP_fnc_handleMessage;
                false};
            private _max = AP_currentTalents;
            private _free = _max - count _talents;
            if (_free < 1) exitWith {["You don't have an available talent point to spend!", "basic"] spawn AP_fnc_handleMessage; false};
            if (_req > 0 && !(_req in _talents)) exitWith {
                ["This talent requires another talent that you don't have!", "basic"] spawn AP_fnc_handleMessage; false};
            _talents pushBack _talentID;
            [format["You have learned the talent %1.", _title], "basic"] spawn AP_fnc_handleMessage;
            systemChat format["You have learned the talent %1.", _title];
            ["action", "learntalent", 1] call AP_fnc_handleQuest;   // owner 2026-07-11: Parole Papers step 4 (+ future quests)
            true
        } else {private _max = AP_currentGangTalents;
            private _free = _max - count _talents;
            if (_free < 1) exitWith {["You don't have an available talent point to spend!", "basic"] spawn AP_fnc_handleMessage; false};
            if (_req > 0 && !(_req in _talents)) exitWith {
                ["This talent requires another talent that you don't have!", "basic"] spawn AP_fnc_handleMessage; false};
            _talents pushBack _talentID;
            [format["You have learned the talent %1.", _title], "basic"] spawn AP_fnc_handleMessage;
            systemChat format["You have learned the talent %1.", _title]; true};};
    // The tree dialog owns this repaint. Guarding on the display keeps the deck
    // path from calling into a dialog that was never opened.
    if (!isNull (findDisplay 123000)) then { [_type] call AP_fnc_populateTalentTree; };
    _result
};

// Direct callers need an answer; the dialog does not and must not block on the
// unlearn confirm, so it keeps the spawn it has always had.
if (_idIn >= 0) exitWith { [_type, _idIn, _confirmed] call _body };
[_type, -1, false] spawn _body;
true
