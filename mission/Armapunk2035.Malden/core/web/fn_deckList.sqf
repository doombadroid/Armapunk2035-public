/*
    fn_deckList.sqf — the eight read-only list apps, behind one payload shape.

    Wanted, Gangs Online, Licenses, Captures, Group, Achieve, Titles and Quests are
    all the same screen: a filtered list of rows, each with a state, a label, a
    chip and a right-hand figure. This is the design brief's "pattern A" and it is
    the row grammar already built for the gang roster and the keychain — so the
    page renders all eight from one view and only the payload differs.

    ALL EIGHT ARE CLIENT-SIDE. Not one of them needs a server round trip: the
    wanted list, the gang roster, licences, achievements and quests all live in
    mission-namespace arrays the client already holds, and Gangs Online is built
    by grouping allPlayers on the public gang_data variable. Nothing here pushes,
    nothing waits.

    Every row is READ ONLY. These apps report; the actions that would change any
    of it (pardon, bounty, capture, quest turn-in) live in their own native
    dialogs and are deliberately not reachable from here.

    Usage:  private _payload = ["licenses"] call AP_fnc_deckList;
*/

params [["_kind", "", [""]]];

private _rows  = [];
private _tools = [];        // optional form controls above the list (create, set password...)
private _title = "";
private _crumb = "";
private _empty = "NOTHING HERE";

// row: state drives the dot colour -- "on" acid, "live" cyan, "off" grey, "bad" red
private _row = {
    params [["_label", ""], ["_chip", ""], ["_meta", ""], ["_state", "off"], ["_sub", ""],
            ["_act", ""], ["_actLabel", ""], ["_actId", ""],
            ["_act2", ""], ["_actLabel2", ""], ["_actId2", ""], ["_argField", ""]];
    createHashMapFromArray [
        ["label", _label], ["chip", _chip], ["meta", _meta], ["state", _state], ["sub", _sub],
        // up to two optional per-row actions. Most lists are pure reports and
        // leave them empty; a squad row needs both promote and kick.
        ["act", _act], ["actLabel", _actLabel], ["actId", _actId],
        ["act2", _act2], ["actLabel2", _actLabel2], ["actId2", _actId2],
        // optional: the id of a tools-bar input whose value rides along with the
        // action. JOIN needs the password box; nothing else does yet.
        ["argField", _argField]
    ]
};

switch (toLower _kind) do {

// ---------------------------------------------------------------- wanted ----
// AP_bounty_list rows are [uid, name, expiry, markerCentre]. The list is a
// client array kept in step by the bounty system; a negative third field is the
// stock seed, so it is shown as an age rather than a countdown.
case "wanted": {
    _title = "WANTED"; _crumb = "// BOUNTIES"; _empty = "NO ACTIVE BOUNTIES";
    private _list = missionNamespace getVariable ["AP_bounty_list", []];
    {
        _x params [["_uid", ""], ["_nm", ""], ["_t", 0], ["_pos", []]];
        private _online = (allPlayers findIf { (getPlayerUID _x) isEqualTo _uid }) > -1;
        _rows pushBack ([_nm, if (_online) then { "ONLINE" } else { "OFFLINE" },
            if (_pos isEqualType [] && { count _pos > 1 }) then { format ["%1 m", round (player distance _pos)] } else { "" },
            if (_online) then { "bad" } else { "off" }] call _row);
    } forEach _list;
};

// ----------------------------------------------------------- gangs online ----
// Pure client-side, exactly as fn_gangListMenu does it: players publish gang_data
// with setVariable, so the roster is a group-by over allPlayers. Squads come off
// `group _x` the same way.
case "gangs": {
    _title = "GANGS ONLINE"; _crumb = "// ROSTER"; _empty = "NOBODY IS BANDED UP";
    private _seen = createHashMap;
    {
        private _gd = _x getVariable ["gang_data", []];
        private _gid = _gd param [0, -1];
        if (_gid isNotEqualTo -1 && { _gid isNotEqualTo 0 }) then {
            private _nm = _gd param [1, format ["Gang %1", _gid]];
            private _cur = _seen getOrDefault [_nm, 0];
            _seen set [_nm, _cur + 1];
        };
    } forEach allPlayers;
    private _mine = (AP_gang_data param [1, ""]);
    {
        _rows pushBack ([_x, if (_x isEqualTo _mine) then { "YOURS" } else { "" },
            format ["%1 ONLINE", _seen get _x],
            if (_x isEqualTo _mine) then { "on" } else { "live" }] call _row);
    } forEach (keys _seen);
};

// -------------------------------------------------------------- licenses ----
// AP_licenses is [[variableName, side], ...] and the display name comes from
// licenseCfg. The native app lists only what you HOLD; this lists everything for
// your side with a state, because "what am I missing" is the actual question.
case "housing": {
    _title = "HOUSE TAXES"; _crumb = "// PROPERTY"; _empty = "YOU OWN NO PROPERTY";
    // the native tax menu's resolve loop, row for row (fn_manageHouseTax
    // taxMenuPopulate): houseTypes-filtered nearest resolve so a replaced-shed
    // spot does not grab the hidden derelict underneath
    private _idx = 0;
    {
        private _pos = parseSimpleArray (_x select 0);
        private _houses = nearestObjects [_pos, ["House"], 18, true];
        if !(_houses isEqualTo []) then {
            private _h = (_houses select { (typeOf _x) in AP_houseTypes }) param [0, (_houses select 0)];
            if ((_h isKindOf "House_F") || { (typeOf _h) in AP_houseTypes }) then {
                private _nm = getText (configFile >> "CfgVehicles" >> (typeOf _h) >> "displayName");
                private _dist = round (player distance _h);
                private _taxData = _h getVariable ["AP_house_tax", []];
                private _due = ["calculateTax", [_h]] call AP_fnc_manageHouseTax;
                private _paid = _taxData param [1, false];
                _rows pushBack ([
                    format ["%1", _nm],
                    format ["%1m", _dist],
                    if (_due > 0) then { format ["$%1", [_due] call AP_fnc_numberText] } else { "PAID" },
                    if (_due > 0) then { "warn" } else { "on" },
                    "",
                    if (_due > 0) then { "housePay" } else { "" },
                    if (_due > 0) then { "PAY TAX" } else { "" },
                    str _idx
                ] call _row);
            };
        };
        _idx = _idx + 1;
    } forEach AP_houses;
    if (({ (_x get "act") isEqualTo "housePay" } count _rows) > 1) then {
        _rows = [([
            "ALL PROPERTIES", "", "", "off", "",
            "housePayAll", "PAY EVERY TAX", "all"
        ] call _row)] + _rows;
    };
};

case "licenses": {
    _title = "LICENCES"; _crumb = "// PERMITS"; _empty = "NO LICENCES FOR YOUR SIDE";
    private _side = switch (AP_effSide) do {
        case west: { "cop" }; case civilian: { "civ" }; case independent: { "med" }; default { "" }
    };
    {
        _x params [["_var", ""], ["_s", ""]];
        if (_s isEqualTo _side) then {
            private _nm = ["varToStr", _var] call AP_fnc_licenseCfg;
            if (_nm isNotEqualTo "") then {
                private _has = missionNamespace getVariable [_var, false];
                _rows pushBack ([_nm, if (_has) then { "HELD" } else { "" }, "",
                    if (_has) then { "on" } else { "off" }] call _row);
            };
        };
    } forEach (missionNamespace getVariable ["AP_licenses", []]);
};

// -------------------------------------------------------------- captures ----
// The roster is AP_fnc_cartelCfg -- one table read by client and server -- with
// rows [id, displayName, flagVar, markerName, position, legacyFlagVar, payout,
// perk]. The flag OBJECT lives in the variable named at index 2, and carries
// AP_capData = [gangID, gangName, progress] plus a cooldown stamp.
//
// A cartel whose flag has not streamed in yet is still listed, greyed, rather
// than dropped: "the map has six cartels and I cannot see two of them" is useful,
// a short list that silently varies is not.
case "captures": {
    _title = "CAPTURES"; _crumb = "// CARTELS"; _empty = "NO CARTELS CONFIGURED";
    private _myGang = AP_gang_data param [0, -1];
    {
        _x params [["_id", ""], ["_nm", ""], ["_flagVar", ""], ["_mk", ""], ["_pos", []], "", ["_payout", 0], ""];
        private _flag = missionNamespace getVariable [_flagVar, objNull];
        if (isNull _flag) then {
            _rows pushBack ([_nm, "OUT OF RANGE", "", "off",
                "flag not streamed in from here"] call _row);
        } else {
            private _cap = _flag getVariable ["AP_capData", [0, "Neutral", 0]];
            _cap params [["_gid", 0], ["_gnm", "Neutral"], ["_prog", 0]];
            private _cool = serverTime < (_flag getVariable ["AP_capture_cooldown", serverTime - 100]);
            private _mine = (_gid isEqualTo _myGang) && { _gid isNotEqualTo 0 };
            _rows pushBack ([
                _nm,
                if (_cool) then { "COOLDOWN" } else { _gnm },
                format ["%1%2", round (_prog * 100), "%"],
                if (_mine) then { "on" } else { if (_gid isEqualTo 0) then { "off" } else { "bad" } },
                format ["%1 m away", round (player distance _flag)]
            ] call _row);
        };
    } forEach ([] call AP_fnc_cartelCfg);
};

// ----------------------------------------------------------------- group ----
case "group": {
    _title = "GROUP"; _crumb = "// SQUAD"; _empty = "NO SQUAD -- MAKE ONE ABOVE";
    // MEMBERSHIP IS AP_my_gang, not a headcount. fn_createGroup sets it, and a
    // squad you just made and are alone in is still a squad -- counting units and
    // calling one player "not a group" hid it completely.
    private _mine = missionNamespace getVariable ["AP_my_gang", grpNull];
    private _in   = !isNull _mine;
    private _g      = if (_in) then { _mine } else { group player };
    private _leader = leader _g;
    private _boss   = _leader isEqualTo player;
    private _alone  = !_in;

    // name and ownership come from the published list, whose rows are
    // [name, group, locked, ownerID, password]
    private _gname = "";
    if (_in) then {
        private _row = (missionNamespace getVariable ["randomized_life_group_list", []]) select { (_x param [1, grpNull]) isEqualTo _mine };
        if !(_row isEqualTo []) then {
            _gname = (_row select 0) param [0, ""];
            _boss  = ((_row select 0) param [3, ""]) isEqualTo (getPlayerUID player);
        };
        if (_gname isNotEqualTo "") then { _crumb = format ["// %1", toUpper _gname] };
    };

    // A squad list with no way to start one is a dead end, which is what shipped.
    // Both actions go through the native functions, so the passive-mode block, the
    // 30s create cooldown, the 120s password cooldown and the character rules all
    // still apply.
    if (_alone) then {
        // Creating needs BOTH -- fn_createGroup refuses without a password, and it
        // reads that from its own control rather than the one setGroupPass uses.
        _tools pushBack (createHashMapFromArray [
            ["kind", "input"], ["id", "gname"], ["ph", "squad name"],
            ["id2", "gpass2"], ["ph2", "password"],
            ["btn", "CREATE"], ["act", "groupCreate"], ["max", 16]
        ]);
        // One shared field for joining. A LOCKED squad needs the exact password;
        // an open one ignores whatever is typed, so a single box serves both and
        // the row's own JOIN button says which kind it is.
        _tools pushBack (createHashMapFromArray [
            ["kind", "input"], ["id", "gjoin"], ["ph", "password, for locked squads"],
            ["btn", ""], ["act", ""], ["max", 16], ["nobtn", true]
        ]);
    } else {
        if (_boss) then {
            _tools pushBack (createHashMapFromArray [
                ["kind", "input"], ["id", "gpass"], ["ph", "set a password"],
                ["btn", "SET"], ["act", "groupPass"], ["max", 16]
            ]);
        };
        _tools pushBack (createHashMapFromArray [
            ["kind", "btn"], ["btn", "LEAVE SQUAD"], ["act", "groupLeave"], ["tone", "bad"]
        ]);
        // There is no disband function: leaving as the LAST member deletes the
        // group. So disband is kick-everyone-then-leave, composed from the same
        // two calls a leader could make by hand, and offered only to the owner.
        if (_boss) then {
            _tools pushBack (createHashMapFromArray [
                ["kind", "btn"], ["btn", "DISBAND SQUAD"], ["act", "groupDisband"], ["tone", "bad"]
            ]);
        };
    };
    {
        if (isPlayer _x) then {
            private _u    = _x;
            private _self = _u isEqualTo player;
            // only the recorded owner may promote or kick, and never themselves
            private _can  = _boss && { !_self };
            _rows pushBack ([[name _u] call AP_fnc_cleanName,
                if (_u isEqualTo _leader) then { "LEADER" } else { "" },
                if (_self) then { "YOU" } else { format ["%1 m", round (player distance _u)] },
                if (alive _u) then { "live" } else { "bad" },
                "",
                if (_can) then { "groupLeader" } else { "" }, "PROMOTE", getPlayerUID _u,
                if (_can) then { "groupKick" } else { "" },   "KICK",    getPlayerUID _u] call _row);
        };
    } forEach (units _g);
    if (!_in) then {
        // Not in one: the useful screen is everyone ELSE's, not your own engine
        // group. Rows are [name, group, locked, ownerID, password]; the password
        // itself is never sent to the page.
        _rows = [];
        {
            _x params [["_nm", ""], ["_grp", grpNull], ["_lock", false], ["_own", ""], ""];
            if (_nm isNotEqualTo "" && { !isNull _grp }) then {
                _rows pushBack ([_nm,
                    if (_lock) then { "LOCKED" } else { "OPEN" },
                    format ["%1", { isPlayer _x } count (units _grp)],
                    if (_lock) then { "off" } else { "live" },
                    "",
                    "groupJoin", "JOIN", _nm,
                    "", "", "", "gjoin"] call _row);
            };
        } forEach (missionNamespace getVariable ["randomized_life_group_list", []]);
        _empty = "NO SQUADS RUNNING -- MAKE ONE ABOVE";
        _crumb = format ["// %1 RUNNING", count _rows];
    };
};

// --------------------------------------------------------------- achieve ----
// AP_achievementInfo rows are [id, sides, name, condition, desc, rewards,
// title, hidden]. Hidden ones stay hidden until earned, which is the point of
// them, and the condition is deliberately NOT evaluated here -- some of those
// code blocks are expensive and one of them per row per repaint is not free.
case "achieve": {
    _title = "ACHIEVEMENTS"; _crumb = "// EARNED"; _empty = "NOTHING EARNED YET";
    private _have = missionNamespace getVariable ["AP_achievements", []];
    {
        _x params [["_id", -1], ["_sides", []], ["_nm", ""], "", ["_desc", ""], "", ["_ttl", ""], ["_hidden", false]];
        if (AP_effSide in _sides) then {
            private _got = _id in _have;
            if (_got || { !_hidden }) then {
                _rows pushBack ([_nm, if (_got) then { "EARNED" } else { "" }, "",
                    if (_got) then { "on" } else { "off" }, _desc] call _row);
            };
        };
    } forEach (localNamespace getVariable ["AP_achievementInfo", []]);
};

// ---------------------------------------------------------------- titles ----
// Titles are the seventh field of an achievement row: earning the achievement is
// what unlocks the title. Only rows that actually carry one are listed.
case "titles": {
    _title = "TITLES"; _crumb = "// UNLOCKED"; _empty = "NO TITLES UNLOCKED";
    private _have = missionNamespace getVariable ["AP_achievements", []];
    private _worn = (player getVariable ["AP_title", ["", ""]]) param [0, ""];
    {
        _x params [["_id", -1], ["_sides", []], ["_nm", ""], "", "", "", ["_ttl", ""], ""];
        if (_ttl isNotEqualTo "" && { AP_effSide in _sides }) then {
            private _got  = _id in _have;
            private _isOn = _ttl isEqualTo _worn;
            // A title IS a format string -- "The Prominent %1", "Tycoon %1" -- with
            // %1 standing in for the player's name. Listing the raw catalogue value
            // put a literal %1 on screen; it has to be rendered to be read.
            _rows pushBack ([format [_ttl, name player],
                if (_isOn) then { "WORN" } else { if (_got) then { "UNLOCKED" } else { "LOCKED" } },
                "", if (_isOn) then { "on" } else { if (_got) then { "live" } else { "off" } },
                format ["from %1", _nm],
                if (_got) then { "title" } else { "" },
                if (_isOn) then { "REMOVE" } else { "WEAR" },
                if (_isOn) then { "" } else { _ttl }] call _row);
        };
    } forEach (localNamespace getVariable ["AP_achievementInfo", []]);
};

// ---------------------------------------------------------------- quests ----
// task 11: the legacy quest catalogue (AP_fnc_questsCfg, core/config/fn_questsCfg.sqf)
// this list used to read from is deleted along with the rest of the legacy quest
// system. This case is kept -- rather than dropped from the switch -- only so the
// "Quests" phone entry still opens a clean, well-formed empty screen instead of
// erroring on a call to a function that no longer exists. ArmaQuest's own journal
// ("Quest Log" -- AP_fnc_aqJournalOpen, dialog\web_journal.hpp) is the live
// replacement; see core/init.sqf for why that is a second, separately-named app
// rather than a takeover of this one.
case "quests": {
    _title = "QUESTS"; _crumb = "// CONTRACTS"; _empty = "RETIRED -- SEE QUEST LOG";
};

default {};
};

createHashMapFromArray [
    ["kind",  _kind],
    ["tools", _tools],
    ["title", _title],
    ["crumb", _crumb],
    ["empty", _empty],
    ["rows",  _rows]
]
