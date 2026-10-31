/*
    fn_staffWire.sqf  (AP_fnc_staffWire) -- put the STAFF DECK on a browser control.

    Registers the staff verbs and the roster push on WHATEVER control is handed in,
    so the same implementation serves both surfaces:

        [_ctrl] call AP_fnc_staffWire;    // from fn_deckOpen  -> staff is a phone app
        [_ctrl] call AP_fnc_staffWire;    // from fn_staffOpen -> the fullscreen fallback

    Owner call 2026-08-14: the staff panel is an APP IN THE PHONE, not a screen of
    its own. The deck's own control carries it, which is why every verb here had to
    stop assuming dialog 937600 -- it is usually 937500 now.

    THE WATCH FLAG. A roster at 1 Hz plus a cash sweep every 5 s is the right cost
    while a staffer is looking at it and pure waste while they are reading their
    texts, so the page turns it on when the app opens and off when it leaves. The
    pusher exits with the display, so a closed phone cannot leave it running.

    WHAT THE ROSTER CAN AND CANNOT KNOW (unchanged, and still the interesting part):
      - position, side, vehicle, alive, restrained: engine-synced to every client
        already; reading them leaks nothing new.
      - cash / bank: NOT synced. Swept with AP_fnc_adminPlayerQuery and cached by
        AP_fnc_adminInfo into AP_staffDossier; -1 until a player has answered once.
      - ping: there is NO scripted ping in Arma. The field is absent, and the page
        prints an em dash. Do not "fix" it by inventing a number.
      - other players' adminLevel: only the viewer's own is real. Publishing every
        staffer's level would tell any modded client exactly who is watching.
*/
params [["_ctrl", controlNull, [controlNull]]];
if (isNull _ctrl) exitWith { diag_log "[STAFF] wire: null control"; false };

// ------------------------------------------------------------- payload ----
private _live = {
    // Defined INSIDE the builder: it runs from the pusher spawn long after the
    // opener's scope is gone (the fn_mapOpen _vehKind lesson).
    private _vehKind = {
        params ["_u"];
        private _v = vehicle _u;
        if (_v isEqualTo _u) exitWith { "none" };
        switch (true) do {
            case (_v isKindOf "Helicopter"): { "heli" };
            case (_v isKindOf "Plane"):      { "plane" };
            case (_v isKindOf "Ship"):       { "boat" };
            default                          { "car" };
        }
    };
    private _money = missionNamespace getVariable ["AP_staffDossier", createHashMap];
    private _meUid = getPlayerUID player;

    private _rows = allPlayers apply {
        private _uid = getPlayerUID _x;
        private _c = _money getOrDefault [_uid, createHashMap];
        private _isMe = _uid isEqualTo _meUid;
        createHashMapFromArray [
            ["uid",        _uid],
            ["name",       [name _x] call AP_fnc_cleanName],
            ["side",       switch (side group _x) do { case west: {"cop"}; case independent: {"med"}; default {"civ"} }],
            // no "ping" key at all -- see the header. The page prints an em dash for
            // an absent field; a nil VALUE would not survive the hashmap anyway.
            ["cash",       if (_isMe) then { AP_cash }    else { _c getOrDefault ["cash", -1] }],
            ["bank",       if (_isMe) then { AP_atmcash } else { _c getOrDefault ["bank", -1] }],
            ["adminLevel", if (_isMe) then { call AP_adminLevel } else { 0 }],
            ["veh",        [_x] call _vehKind],
            ["restrained", (_x getVariable ["AP_restrained", false]) || { _x getVariable ["AP_adminRestrain", false] }],
            ["alive",      alive _x]
        ]
    };

    // Through missionNamespace, not bare: the flag is a mission object and this runs
    // once a second -- an undefined-variable throw here would spam the RPT and kill
    // the rest of the payload on any map where it is absent.
    private _stimmy = missionNamespace getVariable ["AP_stimmy", false];

    private _out = createHashMapFromArray [
        ["level",   call AP_adminLevel],
        ["you",     _meUid],
        ["toggles", createHashMapFromArray [
            ["god",         missionNamespace getVariable ["AP_adminGod", false]],
            ["invis",       player getVariable ["AP_invisOn", false]],
            ["adminMode",   missionNamespace getVariable ["AP_adminMode", false]],
            ["markers",     !isNil "AP_admin_showVeh"],
            ["stimmy",      _stimmy],
            ["fedOverride", missionNamespace getVariable ["AP_fedOverride", false]],
            ["fabFree",     missionNamespace getVariable ["AP_fabFreeBuild", false]]
        ]],
        ["players",  _rows]
    ];
    if (_stimmy) then { _out set ["stimmyDesc", "10x cartel"] };
    _out
};

// ----------------------------------------------------------- catalogues ----
// Built once per session and cached, exactly like the native menu's
// AP_adminWepCache / AP_adminClothCache -- config scans over thousands of classes
// that cannot change while the game runs. Magazines are deliberately NOT here:
// they are per-weapon, and the page asks for them with weaponAcc on selection.
private _catalog = {
    params [["_panel", "", [""]]];
    private _cache = missionNamespace getVariable ["AP_staffCat", createHashMap];
    if (_panel in _cache) exitWith { _cache get _panel };

    private _grp = { params ["_n", "_rows"];
        createHashMapFromArray [["name", _n], ["items", _rows apply {
            createHashMapFromArray [["cls", _x select 1], ["name", _x select 0]] }]] };

    private _out = switch (toLower _panel) do {

        case "weapons": {
            private _rifles = []; private _pistols = []; private _launchers = [];
            {
                private _dn = getText (_x >> "displayName");
                if (_dn isNotEqualTo "") then {
                    switch (getNumber (_x >> "type")) do {
                        case 1: { _rifles    pushBack [_dn, configName _x] };
                        case 2: { _pistols   pushBack [_dn, configName _x] };
                        case 4: { _launchers pushBack [_dn, configName _x] };
                    };
                };
            } forEach ("getNumber (_x >> 'scope') == 2 && {(getNumber (_x >> 'type')) in [1, 2, 4]}" configClasses (configFile >> "CfgWeapons"));
            // UAV terminals are type 4096, so the scan above misses them --
            // fn_adminWeaponMenu adds them by hand for the same reason.
            private _uav = [];
            {
                _x params ["_uCls", "_uLbl"];
                if (isClass (configFile >> "CfgWeapons" >> _uCls)) then { _uav pushBack [_uLbl, _uCls] };
            } forEach [["B_UavTerminal", "UAV Terminal (NATO)"], ["O_UavTerminal", "UAV Terminal (CSAT)"],
                       ["I_UavTerminal", "UAV Terminal (AAF)"], ["I_G_UavTerminal", "UAV Terminal (FIA)"]];
            { _x sort true } forEach [_rifles, _pistols, _launchers];
            createHashMapFromArray [["groups", [
                ["Rifles", _rifles] call _grp,
                ["Handguns", _pistols] call _grp,
                ["Launchers", _launchers] call _grp,
                ["Terminals", _uav] call _grp
            ]]]
        };

        case "vehicles": {
            private _auto = []; private _heli = []; private _plane = []; private _boat = []; private _other = [];
            {
                private _dn = getText (_x >> "displayName");
                private _cls = configName _x;
                if (_dn isNotEqualTo "") then {
                    switch (true) do {
                        case (_cls isKindOf "Helicopter"):    { _heli  pushBack [_dn, _cls] };
                        case (_cls isKindOf "Plane"):         { _plane pushBack [_dn, _cls] };
                        case (_cls isKindOf "Ship"):          { _boat  pushBack [_dn, _cls] };
                        case (_cls isKindOf "Car");
                        case (_cls isKindOf "Tank"):          { _auto  pushBack [_dn, _cls] };
                        case (_cls isKindOf "StaticWeapon"):  { _other pushBack [_dn, _cls] };
                    };
                };
            } forEach ("getNumber (_x >> 'scope') == 2" configClasses (configFile >> "CfgVehicles"));
            { _x sort true } forEach [_auto, _heli, _plane, _boat, _other];
            createHashMapFromArray [["groups", [
                ["Auto", _auto] call _grp,
                ["Heli", _heli] call _grp,
                ["Plane", _plane] call _grp,
                ["Boat", _boat] call _grp,
                ["Static", _other] call _grp
            ]]]
        };

        case "clothing": {
            private _uni = []; private _vest = []; private _hat = []; private _gls = []; private _bag = [];
            {
                private _dn = getText (_x >> "displayName");
                if (_dn isNotEqualTo "") then {
                    switch (getNumber (_x >> "ItemInfo" >> "type")) do {
                        case 801: { _uni  pushBack [_dn, configName _x] };
                        case 701: { _vest pushBack [_dn, configName _x] };
                        case 605: { _hat  pushBack [_dn, configName _x] };
                    };
                };
            } forEach ("getNumber (_x >> 'scope') == 2 && {isClass (_x >> 'ItemInfo')}" configClasses (configFile >> "CfgWeapons"));
            {
                private _dn = getText (_x >> "displayName");
                if (_dn isNotEqualTo "") then { _gls pushBack [_dn, configName _x] };
            } forEach ("getNumber (_x >> 'scope') == 2" configClasses (configFile >> "CfgGlasses"));
            {
                private _dn = getText (_x >> "displayName");
                if (_dn isNotEqualTo "" && { (configName _x) isKindOf "Bag_Base" }) then { _bag pushBack [_dn, configName _x] };
            } forEach ("getNumber (_x >> 'scope') == 2" configClasses (configFile >> "CfgVehicles"));
            { _x sort true } forEach [_uni, _vest, _hat, _gls, _bag];
            createHashMapFromArray [["groups", [
                ["Uniforms", _uni] call _grp,
                ["Vests", _vest] call _grp,
                ["Headgear", _hat] call _grp,
                ["Goggles", _gls] call _grp,
                ["Backpacks", _bag] call _grp
            ]]]
        };

        default { createHashMapFromArray [["groups", []]] };
    };

    // SIZE CAP, deliberate and LOUD. The catalogue crosses in one ExecJS string and
    // nothing in the library caps that direction. Measured 2026-08-14 on this build:
    // weapons 427 rows / 26k chars, vehicles 425 / 23k, clothing 734 / 46k -- no
    // group near 400, so the cap is not biting today. It stays as the backstop for a
    // modded server, and the RPT says exactly what it dropped.
    private _dropped = 0;
    {
        private _items = _x getOrDefault ["items", []];
        if (count _items > 400) then {
            _dropped = _dropped + ((count _items) - 400);
            _x set ["items", _items select [0, 400]];
            _x set ["name", format ["%1 (first 400)", _x get "name"]];
        };
    } forEach (_out getOrDefault ["groups", []]);

    _cache set [_panel, _out];
    missionNamespace setVariable ["AP_staffCat", _cache];
    diag_log format ["[STAFF] catalogue %1: %2 groups, %3 rows, %4 chars%5", _panel,
        count (_out getOrDefault ["groups", []]),
        [] call { private _n = 0; { _n = _n + count (_x getOrDefault ["items", []]) } forEach (_out getOrDefault ["groups", []]); _n },
        count (toJSON _out),
        if (_dropped > 0) then { format [" -- %1 rows DROPPED by the 400/group cap", _dropped] } else { "" }];
    _out
};

// -------------------------------------------------------------- the API ----
[_ctrl, "staff",        _live]    call webui_fnc_on;   // pages re-ask after a reload
[_ctrl, "staffCatalog", _catalog] call webui_fnc_on;

[_ctrl, "staffAct", {
    params [["_action", "", [""]], ["_target", "", [""]], ["_args", [], [[]]]];
    [_action, _target, _args] call AP_fnc_staffAct
}] call webui_fnc_on;

// The app opening and closing inside the phone, so the roster is only paid for
// while someone is reading it.
[_ctrl, "staffWatch", {
    params [["_on", false, [false]]];
    uiNamespace setVariable ["AP_staffWatch", _on];
    createHashMapFromArray [["ok", true], ["msg", ""]]
}] call webui_fnc_on;

// ---------------------------------------------------------- the pusher ----
// Runs with the control, not with a dialog id: the same code serves the phone
// (937500) and the fullscreen fallback (937600).
// The builder is PASSED IN, not looked up: the first iteration runs before the
// first uiSleep, so anything stashed after the spawn would be missed by one tick.
[_ctrl, _live] spawn {
    params ["_ctrl", "_live"];
    private _n = 0;
    while { !isNull _ctrl } do {
        if (uiNamespace getVariable ["AP_staffWatch", false]) then {
            if (_n % 5 isEqualTo 0) then {
                { if (_x isNotEqualTo player) then { [[player], "AP_fnc_adminPlayerQuery", _x, false] spawn AP_fnc_MP; } } forEach allPlayers;
            };
            [_ctrl, "staff", (call _live)] call webui_fnc_push;
            _n = _n + 1;
        } else {
            _n = 0;
        };
        uiSleep 1;
    };
};

diag_log format ["[STAFF] wired to control %1 (lvl %2)", ctrlIDC _ctrl, call AP_adminLevel];
true
