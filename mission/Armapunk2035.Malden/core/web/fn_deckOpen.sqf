/*
    fn_deckOpen.sqf — boot the web phone (dialog 937500, ui\html\deck.html).

    Wires the generic bridge up, registers the deck's own handlers with
    webui_fnc_on, then starts the push loop.

    WHAT IS WIRED IN THIS BUILD
      Reading is real: the launcher is generated from AP_phone_buttons (same
      gates, same actions), the roster from APS_fnc_getGangInfo, the keychain
      from AP_vehicles, the wallet from AP_cash / AP_atmcash.
      launch, sync, setFavs, markPlayer and keyAction "locate" do real work.

      Everything that MOVES money or membership answers ok=false instead. That
      is deliberate, not an oversight: the native functions behind them
      (fn_gangKick, fn_invite2Gang, fn_keyGive, fn_keyDrop, fn_giveMoney) read
      their arguments straight out of their own dialogs' listboxes, so none of
      them can be called from here until they take params. Faking it would mean
      writing fresh client-side money paths, which security.md forbids.

    Usage:  [_this select 0] spawn AP_fnc_deckOpen;   (dialog onLoad)
*/

params [["_display", displayNull, [displayNull]]];
if (isNull _display) exitWith { diag_log "[DECK] open: null display"; };

disableSerialization;
private _ctrl = _display displayCtrl 937501;
if (isNull _ctrl) exitWith { diag_log "[DECK] open: browser control 937501 missing"; };

if !([_ctrl] call webui_fnc_init) exitWith { diag_log "[DECK] open: bridge init failed"; };
// Let the SERVER replace this page's markup if it holds a newer copy, so UI ships
// without a client repack. No-op unless AP_fnc_webServeInit registered a fetcher and
// the server actually has the file -- otherwise the PBO page you just loaded stands.
[_ctrl, "ui\html\deck.html"] call webui_fnc_serve;

// Owner's saved handset size. Applied before the page is talked to so it boots straight into the
// right geometry rather than snapping after the roll-out animation has already played.
private _scale = [_ctrl] call AP_fnc_deckScale;
diag_log format ["[DECK] scale %1", _scale toFixed 2];

// Needs the -debug start parameter, or this is a no-op.
if (!isNil "AP_devMode" && { AP_devMode }) then { _ctrl ctrlWebBrowserAction ["OpenDevConsole"]; };

// ------------------------------------------------------------- deck API ----
// Every handler answers { ok, msg }; the page puts msg in the status strip, red
// when ok is false.
[_ctrl, "log", {
    params [["_msg", "", [""]]];
    diag_log format ["[DECK] %1", _msg];
    createHashMapFromArray [["ok", true], ["msg", ""]]
}] call webui_fnc_on;

[_ctrl, "refresh", {
    params [["_ch", "", [""]]];
    private _c = uiNamespace getVariable ["WEBUI_ctrl", controlNull];
    if (isNull _c) exitWith { createHashMapFromArray [["ok", false], ["msg", "no control"]] };
    if (_ch isEqualTo "gang") then { [] call AP_fnc_deckGangRequest; };
    [_c, _ch, ([_ch] call AP_fnc_deckData)] call webui_fnc_push;
    createHashMapFromArray [["ok", true], ["msg", ""]]
}] call webui_fnc_on;

[_ctrl, "launch", {
    params [["_name", "", [""]]];
    private _all = (localNamespace getVariable "AP_phone_buttons") + (call AP_fnc_phoneGlobals);
    private _hit = _all select { (_x select 0) isEqualTo _name };
    if (_hit isEqualTo []) exitWith {
        createHashMapFromArray [["ok", false], ["msg", format ["no such app: %1", _name]]]
    };

    (_hit select 0) params ["", "", "_action", "_gate"];
    if !(call _gate) exitWith {
        createHashMapFromArray [["ok", false], ["msg", format ["%1 is not available to you", _name]]]
    };

    // Every native app expects to own the dialog slot, so this one has to go
    // first. The 0.1s matches what the ICEBREAKER button in AP_phone_buttons
    // already does before createDialog.
    [_action] spawn {
        params ["_action"];
        closeDialog 0;
        uiSleep 0.1;
        call compile _action;
    };
    createHashMapFromArray [["ok", true], ["msg", format ["opening %1", _name]]]
}] call webui_fnc_on;

[_ctrl, "netlink", {
    // NETLINK (mesh browser) verbs. No re-push here on purpose: post/like are
    // settled server-side and APS_fnc_loonerSRV rebroadcasts the whole feed to
    // every client afterwards, which arrives via AP_fnc_loonerReceive.
    params [["_verb", "", [""]], ["_arg", "", ["", 0]]];
    [_verb, _arg] call AP_fnc_deckNetlink
}] call webui_fnc_on;

[_ctrl, "bank", {
    // Deck BANK app (ATM). Verb goes to AP_fnc_deckBank, which returns {ok,msg};
    // the fresh payload is pushed after every attempt so balances never go stale
    // on a refusal either. xfer spawns -- it does a server round trip.
    params [["_verb", "", [""]], ["_amt", 0, [0]], ["_uid", "", [""]]];
    private _r = [_verb, _amt, _uid] call AP_fnc_deckBank;
    private _c = uiNamespace getVariable ["WEBUI_ctrl", controlNull];
    if (!isNull _c) then { [_c, "bank", (["data"] call AP_fnc_deckBank)] call webui_fnc_push; };
    _r
}] call webui_fnc_on;

[_ctrl, "rig", {
    params [["_verb", "", [""]], ["_a", "", [""]]];
    [_verb, _a] call AP_fnc_deckRig
}] call webui_fnc_on;

[_ctrl, "boot", {
    params [["_verb", "", [""]]];
    [_verb] call AP_fnc_deckBoot
}] call webui_fnc_on;

[_ctrl, "duel", {
    params [["_verb", "", [""]], ["_a", "", [""]], ["_b", 0, [0]]];
    [_verb, _a, _b] call AP_fnc_deckDuel
}] call webui_fnc_on;

[_ctrl, "suites", {
    params [["_verb", "", [""]], ["_a", "", [""]], ["_b", 0, [0]]];
    [_verb, _a, _b] call AP_fnc_deckSuites
}] call webui_fnc_on;

[_ctrl, "medic", {
    params [["_verb", "", [""]], ["_a", -1, [0]]];
    [_verb, _a] call AP_fnc_deckMedic
}] call webui_fnc_on;

[_ctrl, "intake", {
    params [["_verb", "", [""]], ["_a", "", ["", 0]], ["_b", 0, [0, []]]];
    [_verb, _a, _b] call AP_fnc_deckIntake
}] call webui_fnc_on;

[_ctrl, "sprays", {
    params [["_verb", "", [""]], ["_a", 0, [0, ""]]];
    if (_verb isEqualTo "data" && {_a isEqualType ""}) then { AP_deckSprayMode = _a; };
    [_verb, _a] call AP_fnc_deckSpray
}] call webui_fnc_on;

[_ctrl, "loadouts", {
    params [["_verb", "", [""]], ["_a", 0, [0, ""]], ["_b", "", [""]], ["_c", "", [""]]];
    [_verb, _a, _b, _c] call AP_fnc_deckLoadouts
}] call webui_fnc_on;

[_ctrl, "chop", {
    params [["_verb", "", [""]], ["_a", "", ["", 0]]];
    [_verb, _a] call AP_fnc_deckChop
}] call webui_fnc_on;

[_ctrl, "gangCmd", {
    params [["_verb", "", [""]], ["_a", 0, [0, ""]], ["_b", "", [""]], ["_c", "", [""]]];
    [_verb, _a, _b, _c] call AP_fnc_deckGang
}] call webui_fnc_on;

[_ctrl, "house", {
    params [["_verb", "", [""]], ["_a", "", ["", 0]]];
    [_verb, _a] call AP_fnc_deckHouse
}] call webui_fnc_on;

[_ctrl, "vshop", {
    params [["_verb", "", [""]], ["_class", "", [""]], ["_alarm", 0, [0]],
            ["_skinID", -1, [0]], ["_skinText", "", [""]], ["_modVals", [], [[]]]];
    [_verb, _class, _alarm, _skinID, _skinText, _modVals] call AP_fnc_deckVShop
}] call webui_fnc_on;

[_ctrl, "trunk", {
    params [["_verb", "", [""]], ["_moves", [], [[]]]];
    [_verb, _moves] call AP_fnc_deckTrunk
}] call webui_fnc_on;

[_ctrl, "garage", {
    params [["_verb", "", [""]], ["_id", -1, [0]], ["_changes", [], [[]]]];
    [_verb, _id, _changes] call AP_fnc_deckGarage
}] call webui_fnc_on;

[_ctrl, "summon", {
    params [["_verb", "", [""]]];
    [_verb] call AP_fnc_deckSummon
}] call webui_fnc_on;

[_ctrl, "fab", {
    params [["_verb", "", [""]], ["_a", "", [""]], ["_b", 0, [0]]];
    private _r = [_verb, _a, _b] call AP_fnc_deckFab;
    // material counts change on queue; hand the page truth immediately, not on its own retry
    if (_verb in ["queue"]) then {
        private _c = uiNamespace getVariable ["WEBUI_ctrl", controlNull];
        if (!isNull _c) then { [_c, "fab", (["data"] call AP_fnc_deckFab)] call webui_fnc_push; };
    };
    _r
}] call webui_fnc_on;

[_ctrl, "exchange", {
    params [["_verb", "", [""]], ["_a", 0, [0, ""]], ["_b", 0, [0]]];
    [_verb, _a, _b] call AP_fnc_deckExchange
}] call webui_fnc_on;

[_ctrl, "setFavs", {
    params [["_names", [], [[]]]];
    // NAMES only. Never the action or gate code — profileNamespace is
    // client-writable and storing code there was a real injection vector.
    private _clean = (_names select { _x isEqualType "" }) select [0, 5];
    profileNamespace setVariable ["AP_favApps_v2", _clean];
    saveProfileNamespace;
    createHashMapFromArray [["ok", true], ["msg", format ["%1 favourites saved", count _clean]]]
}] call webui_fnc_on;

[_ctrl, "markPlayer", {
    params [["_uid", "", [""]]];
    private _unit = allPlayers param [allPlayers findIf { getPlayerUID _x isEqualTo _uid }, objNull];
    if (isNull _unit) exitWith { createHashMapFromArray [["ok", false], ["msg", "not online"]] };
    [getPosATL _unit, name _unit] call AP_fnc_deckPing;
    createHashMapFromArray [["ok", true], ["msg", format ["marked %1", name _unit]]]
}] call webui_fnc_on;

[_ctrl, "keyAction", {
    params [["_key", "", [""]], ["_verb", "", [""]], ["_targetUid", "", [""]]];
    private _obj = objectFromNetId _key;
    if (isNull _obj) exitWith {
        createHashMapFromArray [["ok", false], ["msg", "not spawned right now"]]
    };
    private _name = getText (configFile >> "CfgVehicles" >> (typeOf _obj) >> "displayName");

    switch (toLower _verb) do {
        case "locate": {
            [getPosATL _obj, _name] call AP_fnc_deckPing;
            createHashMapFromArray [["ok", true], ["msg", format ["pinged %1 m away", round (player distance _obj)]]]
        };
        case "give": {
            private _unit = allPlayers param [allPlayers findIf {
                (_x getVariable ["AP_steamid", getPlayerUID _x]) isEqualTo _targetUid
            }, objNull];
            if (isNull _unit) exitWith {
                createHashMapFromArray [["ok", false], ["msg", "that player is not online"]]
            };
            // straight through the native function: same checks, no second copy
            private _ok = [controlNull, _obj, _unit] call AP_fnc_keyGive;
            createHashMapFromArray [["ok", _ok],
                ["msg", if (_ok) then { format ["%1 key given to %2", _name, name _unit] } else { "refused" }]]
        };
        case "drop": {
            private _ok = [controlNull, _obj] call AP_fnc_keyDrop;
            createHashMapFromArray [["ok", _ok],
                ["msg", if (_ok) then { format ["dropped the %1 key", _name] } else { "refused" }]]
        };
        default { createHashMapFromArray [["ok", false], ["msg", format ["unknown verb: %1", _verb]]] };
    }
}] call webui_fnc_on;

// Who is close enough to hand a key to. The keychain dialog uses the same rule
// (same gang / same group / same vehicle / within 12 m on foot).
[_ctrl, "nearbyPlayers", {
    private _myGang  = AP_gang_data param [0, -5];
    private _myGroup = group player;
    private _myVeh   = vehicle player;
    private _onFoot  = isNull (objectParent player);
    private _out = [];
    {
        private _gid = (_x getVariable ["gang_data", [-1]]) param [0, -1];
        if ((group _x) isEqualTo _myGroup
            || { _gid isEqualTo _myGang }
            || { (vehicle _x) isEqualTo _myVeh }
            || { _onFoot && { (player distance _x) <= 12 } }) then {
            _out pushBack (createHashMapFromArray [
                ["uid",  _x getVariable ["AP_steamid", getPlayerUID _x]],
                ["name", [name _x] call AP_fnc_cleanName],
                ["dist", round (player distance _x)]
            ]);
        };
    } forEach (allPlayers - [player]);
    _out
}] call webui_fnc_on;

[_ctrl, "gangAction", {
    params [["_uid", "", [""]], ["_verb", "", [""]]];
    if (AP_gang_data isEqualTo []) exitWith {
        createHashMapFromArray [["ok", false], ["msg", "you are not in a gang"]]
    };
    // fn_gangKick / fn_manageRank want [uid, name, rank] — the same triple the
    // native dialog stores in its listbox. AP_gangMembersList is the server's
    // own answer from APS_fnc_getGangInfo, so the rank is not client-invented.
    private _rows = missionNamespace getVariable ["AP_gangMembersList", []];
    private _i = _rows findIf { (_x param [0, ""]) isEqualTo _uid };
    if (_i isEqualTo -1) exitWith {
        createHashMapFromArray [["ok", false], ["msg", "member not in the roster — try refreshing"]]
    };
    private _unit = _rows select _i;

    private _ok = switch (toLower _verb) do {
        case "promote": { [1, _unit] call AP_fnc_manageRank };
        case "demote":  { [2, _unit] call AP_fnc_manageRank };
        case "kick":    { [_unit] call AP_fnc_gangKick };
        default { false };
    };
    if (_ok) then { [] call AP_fnc_deckGangRequest; };   // pull a fresh roster
    createHashMapFromArray [["ok", _ok],
        ["msg", if (_ok) then { format ["%1 %2", _verb, _unit param [1, ""]] } else { "refused" }]]
}] call webui_fnc_on;

// Talents / Perks / Honor / Prestige / TT Prestige / Infamy are ONE screen with
// a category string -- see fn_deckTree for why, and for what the design brief got
// wrong about the shape. Fetched on demand rather than pushed on the loop: six
// trees is a lot of payload for a screen the player is usually not looking at.
// ---- ICEBREAKER OS / TAL OS -------------------------------------------------
// Reading is a plain fetch; firing goes straight through AP_fnc_qhCast, which
// validates for instant feedback and then hands the whole thing to the server --
// APS_fnc_qhSRV owns the upload clock and re-validates range, target and
// authorisation when it completes. The page never decides that a hack landed.
[_ctrl, "qh", {
    params [["_what", "deck", [""]]];
    [_what] call AP_fnc_deckQh
}] call webui_fnc_on;

[_ctrl, "qhCast", {
    params [["_targetId", "", [""]], ["_hackId", "", [""]]];
    if (_hackId isEqualTo "") exitWith { createHashMapFromArray [["ok", false], ["msg", "no hack"]] };
    // The native path reads its target from AP_cdTarget -- the console's own
    // pick sets exactly this. netId keeps object handles out of the page.
    private _t = if (_targetId isEqualTo "") then { objNull } else { objectFromNetId _targetId };
    if (isNull _t) exitWith { createHashMapFromArray [["ok", false], ["msg", "target is gone"]] };
    AP_cdTarget = _t;
    [_hackId] call AP_fnc_qhCast;
    // Deliberately optimistic: qhCast reports its own refusals through
    // handleMessage, and the real answer arrives later on the qhResult handle
    // when the server's channel finishes.
    createHashMapFromArray [["ok", true], ["msg", ""]]
}] call webui_fnc_on;

[_ctrl, "qhLoad", {
    params [["_hackId", "", [""]], ["_slot", -1, [0]]];
    if (_slot < 0 || { _slot > 5 }) exitWith { createHashMapFromArray [["ok", false], ["msg", "bad slot"]] };
    private _slots = call AP_fnc_qhConsoleGet;
    while { count _slots < 6 } do { _slots pushBack "" };
    // a hack already in another slot moves rather than duplicating
    private _dup = _slots findIf { _x isEqualTo _hackId };
    if (_dup > -1 && { _dup isNotEqualTo _slot }) then { _slots set [_dup, _slots select _slot] };
    _slots set [_slot, _hackId];
    [_slots select { _x isNotEqualTo "" }] call AP_fnc_qhConsoleSave;
    createHashMapFromArray [["ok", true], ["msg", ""], ["slots", call AP_fnc_qhConsoleGet]]
}] call webui_fnc_on;

[_ctrl, "chipEquip", {
    params [["_chipId", "", [""]]];
    private _eq = player getVariable ["AP_fwChips", []];
    if (_chipId in _eq) then { _eq = _eq - [_chipId]; } else {
        // TWO equipped, from fn_qhCfg's own header. Oldest out rather than a
        // refusal: swapping is the normal action, not an error.
        _eq pushBack _chipId;
        if (count _eq > 2) then { _eq deleteAt 0 };
    };
    [_eq] call AP_fnc_fwSave;
    createHashMapFromArray [["ok", true], ["msg", ""], ["equipped", _eq]]
}] call webui_fnc_on;

// Wanted / Gangs Online / Licences / Captures / Group / Achievements / Titles /
// Quests are one screen with a kind string. All eight read client-side arrays, so
// this is a plain fetch with no server round trip and nothing to wait for.
[_ctrl, "list", {
    params [["_kind", "", [""]]];
    [_kind] call AP_fnc_deckList
}] call webui_fnc_on;

// Row and form actions for the list apps. Each goes straight through the native
// function, so every cooldown and validation rule it carries still applies.
[_ctrl, "listAction", {
    params [["_act", "", [""]], ["_id", "", [""]], ["_kind", "", [""]], ["_id2", "", [""]]];
    switch (_act) do {
        // titles are format strings ("Tycoon %1"); setTitle wants the RAW one, and
        // an empty id is how the native menu removes the current title
        case "title":       { [_id, "AP_prefix"] call AP_fnc_setTitle; };
        case "groupCreate": { [_id, _id2] call AP_fnc_createGroup; };
        case "groupPass":   { [_id] call AP_fnc_setGroupPass; };
        // _id is the squad NAME, _id2 whatever was typed in the shared password
        // field. An open squad ignores it; a locked one needs an exact match.
        case "groupJoin":   { [_id, _id2] call AP_fnc_joinGroup; };
        case "groupKick":   { [_id] call AP_fnc_kickGroup; };
        case "groupLeader": { [_id] call AP_fnc_setGroupLeader; };
        case "groupLeave":  { [true] call AP_fnc_leaveGroup; };
        // no native disband exists -- leaving as the last member deletes the
        // group, so clear the room first and then go
        case "groupDisband": {
            {
                if (isPlayer _x && { _x isNotEqualTo player }) then {
                    [getPlayerUID _x] call AP_fnc_kickGroup;
                };
            } forEach (units (missionNamespace getVariable ["AP_my_gang", grpNull]));
            [true] call AP_fnc_leaveGroup;
        };
        case "housePay":    { [parseNumber _id] call AP_fnc_housePayTax; };
        case "housePayAll": { ["all"] call AP_fnc_housePayTax; };
        default {};
    };
    private _r = createHashMapFromArray [["ok", true], ["msg", ""]];
    if (_kind isNotEqualTo "") then { _r set ["list", ([_kind] call AP_fnc_deckList)] };
    _r
}] call webui_fnc_on;

[_ctrl, "tree", {
    params [["_cat", "standard", [""]]];
    [_cat] call AP_fnc_deckTree
}] call webui_fnc_on;

// One verb for both kinds. A live id is a STRING and is deck-only; a .paa id is a
// NUMBER and goes through the native function so the old handset agrees.
// Straight through the native item functions -- same spam limiter, same
// processing/underwater/in-vehicle guards, same 3-second transfer cooldown, and
// the whole 200-line use switch. `spawn` because dropItem and useItem both
// suspend; the refreshed payload is what tells the page what happened.
[_ctrl, "invAction", {
    params [["_verb", "", [""]], ["_id", "", [""]], ["_qty", 1, [0]], ["_uid", "", [""]]];
    if (_id isEqualTo "") exitWith { createHashMapFromArray [["ok", false], ["msg", "no item"]] };
    switch (toLower _verb) do {
        case "use":  { [controlNull, _id] spawn AP_fnc_useItem; };
        case "drop": { [_id, _qty max 1] spawn AP_fnc_dropItem; };
        case "give": {
            if (_uid isEqualTo "") exitWith {};
            [controlNull, _id, _qty max 1, _uid] spawn AP_fnc_giveItem;
        };
        default {};
    };
    createHashMapFromArray [["ok", true], ["msg", ""]]
}] call webui_fnc_on;

[_ctrl, "setWallpaper", {
    params [["_id", "", ["", 0]]];
    if (_id isEqualType "") then {
        if !(_id in ["live_10"]) exitWith { createHashMapFromArray [["ok", false], ["msg", "no such live wallpaper"]] };
        profileNamespace setVariable ["AP_deckWall", _id];
        saveProfileNamespace;
    } else {
        if (((localNamespace getVariable "AP_wallpapers") findIf { (_x select 0) isEqualTo _id }) isEqualTo -1) exitWith {
            createHashMapFromArray [["ok", false], ["msg", "no such wallpaper"]]
        };
        // clearing the override is what makes the static choice win again
        profileNamespace setVariable ["AP_deckWall", ""];
        [controlNull, _id] call AP_fnc_setWallpaper;
    };
    private _r = createHashMapFromArray [["ok", true], ["msg", "wallpaper set"]];
    _r set ["wallpaper", (["wallpaper"] call AP_fnc_deckData)];
    _r
}] call webui_fnc_on;

[_ctrl, "setScrim", {
    params [["_v", 1, [0]]];
    profileNamespace setVariable ["AP_deckScrim", (round _v) max 0 min 3];
    saveProfileNamespace;
    private _r = createHashMapFromArray [["ok", true], ["msg", ""]];
    _r set ["wallpaper", (["wallpaper"] call AP_fnc_deckData)];
    _r
}] call webui_fnc_on;

[_ctrl, "setWallMotion", {
    params [["_v", "launcher", [""]]];
    if !(_v in ["on", "launcher", "off"]) exitWith { createHashMapFromArray [["ok", false], ["msg", "bad mode"]] };
    profileNamespace setVariable ["AP_deckWallMotion", _v];
    saveProfileNamespace;
    private _r = createHashMapFromArray [["ok", true], ["msg", format ["motion: %1", _v]]];
    _r set ["wallpaper", (["wallpaper"] call AP_fnc_deckData)];
    _r
}] call webui_fnc_on;

// The native settings panel, on the deck. Slots, ranges and live effects all live
// in SQF -- the page draws whatever the payload describes, so a setting added
// there appears here without touching the page.
[_ctrl, "settingsGet", { [] call AP_fnc_deckSettings }] call webui_fnc_on;

[_ctrl, "settingsSet", {
    params [["_id", "", [""]], ["_v", 0, [0, false]]];
    [_id, _v] call AP_fnc_deckSettingsSet;
    // Answer with the whole payload rather than an ok: the value written is
    // clamped and normalised server-side, and the screen must show what was
    // actually stored, not what was asked for.
    [] call AP_fnc_deckSettings
}] call webui_fnc_on;

// Settings rows of type "action" have no value to write -- they open something. Kept separate
// from settingsSet on purpose: that verb's contract is "clamp it, store it, answer with the whole
// payload", and an action has nothing to clamp, nothing to store and a screen to open instead.
[_ctrl, "settingsAction", {
    params [["_id", "", [""]]];
    switch (_id) do {
        case "hudEdit": {
            // Spawned, and it closes this dialog itself: two dialogs cannot be open at once, and
            // AP_fnc_hudEdit has to wait for the engine to actually take the deck down before it
            // can create its own (createDialog on the same frame returns false, silently).
            [] spawn AP_fnc_hudEdit;
            createHashMapFromArray [["ok", true], ["msg", "opening HUD editor"]]
        };
        default {
            diag_log format ["[DECK] unknown settings action '%1'", _id];
            createHashMapFromArray [["ok", false], ["msg", "unknown action"]]
        };
    }
}] call webui_fnc_on;

// Handset size. The ceiling is computed from the safezone, so the page asks for it rather than
// hardcoding a number that would be wrong on a different aspect or interface-size setting.
[_ctrl, "deckScaleGet", {
    private _gw = 2.5 * pixelW * pixelGrid;
    private _gh = 2.5 * pixelH * pixelGrid;
    private _max = ((((safezoneW * 0.98) / (40 * _gw)) min ((safezoneH * 0.98) / (20 * _gh))) min 2.5) max 1;
    createHashMapFromArray [
        ["scale", profileNamespace getVariable ["AP_deckScale", 1]],
        ["min",   1],
        ["max",   _max]
    ]
}] call webui_fnc_on;

[_ctrl, "deckScaleSet", {
    params [["_v", 1, [0]]];
    private _c = uiNamespace getVariable ["WEBUI_ctrl", controlNull];
    private _applied = [_c, _v] call AP_fnc_deckScale;
    // Answer with what was ACTUALLY applied -- the request is clamped to the safezone, so the
    // slider has to be able to snap back to the real ceiling.
    createHashMapFromArray [["ok", true], ["msg", format ["handset size %1%2", round (_applied * 100), "%"]], ["scale", _applied]]
}] call webui_fnc_on;

// Opening a thread is what marks it read. Kept as its own verb rather than folded
// into the fetch, because fetching the screen must not silently clear a badge the
// player has not actually looked at.
[_ctrl, "msgRead", {
    params [["_who", "", [""]]];
    if (_who isNotEqualTo "") then { [_who] call AP_fnc_msgUnreadClear; };
    private _r = createHashMapFromArray [["ok", true], ["msg", ""]];
    _r set ["msgs", (["msgs"] call AP_fnc_deckData)];
    _r
}] call webui_fnc_on;

// Straight through fn_sendText -- same Silence Cell jam, same parseText content
// blacklist, same 500-char cap, same prisoner rule, no second copy. mode 0 needs
// a recipient uid; 1/2/3 are the broadcast channels and take none. Staff and
// governor modes (5-8) are deliberately not reachable from here.
[_ctrl, "sendMsg", {
    params [["_mode", 0, [0]], ["_text", "", [""]], ["_uid", "", [""]]];
    if !(_mode in [0, 1, 2, 3]) exitWith {
        createHashMapFromArray [["ok", false], ["msg", "that channel is not on the deck"]]
    };
    if (_text isEqualTo "") exitWith {
        createHashMapFromArray [["ok", false], ["msg", "type something first"]]
    };
    [controlNull, _mode, _text, _uid] call AP_fnc_sendText;
    // fn_sendText reports its own refusals through handleMessage and does not
    // answer, so the reply here is "handed off", not "delivered". The refreshed
    // thread list is what actually tells the page whether anything landed.
    private _r = createHashMapFromArray [["ok", true], ["msg", ""]];
    _r set ["msgs", (["msgs"] call AP_fnc_deckData)];
    _r
}] call webui_fnc_on;

// Bank money, deducted client-side. That is the existing trust boundary for this
// purchase, not a new one -- fn_buyTalentPoint has always debited locally and let
// APS_fnc_talentPointsSRV record the authoritative count, and the native button
// in dialog\talent.hpp does exactly the same thing. `true` is the pre-answered
// confirm; the page asks first.
[_ctrl, "buyTalentPoint", {
    private _ok = [true] call AP_fnc_buyTalentPoint;
    if !(_ok isEqualType false) then { _ok = false };
    private _r = createHashMapFromArray [["ok", _ok], ["msg", if (_ok) then { "point purchased" } else { "refused" }]];
    _r set ["tree", (["standard"] call AP_fnc_deckTree)];
    _r
}] call webui_fnc_on;

[_ctrl, "treeAction", {
    params [["_cat", "", [""]], ["_id", -1, [0]]];
    private _r = [_cat, _id] call AP_fnc_deckTreeAction;
    // Hand the fresh tree back with the result so the page never has to guess
    // what the mutation did to the pool, the caps or the child locks.
    _r set ["tree", ([_cat] call AP_fnc_deckTree)];
    _r
}] call webui_fnc_on;

// ------------------------------------------------------------ staff deck ----
// The admin panel is an APP on this phone (owner 2026-08-14), so its verbs and its
// roster push ride the deck's own control. Registered for everyone: AP_fnc_staffAct
// gates every verb on AP_adminLevel server-side-checked anyway, and the launcher
// never shows the tile below level 2.
[_ctrl] call AP_fnc_staffWire;

// ---------------------------------------------------- money + gang writes ----
// Wired 2026-08-14. These were the last five stubs; three are now real and two
// are gone rather than stubbed:
//   bank     -- the deck's DEPOSIT / WITHDRAW buttons were removed on the owner's
//               call, banking stays an ATM errand.
//   payFine  -- there is no fine store on this server and no way to settle one
//               from a phone; the money screen's fines box is a READ-ONLY list of
//               what the player is wanted for (fn_deckData "money"). See an officer.
// gangBank went the same way on 2026-08-11.
//
// Each of the three below goes through the native function rather than getting a
// thinner copy of its guards here -- those guards are the trust boundary for a
// client-authoritative cash move (security.md), so there is exactly one of them.

[_ctrl, "transfer", {
    params [["_uid", "", [""]], ["_amount", 0, [0]]];
    if (_uid isEqualTo "") exitWith { createHashMapFromArray [["ok", false], ["msg", "nobody selected"]] };
    private _ok = [_uid, _amount] call AP_fnc_giveMoney;
    // fn_giveMoney has already told the player exactly what was wrong, in the
    // game's own voice; the page only needs to know whether to repaint.
    createHashMapFromArray [["ok", _ok],
        ["msg", if (_ok) then { format ["sent $%1", [_amount] call AP_fnc_numberText] } else { "refused" }]]
}] call webui_fnc_on;

[_ctrl, "gangInvite", {
    params [["_name", "", [""]]];
    if (_name isEqualTo "") exitWith { createHashMapFromArray [["ok", false], ["msg", "type a name first"]] };
    private _ok = [_name] call AP_fnc_invite2Gang;
    createHashMapFromArray [["ok", _ok],
        ["msg", if (_ok) then { format ["invite sent to %1", _name] } else { "refused" }]]
}] call webui_fnc_on;

[_ctrl, "gangRename", {
    params [["_name", "", [""]]];
    private _ok = [_name] call AP_fnc_gangRename;
    // The rename is a server round trip (fee + uniqueness live in the DB), so this
    // only reports that the request went out. AP_fnc_gangRenamed pushes the new
    // name back to every member, and the deck's push loop repaints from it.
    createHashMapFromArray [["ok", _ok],
        ["msg", if (_ok) then { "rename requested" } else { "refused" }]]
}] call webui_fnc_on;

// Ask the LIVE document what it actually is. This works even when the browser
// is serving a stale cached copy, because it runs inside whatever page is
// really loaded rather than relying on that page containing new code — which
// is exactly the trap that made a cached page look like a missing feature.
[_ctrl] spawn {
    params ["_c"];
    uiSleep 3;
    if (isNull _c) exitWith {};
    _c ctrlWebBrowserAction ["ExecJS",
        "window.WEBUI && WEBUI.call('log',['LIVE PAGE href=' + location.href"
        + " + '  build=' + (typeof PAGE_BUILD !== 'undefined' ? PAGE_BUILD : 'ABSENT')"
        + " + '  hasStow=' + (typeof window.__deckStow === 'function')]);"];
};

// ------------------------------------------------------------ Esc / stow ---
// Arma closes a dialog on Esc instantly, so the roll-shut never gets to play.
// CHASSIS.md called this out as an owner decision because intercepting Esc
// holds input for the length of the animation; granted 2026-08-11, with the
// stow kept short (~740ms total) and a second Esc closing immediately so the
// player is never stuck inside an animation while being shot at.
_display displayAddEventHandler ["KeyDown", {
    params ["_disp", "_key"];
    private _handled = false;
    if (_key isEqualTo 1) then {                       // DIK_ESCAPE
        _handled = true;
        if (_disp getVariable ["deck_stowing", false]) then {
            closeDialog 0;                             // second Esc: out now
        } else {
            _disp setVariable ["deck_stowing", true];
            [] spawn {
                private _c = uiNamespace getVariable ["WEBUI_ctrl", controlNull];
                private _ms = 900;
                if (!isNull _c) then {
                    private _r = [_c, "stow", [], 3] call webui_fnc_call;
                    if (!isNil "_r" && { _r isEqualType 0 }) then { _ms = _r };
                };
                uiSleep (_ms / 1000);
                closeDialog 0;
            };
        };
    };
    _handled
}];

// ---------------------------------------------------------------- pushes ---
[] call AP_fnc_deckGangRequest;

[_ctrl] spawn {
    params ["_ctrl"];
    private _n = 0;
    while { !isNull _ctrl && { !isNull (findDisplay 937500) } } do {
        // header data (clock, restart, cash) every tick; the heavier channels
        // every third. Nothing here polls per frame. Pushes sent before the
        // page has loaded are queued by webui_fnc_exec, not dropped.
        [_ctrl, "phone", (["phone"] call AP_fnc_deckData)] call webui_fnc_push;
        if (_n mod 3 isEqualTo 0) then {
            [_ctrl, "gang",  (["gang"]  call AP_fnc_deckData)] call webui_fnc_push;
            [_ctrl, "keys",  (["keys"]  call AP_fnc_deckData)] call webui_fnc_push;
            [_ctrl, "money", (["money"] call AP_fnc_deckData)] call webui_fnc_push;
        };
        if (_n isEqualTo 0) then { diag_log format ["[DECK] first push sent t=%1", diag_tickTime toFixed 1]; };
        _n = _n + 1;
        uiSleep 2;
    };
};

diag_log format ["[DECK] opened t=%1", diag_tickTime toFixed 1];

// AP_fnc_staffMenu sets this when the phone was CLOSED and a staffer asked for the
// admin panel: the page lands on STAFF instead of the launcher. Consumed once, so
// the next plain open behaves normally.
if (uiNamespace getVariable ["AP_deckOpenStaff", false]) then {
    uiNamespace setVariable ["AP_deckOpenStaff", false];
    [_ctrl, "window.__openStaff=1;"] call webui_fnc_exec;
};
// AP_fnc_deckOpenApp sets this when it had to open the phone first: the page
// lands on that app instead of the launcher. Consumed once.
private _wantApp = uiNamespace getVariable ["AP_deckOpenApp", ""];
if (_wantApp isNotEqualTo "") then {
    uiNamespace setVariable ["AP_deckOpenApp", ""];
    // CALL deckGo, don't just set the flag. The page's boot block consumes
    // __openApp the moment bridge.js resolves WEBUIReady -- which is EARLIER in
    // this same exec-queue drain than this line's exec. Setting the variable
    // alone therefore always lost the race from a cold phone: boot checked,
    // found nothing, landed on the launcher, and the name arrived a few execs
    // later with nobody left to read it. __deckGo is defined at page parse, and
    // by the time this exec runs the bridge is up, so the direct call is safe;
    // the assignment stays as the fallback for any future boot-order change.
    [_ctrl, format ["if (window.__deckGo) { window.__deckGo('%1'); } else { window.__openApp='%1'; }", _wantApp]] call webui_fnc_exec;
};
