/*
    fn_deckData.sqf — build one channel payload for the web deck (ui\html\deck.html).

    Payloads are HashMaps. webui_fnc_push serialises with toJSON, so they
    arrive in the page as real JavaScript objects with the same key names —
    v.side, v.members, m.canKick. Nothing has to be mapped at the boundary.

    This used to be positional arrays because `str` was the only serialiser
    available; that put the field order in two files at once with nothing
    enforcing it, and one quote in a gang name produced invalid JSON. toJSON
    (2.18+) fixed both, and the hand-rolled string sanitiser went with it.

    Usage:  private _payload = ["phone"] call AP_fnc_deckData;
*/

params [["_channel", "", [""]]];

private _dist = {
    params ["_m"];
    if (_m >= 1000) then { format ["%1 km", ((_m / 1000) toFixed 1)] } else { format ["%1 m", round _m] }
};

// same formula fn_checkMailbox uses; both globals are server-published, so both
// can still be nil on a client that joined before they were broadcast
private _cycleSecs = missionNamespace getVariable ["serverCycleLength", 14400];
private _minsToRestart = {
    private _start = missionNamespace getVariable ["serverStartTime", -1];
    if (_start < 0) then { round ((14400 - serverTime) / 60) }
    else { round ((_cycleSecs - (serverTime - _start)) / 60) }
};

switch (toLower _channel) do {

// ---------------------------------------------------------------- phone ----
case "phone": {
    private _cop = AP_effSide isEqualTo west;

    // catalogue: app name -> [category, glyph]. Categories are the row keys the
    // page knows (comms/gang/economy/progress/standing/system/admin); "deck" is
    // deliberately not a row — the deck app is always the hero favourite.
    private _cat = createHashMapFromArray [
        ["ICEBREAKER OS", ["deck",     "cyberdeck"]],
        ["TAL OS",        ["deck",     "cyberdeck"]],
        ["Phone",         ["comms",    "phone"]],
        ["Message",       ["comms",    "message"]],
        ["Group",         ["comms",    "group"]],
        ["My Gang",       ["gang",     "mygang"]],
        ["Perks",         ["gang",     "perks"]],
        ["Captures",      ["gang",     "captures"]],
        ["Wanted",        ["gang",     "wanted"]],
        ["Gangs Online",  ["gang",     "gangsonline"]],
        ["Market",        ["economy",  "market"]],
        ["Housing",       ["economy",  "housing"]],
        ["SUMMON VEHICLE", ["economy",  "robotaxi"]],
        ["Casino",        ["economy",  "casino"]],
        ["Talents",       ["progress", "talents"]],
        ["Achieve",       ["progress", "achieve"]],
        ["Titles",        ["progress", "titles"]],
        ["Quests",        ["progress", "quests"]],
        ["Quest Log",     ["progress", "quests"]], // ArmaQuest journal (Task 9) -- same glyph as the native "Quests"/CONTRACTS app on purpose (both are quest-tracking apps); the two are told apart by name, not icon
        ["Prestige",      ["progress", "prestige"]],
        ["TT Prestige",   ["progress", "prestige"]],
        ["Infamy",        ["standing", "infamy"]],
        ["Honor",         ["standing", "honor"]],
        ["Bounty",        ["standing", "bounty"]],
        ["Licenses",      ["standing", "licenses"]],
        ["NETLINK",       ["comms",    "browser"]],
        ["Map",           ["system",   "map"]],
        ["Keychain",      ["system",   "keychain"]],
        ["Settings",      ["system",   "settings"]],
        ["Wallpaper",     ["system",   "wallpaper"]],
        ["Admin",         ["admin",    "settings"]],
        ["Camera",        ["admin",    "wallpaper"]],
        ["Owner Mode",    ["admin",    "settings"]]
    ];

    // live counters, used for badges and favourite sub-lines
    private _keyCount = { !isNull _x && { alive _x } } count AP_vehicles;
    private _licCount = { missionNamespace getVariable [(_x select 0), false] } count AP_licenses;
    private _gangOn   = 0;
    if !(AP_gang_data isEqualTo []) then {
        private _gid = AP_gang_data select 0;
        _gangOn = { (_x getVariable ["gang_data", [-1]]) param [0, -1] isEqualTo _gid } count allPlayers;
    };
    // UNREAD, not inbox size: AP_messages is a flat log that only ever grows, so counting it
    // meant the badge showed a number that never went down. AP_msgUnread is cleared per thread
    // as the player reads it (owner 2026-08-11).
    private _msgCount = call AP_fnc_msgUnreadTotal;
    private _nearby   = ((count (player nearEntities [["Man", "Car", "Truck", "Air"], 30])) - 1) max 0;

    private _badge = createHashMapFromArray [
        ["Keychain", if (_keyCount > 0) then { str _keyCount } else { "" }],
        ["Licenses", if (_licCount > 0) then { str _licCount } else { "" }],
        ["My Gang",  if (_gangOn   > 0) then { str _gangOn   } else { "" }],
        ["Message",  if (_msgCount > 0) then { str _msgCount } else { "" }]
    ];
    private _sub = createHashMapFromArray [
        ["ICEBREAKER OS", format ["FIRMWARE OK - %1 NEARBY", _nearby]],
        ["TAL OS",        format ["GRID LINKED - %1 NEARBY", _nearby]],
        ["My Gang",       format ["%1 ONLINE", _gangOn]],
        ["Keychain",      format ["%1 KEYS", _keyCount]],
        ["Licenses",      format ["%1 HELD", _licCount]],
        ["Message",       format ["%1 UNREAD", _msgCount]]
    ];

    // The phone's own registry is the source of truth for what exists and who may
    // see it — same list, same gates, same actions as the native phone. The four
    // globals ride the rail; only Message also has a catalogue entry, so the other
    // three fall out of the row build below on their own.
    private _all = (localNamespace getVariable "AP_phone_buttons") + (call AP_fnc_phoneGlobals);

    private _apps = [];
    {
        _x params [["_nm", "", [""]], "", "", ["_gate", { false }, [{}]]];
        private _meta = _cat getOrDefault [_nm, []];
        if (_meta isNotEqualTo [] && { call _gate }) then {
            _apps pushBack (createHashMapFromArray [
                ["id",    _nm],
                ["name",  _nm],
                ["cat",   _meta select 0],
                ["glyph", _meta select 1],
                ["badge", _badge getOrDefault [_nm, ""]]
            ]);
        };
    } forEach _all;

    // favourites: the deck app is always the hero tile, then the player's saved
    // favourites by NAME (same profileNamespace key the native phone uses — the
    // name only, never the action code), topped up from a per-side default set.
    private _gateOf = {
        params ["_nm"];
        private _hit = _all select { (_x select 0) isEqualTo _nm };
        if (_hit isEqualTo []) exitWith { false };
        call ((_hit select 0) select 3)
    };

    private _favNames = [];
    { if ([_x] call _gateOf) exitWith { _favNames pushBack _x }; } forEach ["ICEBREAKER OS", "TAL OS"];
    {
        if (count _favNames >= 5) exitWith {};
        if (!(_x in _favNames) && { [_x] call _gateOf }) then { _favNames pushBack _x };
    } forEach (profileNamespace getVariable ["AP_favApps_v2", []]);
    {
        if (count _favNames >= 5) exitWith {};
        if (!(_x in _favNames) && { [_x] call _gateOf }) then { _favNames pushBack _x };
    } forEach (if (_cop) then {
        ["Wanted", "Gangs Online", "Market", "Captures", "Keychain"]
    } else {
        ["Market", "My Gang", "Keychain", "Quests", "Licenses"]
    });

    private _favs = [];
    {
        private _meta = _cat getOrDefault [_x, ["system", "settings"]];
        _favs pushBack (createHashMapFromArray [
            ["id",    _x],
            ["name",  _x],
            ["glyph", _meta select 1],
            ["sub",   _sub getOrDefault [_x, ""]],
            ["hero",  _forEachIndex isEqualTo 0]
        ]);
    } forEach _favNames;

    // fictional handset battery, drained across the restart cycle. Deterministic
    // and free — replace with a real mechanic if one ever exists.
    private _mins = call _minsToRestart;
    private _cyc  = _cycleSecs / 60;
    if (_cyc <= 0) then { _cyc = 240 };
    private _batt = (round (18 + 80 * ((_mins max 0) / _cyc))) min 100;

    private _h = floor dayTime;
    private _m = floor ((dayTime - _h) * 60);

    createHashMapFromArray [
        ["side",    ["civ", "cop"] select _cop],
        ["restart", format ["%1m", _mins max 0]],
        ["batt",    _batt],
        ["cash",    AP_cash],
        ["bank",    AP_atmcash],
        ["clock",   format ["%1:%2",
                        [str _h, "0" + str _h] select (_h < 10),
                        [str _m, "0" + str _m] select (_m < 10)]],
        ["apps",    _apps],
        ["favs",    _favs]
    ]
};

// ----------------------------------------------------------------- gang ----
case "gang": {
    if (AP_gang_data isEqualTo []) exitWith { createHashMap };

    private _rankName = {
        params ["_r"];
        switch (_r) do {
            case 1: { "LEADER" };
            case 2: { "OFFICER" };
            case 3: { "RECRUITER" };
            case 5: { "RECRUIT" };
            default { "MEMBER" };
        }
    };

    private _myRank = AP_gang_data param [2, 5];
    private _myUid  = getPlayerUID player;

    private _members = [];
    {
        // AP_gangMembersList rows are [uid, name, rank] (APS_fnc_getGangInfo)
        _x params [["_uid", "", [""]], ["_nm", "", [""]], ["_rk", 5, [0]]];
        private _unit = allPlayers param [allPlayers findIf { getPlayerUID _x isEqualTo _uid }, objNull];
        private _online = !isNull _unit;

        // mirrors the checks in fn_gangKick: lower rank number = more authority,
        // rank 3 may only remove rank 5. The server re-validates regardless.
        private _self = _uid isEqualTo _myUid;

        _members pushBack (createHashMapFromArray [
            ["uid",        _uid],
            ["name",       _nm],
            ["rank",       [_rk] call _rankName],
            ["online",     _online],
            ["metric",     if (_online) then { [player distance _unit] call _dist } else { "offline" }],
            ["canPromote", !_self && { _myRank <= 2 } && { _rk > 2 }],
            ["canKick",    !_self && { _myRank <= 3 } && { _rk > _myRank }
                                  && { !(_myRank isEqualTo 3) || { _rk isEqualTo 5 } }]
        ]);
    } forEach (missionNamespace getVariable ["AP_gangMembersList", []]);

    // cap and perkPoints have no client-side source on this server; -1 tells the
    // page to render a dash rather than a made-up number.
    createHashMapFromArray [
        ["name",       AP_gang_data param [1, "Gang"]],
        ["tag",        (group player) getVariable ["gangTag", ""]],
        ["myRank",     [_myRank] call _rankName],
        ["funds",      AP_gang_funds],
        ["cap",        -1],
        ["perkPoints", -1],
        ["founded",    ""],
        // Renaming is leader-only and costs the gang bank a fee (owner 2026-08-14).
        // The page prices and gates the button from these; APS_fnc_gangRenameSRV
        // re-checks both against the DB, so this is honesty, not security.
        ["canRename",  _myRank isEqualTo 1],
        ["renameFee",  missionNamespace getVariable ["AP_gangRenameFee", 50000]],
        ["members",    _members],

        // FIXER ALLEGIANCE. Everything here is DISPLAY -- the server re-derives the
        // rank, the fee, the cooldown and the war block from the database before it
        // changes anything, so a page that lied about any of it would only earn
        // itself a refusal with a reason.
        //
        // `faction` is read from the published gang -> faction mirror rather than
        // from anything client-side, so it stays correct for a member who was not
        // online when the leader swore.
        ["faction",    ([] call {
            private _map = missionNamespace getVariable ["AP_gangFactions", []];
            private _i = _map findIf { (_x param [0, -1]) isEqualTo (AP_gang_data param [0, -1]) };
            if (_i isEqualTo -1) then { "" } else { format ["%1", (_map select _i) param [1, ""]] }
        })],
        // The three that hold ground. The reserved fourth has an empty polygon and
        // is filtered out here rather than hidden in the page, so adding it to the
        // world is a config edit and not a UI change.
        ["fixers",     ((["all"] call AP_fnc_factionCfg) select { (_x param [5, []]) isNotEqualTo [] }) apply {
            createHashMapFromArray [
                ["id",    _x select 0],
                ["name",  _x select 1],
                ["town",  _x param [6, ""]],
                ["blurb", _x param [4, ""]]
            ]
        }],
        // This week's matchup, so the page can say why a defection is refused
        // BEFORE the player clicks and gets told by the server.
        ["war",        missionNamespace getVariable ["AP_factionWar", []]],
        ["defectFee",  missionNamespace getVariable ["AP_FACTION_DEFECT_FEE", 500000]],
        ["defectDays", missionNamespace getVariable ["AP_FACTION_DEFECT_DAYS", 7]],
        // The size at which an unaligned crew starts being told to choose. The page
        // uses it to explain the prompt rather than to enforce anything.
        ["alignAt",    missionNamespace getVariable ["AP_FACTION_ALIGN_AT", 5]],

        // COMMAND extension (deck-gang-a/c): the bank, the tag, and the war room.
        ["rank",       _myRank],
        ["cash",       AP_cash],
        ["wars",       missionNamespace getVariable ["AP_gang_wars", []]],
        ["challenges", missionNamespace getVariable ["AP_gang_challenges", []]],
        // other gangs online, for the challenge picker: grouped off the public
        // gang_data var, the same sweep the native wars menu does
        ["targets",    ([] call {
            private _seen = createHashMap;
            {
                private _gd = _x getVariable ["gang_data", []];
                private _og = _gd param [0, -1];
                if (_og isNotEqualTo -1 && {_og isNotEqualTo (AP_gang_data param [0, -1])}) then {
                    _seen set [_og, _gd param [1, "?"]];
                };
            } forEach allPlayers;
            (keys _seen) apply { createHashMapFromArray [["id", _x], ["name", _seen get _x]] }
        })]
    ]
};

// ----------------------------------------------------------------- keys ----
case "keys": {
    private _pairs = [];
    private _veh = 0;
    private _hou = 0;
    {
        if (!isNull _x && { alive _x }) then {
            private _isHouse = _x isKindOf "House_F";
            private _name  = getText (configFile >> "CfgVehicles" >> (typeOf _x) >> "displayName");
            private _plate = ((_x getVariable ["AP_dbInfo", _x getVariable ["dbInfo", []]]) param [1, ""]);
            if !(_plate isEqualType "") then { _plate = str _plate };
            private _d = player distance _x;

            private _kind = "VEHICLE";
            if (_isHouse) then {
                _hou = _hou + 1; _kind = "HOUSE";
                if (_plate isEqualTo "") then { _plate = format ["HOUSE %1", _hou] };
            } else {
                _veh = _veh + 1;
                if (_plate isEqualTo "") then { _plate = format ["VEH %1", _veh] };
            };

            // A house key can only be passed on by the owner (fn_keyGive enforces
            // this too — this only decides whether the button looks available).
            private _mineToGive = !_isHouse
                || { (_x getVariable ["AP_homeOwner", "Error UID"]) isEqualTo getPlayerUID player };

            _pairs pushBack [_d, createHashMapFromArray [
                ["key",     netId _x],
                ["id",      _plate],
                ["kind",    _kind],
                ["label",   _name],
                ["state",   [_d] call _dist],
                ["canGive", _mineToGive],
                ["canDrop", true],
                ["live",    _d < 500]
            ]];
        };
    } forEach AP_vehicles;

    // nearest first — the panel header claims it is sorted by distance
    private _items = ([_pairs, [], { _x select 0 }, "ASCEND"] call BIS_fnc_sortBy) apply { _x select 1 };

    private _held = count AP_houses;

    createHashMapFromArray [
        ["held",         _held],
        ["max",          AP_maxHouseKeys],
        ["nextSlotCost", (AP_keyUpgradeCosts param [_held, -1]) max 0],
        ["vehCount",     _veh],
        ["houseCount",   _hou],
        ["items",        _items]
    ]
};

// ---------------------------------------------------------------- money ----
case "money": {
    private _near = [];
    {
        if (_x isNotEqualTo player && { alive _x } && { (player distance _x) <= 30 }) then {
            _near pushBack (createHashMapFromArray [
                ["uid",  getPlayerUID _x],
                ["name", name _x],
                ["dist", [player distance _x] call _dist]
            ]);
        };
    } forEach allPlayers;

    // FINES = what you are WANTED for, read-only (owner 2026-08-14). This server
    // has no fine store and no way to settle one from a phone -- charges clear when
    // an officer processes you -- so the box is a charge sheet in fines' clothing
    // and the page renders no PAY button. A_stats_crimes is the offender's OWN copy:
    // index 0 is the running bounty, index N the number of counts of charge N
    // (fn_wantedListAdd). Cops get the same data for other players through the
    // WANTED app; this is the one place a civ can read their own.
    private _fines = [];
    private _crimes = missionNamespace getVariable ["A_stats_crimes", []];
    for "_i" from 1 to ((count _crimes) - 1) do {
        private _n = _crimes select _i;
        if (_n > 0) then {
            private _value = ["getChargeValue", _i] call AP_fnc_wantedChargesConfig;
            _fines pushBack (createHashMapFromArray [
                ["id",     str _i],
                ["reason", ["getChargeName", _i] call AP_fnc_wantedChargesConfig],
                ["by",     if (_n > 1) then { format ["%1 COUNTS", _n] } else { "1 COUNT" }],
                ["amount", _value * _n]
            ]);
        };
    };

    // The paycheck loop runs server-side, so the client cannot see its phase, and
    // there is no per-player ledger store; both push empty rather than inventing rows.
    createHashMapFromArray [
        ["cash",   AP_cash],
        ["bank",   AP_atmcash],
        // NEW DRACHMA is server-authoritative and held as an exact 4dp STRING
        // (AP_ndStr); AP_nd is only a float mirror for legacy afford-checks. Send
        // the string, already pretty-printed by the helper that owns the format --
        // the page's own money formatter is dollars-and-cents and would round it.
        ["nd",     [AP_ndStr] call AP_fnc_ndText],
        ["payIn",  ""],
        ["fines",  _fines],
        // The bounty is the authoritative total the MaxSec collects on; the rows above
        // can drift from it (a charge cleared, a stacked count capped), so the page
        // shows THIS as the amount due rather than the sum of what it drew.
        ["bounty", _crimes param [0, 0]],
        ["ledger", []],
        ["nearby", _near]
    ]
};

// ----------------------------------------------------------------- msgs ----
// Pattern F. Two stores, not one -- and the design brief merged them:
//
//   AP_msgThreads  real two-way conversations, but ONLY player DMs (and the
//                   Ben Bones AI). Keyed by DISPLAY NAME, not uid, because that
//                   is what AP_fnc_msgAppend writes. profileNamespace-persisted,
//                   capped at 15 threads x 40 messages, newest thread first.
//   AP_messages   a flat, one-way INBOX: 911 dispatch, EMT dispatch, admin
//                   broadcasts. Nothing here is a conversation and none of it
//                   can be replied to, so it must not be drawn as a thread.
//
// Sending to Police / Medic / Admins is fire-and-forget: fn_sendText never calls
// msgAppend for those modes, so they are compose DESTINATIONS, not threads.
case "msgs": {
    private _clean = { params ["_n"]; [_n] call AP_fnc_cleanName };

    private _threads = [];
    {
        _x params ["_who", ["_items", []]];
        private _last = if (_items isEqualTo []) then { ["", ""] } else { _items select (count _items - 1) };
        private _online = (allPlayers findIf { ([name _x] call _clean) isEqualTo _who }) > -1;
        _threads pushBack (createHashMapFromArray [
            ["key",     _who],
            ["name",    _who],
            // uid is what a send needs; the store only knows names, so this comes out of the
            // local name->uid map. Empty means we have never seen them and cannot text them
            // while they are away.
            ["uid",     [_who] call AP_fnc_msgUidGet],
            ["unread",  [_who] call AP_fnc_msgUnreadGet],
            ["kind",    if (_who isEqualTo "Ben Bones Official") then { "ai" } else { "dm" }],
            ["online",  _online],
            ["preview", _last param [1, ""]],
            ["time",    _last param [2, ""]],
            ["items",   _items apply {
                createHashMapFromArray [["dir", _x param [0, 0]], ["text", _x param [1, ""]], ["t", _x param [2, ""]]]
            }]
        ]);
    } forEach AP_msgThreads;

    // Read-only. The stored string is pre-formatted with a prefix marker
    // (">>>" DM, "---" dispatch, "!!!" admin, "???" request) -- the page groups
    // on that rather than re-deriving a type that was never stored.
    private _inbox = [];
    {
        _x params [["_from", ""], ["_txt", ""], ["_t", 0]];
        _inbox pushBack (createHashMapFromArray [["from", _from], ["text", _txt], ["t", _t]]);
    } forEach (AP_messages select [((count AP_messages) - 30) max 0, 30]);
    reverse _inbox;

    // Who can be DM'd: everyone online except you. The native list is the same
    // set, built by the native phone shell (fn_p_updateMenu, deleted in ce1f5e23).
    private _contacts = [];
    {
        _contacts pushBack (createHashMapFromArray [
            ["uid",  getPlayerUID _x],
            ["name", [name _x] call _clean],
            ["dist", [player distance _x] call _dist]
        ]);
    } forEach (allPlayers select { _x isNotEqualTo player && { alive _x } });

    // Contacts we know but who are not here. These are exactly the people an offline message
    // can be addressed to, because a uid was recorded for them at some point.
    private _offline = [];
    {
        _x params [["_n", ""], ["_u", ""]];
        if (_n isNotEqualTo "" && {(_contacts findIf { (_x get "name") isEqualTo _n }) isEqualTo -1}) then {
            _offline pushBack (createHashMapFromArray [["uid", _u], ["name", _n], ["dist", ""]]);
        };
    } forEach AP_msgUids;

    // Silence Cell jams every outgoing mode. Reporting the remaining seconds
    // lets the composer disable itself instead of failing on send.
    private _jamUntil = missionNamespace getVariable ["AP_qhSilencedUntil", 0];
    private _jammed   = ((_jamUntil - diag_tickTime) max 0) toFixed 0;

    createHashMapFromArray [
        ["threads",  _threads],
        ["inbox",    _inbox],
        ["contacts", _contacts],
        ["offline",  _offline],
        ["unread",   call AP_fnc_msgUnreadTotal],
        // fn_sendText modes that need no recipient. 4 is the taxi and is refused
        // at the top of that function, so it is deliberately not offered.
        ["channels", [
            createHashMapFromArray [["mode", 1], ["name", "THE POLICE"]],
            createHashMapFromArray [["mode", 2], ["name", "EMERGENCY MEDICAL"]],
            createHashMapFromArray [["mode", 3], ["name", "THE ADMINS"]]
        ]],
        ["jammed",   parseNumber _jammed],
        ["maxLen",   500],
        ["arrested", (AP_is_arrested param [0, 0]) isEqualTo 1]
    ]
};

// --------------------------------------------------------------- market ----
// Pattern D. The design brief's own correction was right -- this REPORTS prices,
// it does not trade. Buying and selling happen at the dealer, in the world.
//
// What the brief got wrong is the number in the drift column. There is no 24h
// change and no price history anywhere in this codebase, so the 14-bar spark
// line has nothing to draw. What DOES exist is better: AP_price_index holds
// [class, prem, sales] per tracked good, server-synced and DB-persisted, where
//
//   prem   the live premium multiplier, clamped to [AP_marketFloor 0.6,
//          AP_marketMaxPrem 1.3]. SELLING drives it down toward the floor
//          (oversupply, the good is worth less), an idle tick lets it climb
//          back toward the ceiling (scarcity). 1.0 is neutral.
//   sales  accumulated sell volume -- a real demand signal the brief did not
//          know was available.
//
// So the column is a POSITION IN A BAND, not a percentage change, and the page
// is given the floor and ceiling so it can draw that honestly.
//
// Untracked goods have static prices and report prem 1.0 / tracked false; they
// must not be drawn as though they were flat-but-live.
case "market": {
    private _catIds = ["heroin", "wongs", "rebel", "market", "oil", "fishmarket", "diamond", "salt", "commod", "blackmarket"];

    private _floor = missionNamespace getVariable ["AP_marketFloor", 0.6];
    private _ceil  = missionNamespace getVariable ["AP_marketMaxPrem", 1.3];
    private _idx   = missionNamespace getVariable ["AP_price_index", []];

    private _cats  = [];
    private _order = [];          // item id -> first seen, keeps a stable row order
    private _catsOf = createHashMap;
    {
        private _cid  = _x;
        private _info = [_cid] call AP_fnc_virt_shops;
        _info params [["_title", "", [""]], ["_buy", [], [[]]], ["_sell", [], [[]]]];
        if (_title isNotEqualTo "") then {
            _cats pushBack (createHashMapFromArray [["id", _cid], ["title", _title], ["n", count _sell]]);
            {
                // one row per good, carrying every category it trades in -- an item
                // in two shops is one line with two tags, not two lines
                private _have = _catsOf getOrDefault [_x, []];
                if (_have isEqualTo []) then { _order pushBack _x; };
                _have pushBack _cid;
                _catsOf set [_x, _have];
            } forEach _sell;
        };
    } forEach _catIds;

    private _goods = [];
    {
        private _it = _x;
        private _sell = ["getLowestPrice", _it] call AP_fnc_virtItemCfg;
        private _buy  = ["getBasePrice",   _it] call AP_fnc_virtItemCfg;
        if (!(_sell isEqualType 0)) then { _sell = 0 };
        if (!(_buy  isEqualType 0)) then { _buy  = 0 };

        // raw premium straight off the synced index, so the page can show where a
        // good sits in the band rather than a factor already folded into the price
        private _i    = _idx findIf { (_x isEqualType []) && { (_x param [0, ""]) isEqualTo _it } };
        private _prem = if (_i isEqualTo -1) then { -1 } else { (_idx select _i) param [1, -1] };
        private _sold = if (_i isEqualTo -1) then { 0 }  else { (_idx select _i) param [2, 0] };
        private _tracked = (!isNil "AP_marketGoods") && { _it in AP_marketGoods } && { _prem > 0 };

        _goods pushBack (createHashMapFromArray [
            ["id",      _it],
            ["name",    ["getName", _it] call AP_fnc_virtItemCfg],
            ["cats",    _catsOf getOrDefault [_it, []]],
            ["buy",     round _buy],
            ["sell",    round _sell],
            ["prem",    if (_tracked) then { (_prem max _floor) min _ceil } else { 1 }],
            ["sales",   _sold],
            ["tracked", _tracked],
            ["illegal", ["getIllegalPrice", _it] call AP_fnc_virtItemCfg > 0],
            ["weight",  ["getItemWeight", _it] call AP_fnc_virtItemCfg],
            ["held",    missionNamespace getVariable [format ["AP_inv_%1", _it], 0]]
        ]);
    } forEach _order;

    // What the player is actually carrying, so the screen answers "should I sell
    // this now" rather than just listing prices in the abstract.
    private _holdings = [];
    private _carried  = 0;
    {
        private _g = _x;
        private _n = _g get "held";
        if (_n isEqualType 0 && { _n > 0 }) then {
            _carried = _carried + _n * ((_g get "weight") max 0);
            _holdings pushBack (createHashMapFromArray [
                ["id",    _g get "id"],
                ["name",  _g get "name"],
                ["qty",   _n],
                ["value", _n * (_g get "sell")]
            ]);
        };
    } forEach _goods;

    // Server-wide event: every illegal drug sells +12% while it runs. Worth its own
    // banner -- it is the one thing on this screen that is urgent.
    private _bustUntil = missionNamespace getVariable ["AP_drugBustUntil", 0];
    private _bust = ((_bustUntil - serverTime) max 0) toFixed 0;

    createHashMapFromArray [
        ["cats",     _cats],
        ["goods",    _goods],
        ["holdings", _holdings],
        ["carried",  round _carried],
        ["floor",    _floor],
        ["ceil",     _ceil],
        ["bust",     parseNumber _bust]
    ]
};

// ------------------------------------------------------------ wallpaper ----
// Pattern E, picker half. The brief specified a 6-column grid of 24 images;
// there is ONE static .paa plus the deck's own live CSS layer, so the grid is
// sized to the catalogue rather than to the mock.
//
// There used to be a second, PAA-ANIMATED entry: Matrix Rain, 16 baked frames
// driven by an SQF loop that swapped them onto control 90300. It was removed
// 2026-08-14 -- the live CSS wallpaper below is the same effect for no texture
// memory and no script loop -- and the frame-sequence machinery went with it.
case "wallpaper": {
    private _cur = missionNamespace getVariable ["AP_wallpaper", -1];
    private _out = [];
    {
        _x params [["_id", -1], ["_path", ""], ["_name", ""], ["_gate", {true}]];
        if ([] call _gate) then {
            _out pushBack (createHashMapFromArray [
                ["id",     _id],
                ["name",   _name],
                // SQF strings do not escape backslashes -- "\\" is two literal
                // characters and the texture would never resolve.
                ["path",   format ["images\wallpapers\%1", _path]],
                ["cur",    _id isEqualTo _cur]
            ]);
        };
    } forEach (localNamespace getVariable "AP_wallpapers");

    // LIVE wallpapers are deck-only and deliberately NOT in AP_wallpapers: they are
    // CSS layers, not textures, and a live entry in that catalogue would make the
    // native picker try to ctrlSetText a path that does not exist. The deck keeps its
    // own override; empty means "follow the .paa choice", so both handsets stay in
    // sync for everything the native one can actually render.
    private _live = [
        createHashMapFromArray [["id", "live_10"], ["name", "Matrix Rain"], ["note", "CSS"]]
    ];

    createHashMapFromArray [
        ["items",   _out],
        ["current", _cur],
        ["live",    _live],
        ["deck",    profileNamespace getVariable ["AP_deckWall", ""]],
        // 0 OFF / 1 LOW / 2 MED / 3 HIGH -- a scrim between the wallpaper and the
        // panels. Live wallpapers are full-bleed and bright; the panels have to stay
        // readable over them.
        ["scrim",   profileNamespace getVariable ["AP_deckScrim", 1]],
        // on | launcher | off. Frame delivery is dirty-driven, so a full-bleed
        // animation marks the whole surface dirty every frame -- "launcher" keeps
        // the cost to the one screen that is mostly idle anyway.
        ["motion",  profileNamespace getVariable ["AP_deckWallMotion", "launcher"]]
    ]
};

// ------------------------------------------------------------------ inv ----
// Pattern E, inventory half. Items come from virtItemCfg mode 2 -- the plain id
// list -- rather than mode 1's "AP_inv_<id>" variable names, which is what the
// native dialog iterates. The ids feed getName/getShortName/getItemWeight
// directly, so nothing has to strip a prefix back off.
//
// Loot-crate keys and infamy scalps are NOT virtual items and have no id: they
// live in their own arrays and cannot be dropped, used or given. They are listed
// as a separate read-only group rather than mixed in with things that have
// actions, which is what the native list does.
case "inv": {
    private _items = [];
    {
        private _id  = _x;
        private _qty = missionNamespace getVariable [format ["AP_inv_%1", _id], 0];
        if (_qty isEqualType 0 && { _qty > 0 }) then {
            private _w = ["getItemWeight", _id] call AP_fnc_virtItemCfg;
            if (!(_w isEqualType 0)) then { _w = 0 };
            _items pushBack (createHashMapFromArray [
                ["id",     _id],
                ["name",   ["getName", _id] call AP_fnc_virtItemCfg],
                ["qty",    _qty],
                ["weight", _w],
                ["total",  _qty * _w],
                ["sell",   ["getLowestPrice", _id] call AP_fnc_virtItemCfg],
                // the same explainer the shop hover uses; chips and hacks have real copy
                ["desc",   AP_itemDesc getOrDefault [_id, ""]]
            ]);
        };
    } forEach ([2] call AP_fnc_virtItemCfg);

    // read-only oddments, kept out of the actionable list
    private _odd = [];
    private _keyNames = ["Loot", "Guardian", "Aggressor", "Destruction", "Revival", "Horn 1", "Horn 2",
        "Crypto", "Camo 1", "Camo 2", "Blasphemy", "Horn 3", "Retribution", "Takeover", "Uniform 1",
        "Vengeance", "Futuristic"];
    {
        private _n = _x param [0, 0];
        if (_n isEqualType 0 && { _n >= 1 }) then {
            _odd pushBack (createHashMapFromArray [
                ["name", format ["%1 Crate Key", _keyNames param [_forEachIndex, "Crate"]]],
                ["qty",  _n]
            ]);
        };
    } forEach AP_lootKeys;
    {
        _odd pushBack (createHashMapFromArray [["name", format ["%1's scalp", _x param [2, "?"]]], ["qty", 1]]);
    } forEach AP_infamyScalps;

    // Give targets. fn_giveItem resolves against allUnits, so this matches it
    // rather than using the keychain's nearer/gang-aware rule.
    private _near = [];
    {
        if (_x isNotEqualTo player && { alive _x } && { !(_x getVariable ["AP_invisOn", false]) }) then {
            _near pushBack (createHashMapFromArray [
                ["uid",  getPlayerUID _x],
                ["name", [name _x] call AP_fnc_cleanName],
                ["dist", [player distance _x] call _dist]
            ]);
        };
    } forEach allPlayers;

    createHashMapFromArray [
        ["items",  _items],
        ["odd",    _odd],
        ["weight", missionNamespace getVariable ["AP_carryWeight", 0]],
        ["max",    missionNamespace getVariable ["AP_maxWeight", 0]],
        ["nearby", _near]
    ]
};

// ------------------------------------------------------------------ bank ----
// The ATM app. Assembly and every guard live in AP_fnc_deckBank; this case
// exists so the generic "refresh" channel can rebuild it like any other.
case "bank": { ["data"] call AP_fnc_deckBank };

// ------------------------------------------------------------------- rig ----
case "rig": { ["data"] call AP_fnc_deckRig };
case "netlink": { ["data"] call AP_fnc_deckNetlink };

// ------------------------------------------------------------------ boot ----
case "boot": { ["data"] call AP_fnc_deckBoot };

// ------------------------------------------------------------------ duel ----
case "duel": { ["data"] call AP_fnc_deckDuel };

// ---------------------------------------------------------------- suites ----
case "suites": { ["data"] call AP_fnc_deckSuites };

// ----------------------------------------------------------------- medic ----
case "medic": { ["data"] call AP_fnc_deckMedic };

// ---------------------------------------------------------------- intake ----
case "intake": { ["data"] call AP_fnc_deckIntake };

// ---------------------------------------------------------------- sprays ----
case "sprays": { ["data", missionNamespace getVariable ["AP_deckSprayMode", "spray"]] call AP_fnc_deckSpray };

// -------------------------------------------------------------- loadouts ----
case "loadouts": { ["data"] call AP_fnc_deckLoadouts };

// ------------------------------------------------------------ chop + skins --
case "chop":  { ["chopData"] call AP_fnc_deckChop };
case "skins": { ["skinData"] call AP_fnc_deckChop };

// ----------------------------------------------------------------- house ----
case "house": { ["data"] call AP_fnc_deckHouse };

// ----------------------------------------------------------------- vshop ----
case "vshop": { ["data"] call AP_fnc_deckVShop };

// ----------------------------------------------------------------- trunk ----
case "trunk": { ["data"] call AP_fnc_deckTrunk };

// ---------------------------------------------------------------- garage ----
case "garage": { ["data"] call AP_fnc_deckGarage };

// ------------------------------------------------------------------- fab ----
case "fab": { ["data"] call AP_fnc_deckFab };

// -------------------------------------------------------------- exchange ----
case "exchange": {
    // the channel refresh triggers the async open dance; the dance pushes the
    // real payload when the server answers, so this returns a placeholder
    ["fetch"] call AP_fnc_deckExchange;
    createHashMap
};

default { createHashMap };
};
